//
//  AlarmStore.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/3/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI
import AlarmKit

@Observable
@MainActor
final class AlarmStore {

    // MARK: - State

    private(set) var alarms: [AlarmConfiguration] = []

    // MARK: - Dependencies

    let scheduler: AlarmScheduler
    let audioFileManager: AudioFileManager

    // MARK: - Constants

    private static let storageKey = "alarm_configurations"

    // MARK: - Factory

    static func create() -> AlarmStore {
        let audioFileManager = AudioFileManager()
        let scheduler = AlarmScheduler(audioFileManager: audioFileManager)
        return AlarmStore(scheduler: scheduler, audioFileManager: audioFileManager)
    }

    // MARK: - Init

    init(scheduler: AlarmScheduler, audioFileManager: AudioFileManager) {
        self.scheduler = scheduler
        self.audioFileManager = audioFileManager
    }

    // MARK: - Persistence

    func load() {
        let cal = Calendar.current

        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([AlarmConfiguration].self, from: data) {
            alarms = decoded
        } else {
            alarms = []
        }

        // Ensure demo alarms are always present at the bottom
        let hasDemos = alarms.contains(where: { $0.isDemo })
        if !hasDemos {
            let demos: [AlarmConfiguration] = [
                AlarmConfiguration(
                    isEnabled: true,
                    wakeTime: cal.date(from: DateComponents(hour: 6, minute: 30)),
                    repeatDays: [1, 2, 3, 4, 5],
                    tone: .calm,
                    intensity: .gentle,
                    voicePersona: .calmGuide,
                    snoozeInterval: 5,
                    isDemo: true
                ),
                AlarmConfiguration(
                    isEnabled: false,
                    wakeTime: cal.date(from: DateComponents(hour: 9, minute: 0)),
                    repeatDays: [0, 6],
                    tone: .fun,
                    intensity: .balanced,
                    voicePersona: .playful,
                    snoozeInterval: 5,
                    isDemo: true
                )
            ]
            alarms.append(contentsOf: demos)
            save()
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(alarms) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    // MARK: - CRUD

    func addAlarm(_ config: AlarmConfiguration) async {
        alarms.insert(config, at: 0)
        save()
        if config.isEnabled {
            try? await scheduler.scheduleAlarm(config)
        }
        HapticManager.shared.success()
    }

    func updateAlarm(_ config: AlarmConfiguration) async {
        guard let index = alarms.firstIndex(where: { $0.id == config.id }) else { return }
        alarms[index] = config
        save()
        try? await scheduler.toggleAlarm(config)
    }

    func deleteAlarm(id: UUID) async {
        alarms.removeAll { $0.id == id }
        save()
        try? scheduler.cancelAlarm(id: id)
        audioFileManager.deleteSound(for: id)
        HapticManager.shared.warning()
    }

    func toggleAlarm(id: UUID) async {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].isEnabled.toggle()
        save()
        try? await scheduler.toggleAlarm(alarms[index])
        HapticManager.shared.selection()
    }

    // MARK: - Accessors

    func alarm(for id: UUID) -> AlarmConfiguration? {
        alarms.first { $0.id == id }
    }

    var alarmStates: [UUID: Alarm.State] {
        scheduler.activeAlarmStates
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        await scheduler.requestAuthorization()
    }

    // MARK: - Bulk Scheduling

    func rescheduleAllEnabled() async {
        // Check which alarms AlarmKit still knows about
        let systemAlarmIds: Set<UUID>
        if let systemAlarms = try? scheduler.manager.alarms {
            systemAlarmIds = Set(systemAlarms.map(\.id))
        } else {
            systemAlarmIds = []
        }

        var didChange = false

        for index in alarms.indices {
            guard alarms[index].isEnabled else { continue }

            let isOneTime = alarms[index].repeatDays == nil || alarms[index].repeatDays?.isEmpty == true

            // If a one-time alarm is no longer in AlarmKit, it already fired — disable it
            if isOneTime && !systemAlarmIds.contains(alarms[index].id) {
                alarms[index].isEnabled = false
                didChange = true
                continue
            }

            try? await scheduler.scheduleAlarm(alarms[index])
        }

        if didChange { save() }
    }

    func startObserving() async {
        // Observation reserved for future use.
        // Auto-disable of one-time alarms is handled in rescheduleAllEnabled() on launch.
    }
}

// MARK: - Environment Key

struct AlarmStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = AlarmStore.create()
}

extension EnvironmentValues {
    var alarmStore: AlarmStore {
        get { self[AlarmStoreKey.self] }
        set { self[AlarmStoreKey.self] = newValue }
    }
}
