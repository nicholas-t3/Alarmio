//
//  AlarmScheduler.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/3/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import AlarmKit
import ActivityKit
import AppIntents
import SwiftUI

@Observable
@MainActor
final class AlarmScheduler {

    // MARK: - State

    private(set) var authorizationState: AlarmManager.AuthorizationState = .notDetermined
    var activeAlarmStates: [UUID: Alarm.State] = [:]

    // MARK: - Dependencies

    let manager = AlarmManager.shared
    private let audioFileManager: AudioFileManager

    // MARK: - Init

    init(audioFileManager: AudioFileManager) {
        self.audioFileManager = audioFileManager
        authorizationState = manager.authorizationState
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        switch manager.authorizationState {
        case .notDetermined:
            do {
                let state = try await manager.requestAuthorization()
                authorizationState = state
                return state == .authorized
            } catch {
                print("[AlarmScheduler] Authorization error: \(error)")
                return false
            }
        case .authorized:
            authorizationState = .authorized
            return true
        case .denied:
            authorizationState = .denied
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Scheduling

    func scheduleAlarm(_ config: AlarmConfiguration) async throws {
        let wakeDesc: String = {
            guard let w = config.wakeTime else { return "nil" }
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            return f.string(from: w)
        }()
        print("[AlarmScheduler.schedule] id=\(config.id) wake=\(wakeDesc) repeatDays=\(config.repeatDays.map { String(describing: $0) } ?? "nil") enabled=\(config.isEnabled)")

        guard let intendedFireDate = buildIntendedFireDate(from: config) else {
            print("[AlarmScheduler] Cannot build schedule — no wake time set")
            return
        }

        let intendedFormatter = DateFormatter()
        intendedFormatter.dateFormat = "EEE yyyy-MM-dd HH:mm:ss"
        print("[AlarmScheduler.schedule] intendedFireDate=\(intendedFormatter.string(from: intendedFireDate))")

        let isRepeating = !(config.repeatDays?.isEmpty ?? true)
        let now = Date()
        let headroom = intendedFireDate.timeIntervalSince(now)
        print("[AlarmScheduler] headroom=\(Int(headroom))s isRepeating=\(isRepeating)")

        // H1 + H3: pick largest minute-aligned preAlert ≤ desired such that
        // the resulting registered time is safely in the future (.relative)
        // or the shifted fixed date is ≥ now + schedulingBuffer (.fixed).
        // See plan hazards H1/H3 for the defer-to-next-week history.
        let desiredPreAlert: TimeInterval = config.liveActivityEnabled
            ? TimeInterval(max(1, min(9, config.liveActivityLeadHours)) * 3600)
            : 0
        let safePreAlert = pickSafePreAlert(
            intendedFireDate: intendedFireDate,
            desired: desiredPreAlert,
            isRepeating: isRepeating,
            now: now
        )
        print("[AlarmScheduler] desiredPreAlert=\(Int(desiredPreAlert))s safePreAlert=\(Int(safePreAlert))s")

        let maxSnoozes = config.maxSnoozes
        let currentCount = config.currentSnoozeCount ?? 0
        // In unlimited mode, snoozesRemaining is effectively infinite — we
        // pass a sentinel large value so the snooze button is always shown.
        // SnoozeAlarmIntent skips the cap math when unlimitedSnooze is true.
        let snoozesRemaining = config.unlimitedSnooze
            ? Int.max
            : max(0, maxSnoozes - currentCount)
        print("[AlarmScheduler] scheduling alarm=\(config.id) snoozesRemaining=\(snoozesRemaining) (count=\(currentCount)/\(maxSnoozes), unlimited=\(config.unlimitedSnooze))")

        // H5: both nil or both non-nil — single `safePreAlert > 0` source
        // gates both countdownDuration and the Countdown presentation so
        // they can never disagree (would throw Code=0).
        let includeCountdown = safePreAlert > 0
        let countdownDuration: Alarm.CountdownDuration? = includeCountdown
            ? Alarm.CountdownDuration(preAlert: safePreAlert, postAlert: nil)
            : nil

        let attributes = buildAttributes(
            from: config,
            snoozesRemaining: snoozesRemaining,
            includeCountdown: includeCountdown
        )

        // Resolve the initial-fire sound from AudioFileManager. For
        // Composer-generated alarms this picks up the indexed `_0` file.
        // When no generated file exists (demo alarms, missing audio) fall
        // back to the iOS system alarm sound via `.default`.
        let soundName = audioFileManager.soundFileName(
            for: config.id,
            configured: config.soundFileName
        )
        let sound: ActivityKit.AlertConfiguration.AlertSound = soundName.map { .named($0) } ?? .default
        print("[AlarmScheduler] initial sound=\(soundName ?? "<system default>")")

        // When snoozes are exhausted, omit the secondary intent entirely so
        // the final alarm has only a Stop button and cannot be snoozed.
        let secondaryIntent: (any LiveActivityIntent)?
        if snoozesRemaining > 0 {
            secondaryIntent = SnoozeAlarmIntent(alarmID: config.id.uuidString)
        } else {
            secondaryIntent = nil
        }

        // H2: registered time is shifted back by preAlert so the alert still
        // rings at the user's intended wake time (ring = time + preAlert).
        // When safePreAlert == 0 the shift is zero and we fall back to the
        // proven no-Countdown shape.
        let schedule = buildSchedule(
            intendedFireDate: intendedFireDate,
            isRepeating: isRepeating,
            repeatDays: config.repeatDays ?? [],
            shiftSeconds: safePreAlert
        )

        let alarmConfig = AlarmManager.AlarmConfiguration<AlarmioMetadata>(
            countdownDuration: countdownDuration,
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: config.id.uuidString),
            secondaryIntent: secondaryIntent,
            sound: sound
        )

        AlarmDebugLog.log("schedule.request", "id=\(config.id) isRepeating=\(isRepeating) headroom=\(Int(headroom))s intended=\(intendedFireDate) desiredPreAlert=\(Int(desiredPreAlert))s safePreAlert=\(Int(safePreAlert))s snoozesRemaining=\(snoozesRemaining) includeCountdown=\(includeCountdown) sound=\(soundName ?? "<default>")")

        // H6: race-safe reschedule. Any live edit during an active countdown
        // hits the UUID-release race unless we sleep 200ms between cancel
        // and schedule. Silent `Code=0` otherwise.
        do {
            try await performSafeReschedule(id: config.id, configuration: alarmConfig)
            AlarmDebugLog.log("schedule.result", "id=\(config.id) ok")
            print("[AlarmScheduler] scheduled successfully")
        } catch {
            let ns = error as NSError
            AlarmDebugLog.log("schedule.error", "id=\(config.id) domain=\(ns.domain) code=\(ns.code) userInfo=\(ns.userInfo) description=\(ns.localizedDescription)")
            throw error
        }
    }

    /// H6: `AlarmManager.schedule(id:)` immediately after `cancel(id:)` or
    /// `stop(id:)` throws `Code=0` because `alarmd` hasn't released the UUID
    /// slot. 200ms sleep fixes it. Used by the main scheduling path AND by
    /// `SnoozeAlarmIntent.scheduleNext`.
    func performSafeReschedule(
        id: UUID,
        configuration: AlarmManager.AlarmConfiguration<AlarmioMetadata>
    ) async throws {
        try? manager.cancel(id: id)
        try? await Task.sleep(nanoseconds: 200_000_000)
        _ = try await manager.schedule(id: id, configuration: configuration)
    }

    func cancelAlarm(id: UUID) throws {
        try manager.cancel(id: id)
    }

    func toggleAlarm(_ config: AlarmConfiguration) async throws {
        if config.isEnabled {
            try await scheduleAlarm(config)
        } else {
            try? cancelAlarm(id: config.id)
        }
    }

    // MARK: - Observation (handled by AlarmStore)

    // MARK: - Schedule Building (internal for testability)

    /// Minimum gap between "now" and the schedule's .fixed() date. If we
    /// pass AlarmKit a schedule time that's already in the past (even by
    /// a few ms after IPC), it silently drops the alarm. Give ourselves a
    /// proper cushion.
    static let schedulingBufferSeconds: TimeInterval = 3

    /// The user's intended fire time, unshifted, in absolute Date terms.
    /// For one-time alarms: the next occurrence of the hour/minute.
    /// For repeating alarms: the next occurrence in any of the selected
    /// weekdays.
    func buildIntendedFireDate(from config: AlarmConfiguration, referenceDate: Date = Date()) -> Date? {
        guard let wakeTime = config.wakeTime else { return nil }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: wakeTime)
        let minute = calendar.component(.minute, from: wakeTime)

        if let repeatDays = config.repeatDays, !repeatDays.isEmpty {
            // Find the next occurrence across any of the selected weekdays.
            let weekdaysAsInts = repeatDays.map { ($0 + 1) }  // our 0=Sun → Calendar 1=Sun
            var earliest: Date?
            for weekday in weekdaysAsInts {
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                components.second = 0  // pin to :00, otherwise matches current second
                components.weekday = weekday
                if let candidate = calendar.nextDate(
                    after: referenceDate,
                    matching: components,
                    matchingPolicy: .nextTime
                ) {
                    if earliest == nil || candidate < earliest! {
                        earliest = candidate
                    }
                }
            }
            return earliest
        }

        // .second = 0 is critical: without it, nextDate(matching:) preserves
        // the current second, causing alarms to drift by 0-59 seconds
        // depending on when the user tapped Set.
        let components = DateComponents(hour: hour, minute: minute, second: 0)
        return calendar.nextDate(
            after: referenceDate,
            matching: components,
            matchingPolicy: .nextTime
        )
    }

