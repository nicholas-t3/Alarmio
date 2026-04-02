//
//  HomeViewModel.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class HomeViewModel {

    // MARK: - State

    var alarms: [AlarmConfiguration] = []

    // MARK: - Actions

    func loadAlarms() {
        alarms = Self.mockAlarms()
    }

    func toggleAlarm(_ id: UUID) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].isEnabled.toggle()
        HapticManager.shared.selection()
    }

    func addAlarm(_ alarm: AlarmConfiguration) {
        alarms.insert(alarm, at: 0)
        HapticManager.shared.success()
    }

    func deleteAlarm(_ id: UUID) {
        alarms.removeAll { $0.id == id }
        HapticManager.shared.warning()
    }

    // MARK: - Mock Data

    private static func mockAlarms() -> [AlarmConfiguration] {
        let cal = Calendar.current

        return [
            AlarmConfiguration(
                isEnabled: true,
                wakeTime: cal.date(from: DateComponents(hour: 6, minute: 30)),
                repeatDays: [1, 2, 3, 4, 5],
                tone: .calm,
                intensity: .gentle,
                voicePersona: .calmGuide,
                snoozeCount: 3,
                snoozeInterval: 5
            ),
            AlarmConfiguration(
                isEnabled: true,
                wakeTime: cal.date(from: DateComponents(hour: 7, minute: 45)),
                repeatDays: [1, 3, 5],
                tone: .push,
                intensity: .intense,
                voicePersona: .energeticCoach,
                snoozeCount: 2,
                snoozeInterval: 3
            ),
            AlarmConfiguration(
                isEnabled: false,
                wakeTime: cal.date(from: DateComponents(hour: 9, minute: 0)),
                repeatDays: [0, 6],
                tone: .fun,
                intensity: .balanced,
                voicePersona: .playful,
                snoozeCount: 5,
                snoozeInterval: 5
            ),
        ]
    }
}
