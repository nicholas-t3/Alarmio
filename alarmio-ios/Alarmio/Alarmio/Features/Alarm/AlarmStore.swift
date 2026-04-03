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
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([AlarmConfiguration].self, from: data) else {
            alarms = []
            return
        }
        alarms = decoded
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
        var previousIds: Set<UUID> = []

        for await systemAlarms in scheduler.manager.alarmUpdates {
            let currentIds = Set(systemAlarms.map(\.id))

            // Detect one-time alarms that disappeared (user stopped them)
            let disappeared = previousIds.subtracting(currentIds)
            for id in disappeared {
                guard let index = alarms.firstIndex(where: { $0.id == id }),
                      alarms[index].isEnabled,
                      alarms[index].repeatDays == nil || alarms[index].repeatDays?.isEmpty == true
                else { continue }

                alarms[index].isEnabled = false
                save()
            }

            previousIds = currentIds
        }
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
