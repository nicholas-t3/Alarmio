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

    private static let storageKey = AppGroup.alarmConfigurationsKey

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

        let rawData = AppGroup.defaults.data(forKey: Self.storageKey)
        print("[AlarmStore.load] storageKey=\(Self.storageKey), rawData=\(rawData?.count ?? 0) bytes")

        if let data = rawData,
           let decoded = try? JSONDecoder().decode([AlarmConfiguration].self, from: data) {
            alarms = decoded
            print("[AlarmStore.load] Decoded \(decoded.count) alarm(s) from storage:")
            for (i, a) in decoded.enumerated() {
                print("  [\(i)] id=\(a.id) isDemo=\(a.isDemo) enabled=\(a.isEnabled) wake=\(a.wakeTime?.description ?? "nil")")
            }
        } else {
            alarms = []
            print("[AlarmStore.load] No decodable data → starting with empty list")
        }

        let demoCount = alarms.filter { $0.isDemo }.count
        let hasDemos = demoCount > 0
        print("[AlarmStore.load] demoCount=\(demoCount), hasDemos=\(hasDemos)")

        if !hasDemos {
            let demos: [AlarmConfiguration] = [
                AlarmConfiguration(
                    isEnabled: true,
                    wakeTime: cal.date(from: DateComponents(hour: 7, minute: 0)),
                    repeatDays: [1, 2, 3, 4, 5],
                    tone: .calm,
                    intensity: .gentle,
                    voicePersona: .calmGuide,
                    snoozeInterval: 5,
                    maxSnoozes: 3,
                    isDemo: true
                ),
                AlarmConfiguration(
                    isEnabled: true,
                    wakeTime: cal.date(from: DateComponents(hour: 6, minute: 30)),
                    repeatDays: [1, 2, 3, 4, 5],
                    tone: .encourage,
                    intensity: .balanced,
                    voicePersona: .energeticCoach,
                    snoozeInterval: 5,
                    maxSnoozes: 3,
                    isDemo: true
                ),
                AlarmConfiguration(
                    isEnabled: false,
                    wakeTime: cal.date(from: DateComponents(hour: 5, minute: 45)),
                    repeatDays: [1, 3, 5],
                    tone: .push,
                    intensity: .intense,
                    voicePersona: .hardSergeant,
                    snoozeInterval: 3,
                    maxSnoozes: 2,
                    isDemo: true
                ),
                AlarmConfiguration(
                    isEnabled: true,
                    wakeTime: cal.date(from: DateComponents(hour: 8, minute: 30)),
                    repeatDays: [0, 6],
                    tone: .fun,
                    intensity: .gentle,
                    voicePersona: .playful,
                    snoozeInterval: 10,
                    maxSnoozes: 5,
                    isDemo: true
                ),
                AlarmConfiguration(
                    isEnabled: false,
                    wakeTime: cal.date(from: DateComponents(hour: 9, minute: 15)),
                    repeatDays: nil,
                    tone: .strict,
                    intensity: .balanced,
                    voicePersona: .digitalAssistant,
                    snoozeInterval: 5,
                    maxSnoozes: 3,
                    isDemo: true
                )
            ]
            alarms.append(contentsOf: demos)
            save()
            print("[AlarmStore.load] Inserted \(demos.count) fresh demo alarms → alarms.count=\(alarms.count)")
        } else {
            print("[AlarmStore.load] Skipping demo insertion — demos already present")
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(alarms) else {
            print("[AlarmStore.save] FAILED to encode alarms (count=\(alarms.count))")
            return
        }
        AppGroup.defaults.set(data, forKey: Self.storageKey)
        let verify = AppGroup.defaults.data(forKey: Self.storageKey)?.count ?? 0
        print("[AlarmStore.save] Wrote \(data.count) bytes to storageKey=\(Self.storageKey), alarms.count=\(alarms.count), readback=\(verify) bytes")
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
        let before = alarms.count
        let target = alarms.first(where: { $0.id == id })
        print("[AlarmStore.delete] Deleting id=\(id) isDemo=\(target?.isDemo ?? false) — before=\(before)")
        alarms.removeAll { $0.id == id }
        print("[AlarmStore.delete] After removal, alarms.count=\(alarms.count)")
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
        let systemAlarms = (try? scheduler.manager.alarms) ?? []
        let systemAlarmIds = Set(systemAlarms.map(\.id))
        let localAlarmIds = Set(alarms.map(\.id))

        logReconciliation(systemAlarms: systemAlarms, systemAlarmIds: systemAlarmIds, localAlarmIds: localAlarmIds)

        // Cancel orphans: AlarmKit has them scheduled but we don't know
        // about them locally. Without this, a stale schedule from a prior
        // install/dev session fires forever with no UI to turn it off.
        let orphans = systemAlarmIds.subtracting(localAlarmIds)
        for orphanId in orphans {
            print("[AlarmStore] Cancelling orphan id=\(orphanId)")
            try? scheduler.cancelAlarm(id: orphanId)
        }

        var didChange = false

        for index in alarms.indices {
            // If an alarm is disabled locally but still scheduled in AlarmKit,
            // cancel it — otherwise it rings with no visible toggle to stop it.
            guard alarms[index].isEnabled else {
                if systemAlarmIds.contains(alarms[index].id) {
                    print("[AlarmStore] Cancelling disabled-but-scheduled id=\(alarms[index].id)")
                    try? scheduler.cancelAlarm(id: alarms[index].id)
                }
                continue
            }

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

    // MARK: - Reconciliation Logging

    /// Log-only reconciliation: dumps what AlarmKit has scheduled vs what
    /// we have locally so we can identify phantom/orphan alarms. Cancel
    /// logic is intentionally NOT here yet — we want evidence first.
    private func logReconciliation(
        systemAlarms: [Alarm],
        systemAlarmIds: Set<UUID>,
        localAlarmIds: Set<UUID>
    ) {
        print("[AlarmStore] === Launch reconciliation ===")
        print("[AlarmStore] Local alarms: \(alarms.count)")
        for a in alarms {
            let wake = a.wakeTime.map { Self.timeFormatter.string(from: $0) } ?? "—"
            print("[AlarmStore]   local id=\(a.id) enabled=\(a.isEnabled) wake=\(wake) repeat=\(a.repeatDays ?? [])")
        }
        print("[AlarmStore] AlarmKit system alarms: \(systemAlarms.count)")
        for a in systemAlarms {
            print("[AlarmStore]   system id=\(a.id) state=\(a.state) schedule=\(String(describing: a.schedule))")
        }

        let orphans = systemAlarmIds.subtracting(localAlarmIds)
        if orphans.isEmpty {
            print("[AlarmStore] No orphans detected")
        } else {
            print("[AlarmStore] ⚠️ Orphan alarms (scheduled in AlarmKit, missing locally): \(orphans.count)")
            for id in orphans {
                if let match = systemAlarms.first(where: { $0.id == id }) {
                    print("[AlarmStore]   ⚠️ orphan id=\(id) schedule=\(String(describing: match.schedule))")
                } else {
                    print("[AlarmStore]   ⚠️ orphan id=\(id)")
                }
            }
        }

        let disabledButScheduled = alarms
            .filter { !$0.isEnabled && systemAlarmIds.contains($0.id) }
            .map(\.id)
        if !disabledButScheduled.isEmpty {
            print("[AlarmStore] ⚠️ Disabled locally but still scheduled in AlarmKit: \(disabledButScheduled)")
        }
        print("[AlarmStore] === End reconciliation ===")
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

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
