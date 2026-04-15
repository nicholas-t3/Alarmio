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
        // Cancel existing first to prevent duplicates
        try? cancelAlarm(id: config.id)

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

        // Pick a preAlert countdown length. `.relative` schedules pattern-
        // match the registered `time` against the local wall clock — if
        // that `time` (after dropping seconds) lands at or before "now",
        // AlarmKit defers to next week. So the shifted time MUST stay
        // comfortably in the future. `.fixed` doesn't have this issue.
        //
        // Strategy: aim for a 60s countdown. If that would push the
        // shifted time into/past the current minute, drop the countdown
        // entirely and register the raw intended time.
        let isRepeating = !(config.repeatDays?.isEmpty ?? true)
        let headroom = intendedFireDate.timeIntervalSince(Date())
        // Live Activities disabled — force preAlert to 0 so no countdown
        // card renders. Uncomment the pickPreAlertSeconds call to restore.
        let preAlertSeconds: TimeInterval = 0
//        let preAlertSeconds = pickPreAlertSeconds(
//            intendedFireDate: intendedFireDate,
//            isRepeating: isRepeating
//        )
        print("[AlarmScheduler] headroom=\(Int(headroom))s preAlert=\(Int(preAlertSeconds))s isRepeating=\(isRepeating)")

        let maxSnoozes = config.maxSnoozes
        let currentCount = config.currentSnoozeCount ?? 0
        // In unlimited mode, snoozesRemaining is effectively infinite — we
        // pass a sentinel large value so the snooze button is always shown.
        // SnoozeAlarmIntent skips the cap math when unlimitedSnooze is true.
        let snoozesRemaining = config.unlimitedSnooze
            ? Int.max
            : max(0, maxSnoozes - currentCount)
        print("[AlarmScheduler] scheduling alarm=\(config.id) snoozesRemaining=\(snoozesRemaining) (count=\(currentCount)/\(maxSnoozes), unlimited=\(config.unlimitedSnooze))")

        let attributes = buildAttributes(
            from: config,
            snoozesRemaining: snoozesRemaining,
            includeCountdown: preAlertSeconds > 0
        )

        // Resolve the initial-fire sound from AudioFileManager. For
        // Composer-generated alarms this picks up the indexed `_0` file.
        // For demo alarms or alarms missing audio it falls back to
        // default_alarm.mp3.
        let soundName = audioFileManager.soundFileName(
            for: config.id,
            configured: config.soundFileName
        )
        let sound: ActivityKit.AlertConfiguration.AlertSound = .named(soundName)
        print("[AlarmScheduler] initial sound=\(soundName)")

        // When snoozes are exhausted, omit the secondary intent entirely so
        // the final alarm has only a Stop button and cannot be snoozed.
        let secondaryIntent: (any LiveActivityIntent)?
        if snoozesRemaining > 0 {
            secondaryIntent = SnoozeAlarmIntent(alarmID: config.id.uuidString)
        } else {
            secondaryIntent = nil
        }

        // Schedule the countdown to start at `intendedFireDate - preAlert`
        // so the alert rings at the user's intended time after the
        // countdown elapses. For repeating alarms we shift the
        // hour/minute components instead.
        let schedule = buildScheduleShifted(
            intendedFireDate: intendedFireDate,
            config: config,
            shiftSeconds: preAlertSeconds
        )

        // If preAlertSeconds is 0, omit countdownDuration AND the countdown
        // presentation to keep AlarmKit happy (presentation is invalid
        // without a countdownDuration).
        let countdownDuration: Alarm.CountdownDuration? = preAlertSeconds > 0
            ? .init(preAlert: preAlertSeconds, postAlert: nil)
            : nil

        let alarmConfig = AlarmManager.AlarmConfiguration<AlarmioMetadata>(
            countdownDuration: countdownDuration,
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: config.id.uuidString),
            secondaryIntent: secondaryIntent,
            sound: sound
        )

        _ = try await manager.schedule(id: config.id, configuration: alarmConfig)
        print("[AlarmScheduler] scheduled successfully")
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

    /// Maximum Live Activity countdown window. Alarms with more headroom
    /// than this cap at this length; closer ones use as much as fits.
    /// Shift is always a whole number of minutes so the shifted `time`
    /// (hour+minute, seconds dropped) equals the intended ring time
    /// minus exactly `preAlert` seconds — no drift.
    static let preAlertLeadSeconds: TimeInterval = 3600

    /// Minimum gap between "now" and the shifted `time` for a repeating
    /// alarm. AlarmKit's `.relative` defers to next week if `time` lands
    /// at or before the current wall-clock minute. 15s keeps us safe.
    static let minShiftedFutureSeconds: TimeInterval = 15

    /// Pick a preAlert countdown length.
    ///
    /// Alarms are always set on the minute (user picks minute precision),
    /// so the shift must always be a whole number of minutes — otherwise
    /// AlarmKit drops the seconds component and the ring time drifts.
    ///
    /// Strategy: try the longest minute-multiple shift that (1) fits
    /// inside usable headroom and (2) keeps the shifted time ≥15s in the
    /// future. If none fit, preAlert=0, no countdown.
    func pickPreAlertSeconds(intendedFireDate: Date, isRepeating: Bool, now: Date = Date()) -> TimeInterval {
        let headroom = intendedFireDate.timeIntervalSince(now)
        let usableHeadroom = headroom - Self.schedulingBufferSeconds
        guard usableHeadroom > 0 else { return 0 }

        let maxCandidate = min(Self.preAlertLeadSeconds, usableHeadroom)
        let maxMinutes = Int(floor(maxCandidate / 60.0))
        guard maxMinutes >= 1 else { return 0 }

        // Walk from longest to shortest minute-multiple until one fits.
        for minutes in stride(from: maxMinutes, through: 1, by: -1) {
            let candidate = TimeInterval(minutes * 60)
            let shifted = intendedFireDate.addingTimeInterval(-candidate)
            if shifted.timeIntervalSince(now) >= Self.minShiftedFutureSeconds {
                return candidate
            }
        }
        return 0
    }

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

    /// Shifted schedule: the countdown starts `shiftSeconds` before the
    /// intended fire date, so the alert rings at the user's intended time
    /// after `AlarmKit`'s preAlert countdown elapses.
    func buildScheduleShifted(intendedFireDate: Date, config: AlarmConfiguration, shiftSeconds: TimeInterval) -> Alarm.Schedule {
        if let repeatDays = config.repeatDays, !repeatDays.isEmpty {
            let weekdays = repeatDays.compactMap { mapDayIndexToWeekday($0) }
            // .relative doesn't accept absolute dates, so derive the
            // shifted hour/minute components.
            let shifted = intendedFireDate.addingTimeInterval(-shiftSeconds)
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: shifted)
            let minute = calendar.component(.minute, from: shifted)
            let intendedHour = calendar.component(.hour, from: intendedFireDate)
            let intendedMinute = calendar.component(.minute, from: intendedFireDate)
            let shiftedWeekday = calendar.component(.weekday, from: shifted)
            let intendedWeekday = calendar.component(.weekday, from: intendedFireDate)
            print("[AlarmScheduler.buildSchedule] REPEATING — repeatDays(0=Sun)=\(repeatDays), weekdays=\(weekdays)")
            print("[AlarmScheduler.buildSchedule]   intended=\(intendedHour):\(String(format: "%02d", intendedMinute)) weekday=\(intendedWeekday) (1=Sun)")
            print("[AlarmScheduler.buildSchedule]   shifted =\(hour):\(String(format: "%02d", minute)) weekday=\(shiftedWeekday) (1=Sun)  shiftSeconds=\(Int(shiftSeconds))")
            if shiftedWeekday != intendedWeekday {
                print("[AlarmScheduler.buildSchedule]   ⚠️ shift crossed a day boundary — selected weekdays no longer match the shifted time's weekday")
            }
            return .relative(.init(
                time: .init(hour: hour, minute: minute),
                repeats: .weekly(weekdays)
            ))
        }
        print("[AlarmScheduler.buildSchedule] ONE-TIME fixed=\(intendedFireDate.addingTimeInterval(-shiftSeconds))")
        return .fixed(intendedFireDate.addingTimeInterval(-shiftSeconds))
    }

    /// Legacy entry point kept for tests. Uses the full preAlertLeadSeconds.
    func buildSchedule(from config: AlarmConfiguration, referenceDate: Date = Date()) -> Alarm.Schedule? {
        guard let intended = buildIntendedFireDate(from: config, referenceDate: referenceDate) else {
            return nil
        }
        return buildScheduleShifted(
            intendedFireDate: intended,
            config: config,
            shiftSeconds: Self.preAlertLeadSeconds
        )
    }

    private func buildAttributes(
        from config: AlarmConfiguration,
        snoozesRemaining: Int,
        includeCountdown: Bool = true
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

        // Countdown presentation renders the pre-alert Live Activity card
        // ("Alarm ringing soon 1:32 / Skip"). Only include it when the
        // config has a countdownDuration — AlarmKit rejects the schedule
        // if the presentation is present without a matching duration.
        let countdownContent: AlarmPresentation.Countdown? = includeCountdown
            ? AlarmPresentation.Countdown(
                title: "Alarm ringing soon",
                pauseButton: AlarmButton(
                    text: "Skip",
                    textColor: .white,
                    systemImageName: "forward.fill"
                )
            )
            : nil

        return AlarmAttributes<AlarmioMetadata>(
            presentation: AlarmPresentation(alert: alert, countdown: countdownContent),
            tintColor: Color(hex: "3A6EAA")
        )
    }

    func buildCountdownDuration(from config: AlarmConfiguration) -> Alarm.CountdownDuration {
        let snoozeSeconds = TimeInterval(config.snoozeInterval * 60)
        return Alarm.CountdownDuration(preAlert: nil, postAlert: snoozeSeconds)
    }

    func buildAlarmTitle(from config: AlarmConfiguration) -> LocalizedStringResource {
        if let tone = config.tone {
            let toneLabel = switch tone {
            case .calm: "Calm"
            case .encourage: "Encouraging"
            case .push: "Motivating"
            case .strict: "Strict"
            case .fun: "Fun"
            case .other: "Custom"
            }
            return "\(toneLabel) Wake Up"
        }
        return "Wake Up"
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
