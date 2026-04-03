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

nonisolated struct AlarmioMetadata: AlarmMetadata {}

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

        let attributes = buildAttributes(from: config)
        let countdownDuration = buildCountdownDuration(from: config)
        let sound: ActivityKit.AlertConfiguration.AlertSound
        if audioFileManager.hasCustomSound(for: config.id) || config.soundFileName != nil {
            let soundName = audioFileManager.soundFileName(for: config.id, configured: config.soundFileName)
            sound = .named(soundName)
        } else {
            sound = .default
        }

        let alarmConfig: AlarmManager.AlarmConfiguration<AlarmioMetadata>
        if config.snoozeCount > 0 {
            alarmConfig = AlarmManager.AlarmConfiguration(
                countdownDuration: countdownDuration,
                schedule: schedule,
                attributes: attributes,
                stopIntent: StopAlarmIntent(),
                secondaryIntent: SnoozeAlarmIntent(),
                sound: sound
            )
        } else {
            alarmConfig = AlarmManager.AlarmConfiguration(
                countdownDuration: countdownDuration,
                schedule: schedule,
                attributes: attributes,
                stopIntent: StopAlarmIntent(),
                sound: sound
            )
        }

        _ = try await manager.schedule(id: config.id, configuration: alarmConfig)
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

    // MARK: - Private Methods

    private func buildSchedule(from config: AlarmConfiguration) -> Alarm.Schedule? {
        guard let wakeTime = config.wakeTime else { return nil }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: wakeTime)
        let minute = calendar.component(.minute, from: wakeTime)

        // Repeating alarm
        if let repeatDays = config.repeatDays, !repeatDays.isEmpty {
            let weekdays = repeatDays.compactMap { mapDayIndexToWeekday($0) }
            return .relative(.init(
                time: .init(hour: hour, minute: minute),
                repeats: .weekly(weekdays)
            ))
        }

        // One-time alarm — compute next occurrence
        let components = DateComponents(hour: hour, minute: minute)
        guard let nextDate = calendar.nextDate(
            after: Date(),
            matching: components,
            matchingPolicy: .nextTime
        ) else {
            return nil
        }
        return .fixed(nextDate)
    }

    private func buildAttributes(from config: AlarmConfiguration) -> AlarmAttributes<AlarmioMetadata> {
        let title = buildAlarmTitle(from: config)

        let stopButton = AlarmButton(
            text: "STOP",
            textColor: .red,
            systemImageName: "stop.circle.fill"
        )

        let alert: AlarmPresentation.Alert
        if config.snoozeCount > 0 {
            let snoozeButton = AlarmButton(
                text: "SNOOZE",
                textColor: .black,
                systemImageName: "zzz"
            )
            alert = AlarmPresentation.Alert(
                title: title,
                stopButton: stopButton,
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .countdown
            )
        } else {
            alert = AlarmPresentation.Alert(
                title: title,
                stopButton: stopButton
            )
        }

        return AlarmAttributes<AlarmioMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: Color(hex: "3A6EAA")
        )
    }

    private func buildCountdownDuration(from config: AlarmConfiguration) -> Alarm.CountdownDuration? {
        guard config.snoozeCount > 0 else { return nil }
        let snoozeSeconds = TimeInterval(config.snoozeInterval * 60)
        return Alarm.CountdownDuration(preAlert: nil, postAlert: snoozeSeconds)
    }

    private func buildAlarmTitle(from config: AlarmConfiguration) -> LocalizedStringResource {
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

    private func mapDayIndexToWeekday(_ index: Int) -> Locale.Weekday? {
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