    /// H1 + H3 + H4: pick largest minute-aligned preAlert ≤ desired that
    /// produces a safe schedule.
    ///
    /// For `.relative`: registered time (intended - candidate) must be
    ///   ≥ now + 60s AND on the same calendar day as the intended fire
    ///   (avoids the weekday-crossing complexity entirely).
    /// For `.fixed`: shifted date must be ≥ now + schedulingBufferSeconds.
    ///
    /// Walks down from desired in 60s steps. Returns 0 when nothing fits —
    /// caller omits Countdown presentation entirely and the first fire
    /// simply has no Live Activity window. The alarm still rings correctly
    /// at the intended time via the unshifted schedule.
    func pickSafePreAlert(
        intendedFireDate: Date,
        desired: TimeInterval,
        isRepeating: Bool,
        now: Date
    ) -> TimeInterval {
        guard desired > 0 else { return 0 }

        let safetyBuffer: TimeInterval = isRepeating ? 60 : Self.schedulingBufferSeconds
        let headroom = intendedFireDate.timeIntervalSince(now)

        // Can't fit even a 1-minute countdown? Give up — alarm still rings.
        if headroom < safetyBuffer + 60 { return 0 }

        // Start at the largest minute-aligned value ≤ desired.
        let maxCandidate = floor(desired / 60) * 60
        var candidate = maxCandidate

        let calendar = Calendar.current
        let intendedDay = calendar.startOfDay(for: intendedFireDate)

        while candidate >= 60 {
            let shiftedTime = intendedFireDate.addingTimeInterval(-candidate)
            let fitsHeadroom = shiftedTime >= now.addingTimeInterval(safetyBuffer)
            // .fixed tolerates crossing midnight (one-time alarms don't
            // pattern-match on weekdays). .relative must stay same-day to
            // avoid needing weekday adjustment math.
            let sameDayOK = isRepeating
                ? calendar.startOfDay(for: shiftedTime) == intendedDay
                : true
            if fitsHeadroom && sameDayOK { return candidate }
            candidate -= 60
        }
        return 0
    }

