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

        guard let schedule = buildSchedule(from: config) else {
            print("[AlarmScheduler] Cannot build schedule — no wake time set")
            return
        }

        let maxSnoozes = config.maxSnoozes ?? 3
        let currentCount = config.currentSnoozeCount ?? 0
        let snoozesRemaining = max(0, maxSnoozes - currentCount)
        print("[AlarmScheduler] scheduling alarm=\(config.id) snoozesRemaining=\(snoozesRemaining) (count=\(currentCount)/\(maxSnoozes))")

        let attributes = buildAttributes(from: config, snoozesRemaining: snoozesRemaining)

        // POC: initial fire always plays alarm1.mp3. Snooze chain rotates
        // through alarm2 → alarm3 → alarm1 via SnoozeAlarmIntent.
        let soundName = "alarm1.mp3"
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

        // The Live Activity countdown card shows for `preAlertLeadSeconds`
        // before the alarm fires. We also shifted the scheduled fire date
        // back by the same amount in buildSchedule() so the alert rings at
        // the user's intended wake time.
        let alarmConfig = AlarmManager.AlarmConfiguration<AlarmioMetadata>(
            countdownDuration: .init(preAlert: Self.preAlertLeadSeconds, postAlert: nil),
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

    /// Number of seconds before the user's wake time that the Live Activity
    /// countdown should begin. Must match the `preAlert` value we pass into
    /// `AlarmConfiguration.countdownDuration`.
    static let preAlertLeadSeconds: TimeInterval = 90

    func buildSchedule(from config: AlarmConfiguration, referenceDate: Date = Date()) -> Alarm.Schedule? {
        guard let wakeTime = config.wakeTime else { return nil }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: wakeTime)
        let minute = calendar.component(.minute, from: wakeTime)

        // Repeating alarm — AlarmKit relative schedules don't support a
        // sub-minute offset, so we subtract the lead time from the
        // components directly by shifting minutes back. For the POC, we
        // assume the user accepts that repeating alarms may ring ~1-2 min
        // before the displayed time due to the countdown lead.
        if let repeatDays = config.repeatDays, !repeatDays.isEmpty {
            let weekdays = repeatDays.compactMap { mapDayIndexToWeekday($0) }
            guard !weekdays.isEmpty else { return nil }

            // Shift back by preAlertLeadSeconds. 90s = 1 min 30s so subtract
            // 2 whole minutes and let the system handle the 30s drift.
            let shiftMinutes = Int(Self.preAlertLeadSeconds / 60)
            var adjustedHour = hour
            var adjustedMinute = minute - shiftMinutes
            if adjustedMinute < 0 {
                adjustedMinute += 60
                adjustedHour = (adjustedHour - 1 + 24) % 24
            }
            return .relative(.init(
                time: .init(hour: adjustedHour, minute: adjustedMinute),
                repeats: .weekly(weekdays)
            ))
        }

        // One-time alarm — compute next occurrence, then shift back so the
        // alert fires at the user's intended wake time after the 90s
        // countdown elapses.
        let components = DateComponents(hour: hour, minute: minute)
        guard let nextDate = calendar.nextDate(
            after: referenceDate,
            matching: components,
            matchingPolicy: .nextTime
        ) else {
            return nil
        }
        let countdownStart = nextDate.addingTimeInterval(-Self.preAlertLeadSeconds)
        return .fixed(countdownStart)
    }

    private func buildAttributes(from config: AlarmConfiguration, snoozesRemaining: Int) -> AlarmAttributes<AlarmioMetadata> {
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
        // ("Alarm ringing soon 1:32 / Skip"). Required whenever
        // countdownDuration.preAlert is set on the AlarmConfiguration,
        // otherwise AlarmManager.schedule throws at runtime.
        let countdownContent = AlarmPresentation.Countdown(
            title: "Alarm ringing soon",
            pauseButton: AlarmButton(
                text: "Skip",
                textColor: .white,
                systemImageName: "forward.fill"
            )
        )

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