    /// Build the AlarmKit schedule. For repeating `.relative` alarms the
    /// registered hour/minute is shifted back by `shiftSeconds` so that
    /// ring time (`time + preAlertSeconds`) equals the user's intended
    /// time. `shiftSeconds` MUST come from `pickSafePreAlert` (minute-
    /// aligned, keeps shifted time same-day) — AlarmKit drops seconds from
    /// the registered `time`.
    ///
    /// For `.fixed` (one-time), the shifted date is clamped to at least
    /// `now + schedulingBufferSeconds` so we can't feed `alarmd` a past
    /// date (which it silently drops — H3).
    func buildSchedule(
        intendedFireDate: Date,
        isRepeating: Bool,
        repeatDays: [Int],
        shiftSeconds: TimeInterval
    ) -> Alarm.Schedule {
        if isRepeating {
            let weekdays = repeatDays.compactMap { mapDayIndexToWeekday($0) }
            let shifted = intendedFireDate.addingTimeInterval(-shiftSeconds)
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: shifted)
            let minute = calendar.component(.minute, from: shifted)
            print("[AlarmScheduler.buildSchedule] REPEATING — repeatDays(0=Sun)=\(repeatDays), weekdays=\(weekdays), registeredTime=\(hour):\(String(format: "%02d", minute)), shiftSeconds=\(Int(shiftSeconds))")
            return .relative(.init(
                time: .init(hour: hour, minute: minute),
                repeats: .weekly(weekdays)
            ))
        }
        let shifted = intendedFireDate.addingTimeInterval(-shiftSeconds)
        let earliest = Date().addingTimeInterval(Self.schedulingBufferSeconds)
        let fireDate = max(shifted, earliest)
        print("[AlarmScheduler.buildSchedule] ONE-TIME fixed=\(fireDate) (shifted=\(shifted), shift=\(Int(shiftSeconds))s)")
        return .fixed(fireDate)
    }

    /// Legacy entry point kept for tests. Returns the unshifted schedule
    /// (no preAlert) — useful for asserting the raw intended hour/minute.
    /// Returns nil when the alarm can't be scheduled (no wake time, or
    /// repeatDays non-empty but every index is out of range).
    func buildSchedule(from config: AlarmConfiguration, referenceDate: Date = Date()) -> Alarm.Schedule? {
        guard let intended = buildIntendedFireDate(from: config, referenceDate: referenceDate) else {
            return nil
        }
        let isRepeating = !(config.repeatDays?.isEmpty ?? true)
        if isRepeating {
            let validDays = (config.repeatDays ?? []).compactMap { mapDayIndexToWeekday($0) }
            if validDays.isEmpty { return nil }
        }
        return buildSchedule(
            intendedFireDate: intended,
            isRepeating: isRepeating,
            repeatDays: config.repeatDays ?? [],
            shiftSeconds: 0
        )
    }

    private func buildAttributes(
        from config: AlarmConfiguration,
        snoozesRemaining: Int,
        includeCountdown: Bool
    ) -> AlarmAttributes<AlarmioMetadata> {
        let title = buildAlarmTitle(from: config)

        let stopButton = AlarmButton(
            text: "STOP",
            textColor: .red,
            systemImageName: "stop.circle.fill"
        )

        let alert: AlarmPresentation.Alert
        if snoozesRemaining > 0 {
            let snoozeButton = AlarmButton(
                text: "SNOOZE",
                textColor: .black,
                systemImageName: "zzz"
            )
            alert = AlarmPresentation.Alert(
                title: title,
                stopButton: stopButton,
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .custom
            )
        } else {
            // Final alarm — only Stop, no Snooze button. Structural cap.
            alert = AlarmPresentation.Alert(
                title: title,
                stopButton: stopButton
            )
        }

        // H5: Countdown presentation exists IFF countdownDuration is non-nil
        // on the paired config. Caller gates both with `safePreAlert > 0`.
        let presentation: AlarmPresentation = includeCountdown
            ? AlarmPresentation(
                alert: alert,
                countdown: AlarmPresentation.Countdown(title: title, pauseButton: nil)
              )
            : AlarmPresentation(alert: alert)

        return AlarmAttributes<AlarmioMetadata>(
            presentation: presentation,
            tintColor: Color(hex: "3A6EAA")
        )
    }

    func buildCountdownDuration(from config: AlarmConfiguration) -> Alarm.CountdownDuration {
        let snoozeSeconds = TimeInterval(config.snoozeInterval * 60)
        return Alarm.CountdownDuration(preAlert: nil, postAlert: snoozeSeconds)
    }

    func buildAlarmTitle(from config: AlarmConfiguration) -> LocalizedStringResource {
        if let name = config.name, !name.isEmpty {
            return "\(name)"
        }
        return "Alarmio Alarm"
    }

    func mapDayIndexToWeekday(_ index: Int) -> Locale.Weekday? {
        switch index {
        case 0: return .sunday
        case 1: return .monday
        case 2: return .tuesday
        case 3: return .wednesday
        case 4: return .thursday
        case 5: return .friday
        case 6: return .saturday
        default: return nil
        }
    }
}
