//
//  AlarmStoreTests.swift
//  AlarmioTests
//
//  Created by Parenthood ApS on 4/3/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Testing
import Foundation
@testable import Alarmio

@MainActor
struct AlarmStoreTests {

    // MARK: - Helpers

    private func makeStore() -> AlarmStore {
        let store = AlarmStore.create()
        // Clear any persisted state from previous runs
        UserDefaults.standard.removeObject(forKey: "alarm_configurations")
        store.load()
        return store
    }

    private func makeConfig(
        hour: Int = 7,
        minute: Int = 0,
        repeatDays: [Int]? = nil,
        isDemo: Bool = false
    ) -> AlarmConfiguration {
        let cal = Calendar.current
        return AlarmConfiguration(
            isEnabled: true,
            wakeTime: cal.date(from: DateComponents(hour: hour, minute: minute)),
            repeatDays: repeatDays,
            tone: .calm,
            voicePersona: .soothingSarah,
            snoozeInterval: 5,
            isDemo: isDemo
        )
    }

    // MARK: - CRUD

    @Test("addAlarm inserts at index 0")
    func addAlarmInsertsAtTop() async {
        let store = makeStore()
        // Store has 2 demos after load
        let demoCount = store.alarms.count

        let newAlarm = makeConfig(hour: 8, minute: 30)
        await store.addAlarm(newAlarm)

        #expect(store.alarms.count == demoCount + 1)
        #expect(store.alarms[0].id == newAlarm.id)
        #expect(store.alarms[0].isDemo == false)
    }

    @Test("deleteAlarm removes by ID")
    func deleteAlarmRemoves() async {
        let store = makeStore()
        let alarm = makeConfig()
        await store.addAlarm(alarm)
        let countAfterAdd = store.alarms.count

        await store.deleteAlarm(id: alarm.id)

        #expect(store.alarms.count == countAfterAdd - 1)
        #expect(store.alarm(for: alarm.id) == nil)
    }

    @Test("toggleAlarm flips isEnabled")
    func toggleAlarmFlips() async {
        let store = makeStore()
        let alarm = makeConfig()
        await store.addAlarm(alarm)

        #expect(store.alarms[0].isEnabled == true)
        await store.toggleAlarm(id: alarm.id)
        #expect(store.alarm(for: alarm.id)?.isEnabled == false)
        await store.toggleAlarm(id: alarm.id)
        #expect(store.alarm(for: alarm.id)?.isEnabled == true)
    }

    @Test("updateAlarm replaces correct alarm")
    func updateAlarmReplaces() async {
        let store = makeStore()
        var alarm = makeConfig(hour: 7, minute: 0)
        await store.addAlarm(alarm)

        alarm.snoozeInterval = 10
        await store.updateAlarm(alarm)

        #expect(store.alarm(for: alarm.id)?.snoozeInterval == 10)
    }

    // MARK: - Persistence Round-Trip

    @Test("Encode-decode preserves all fields")
    func roundTripPreservesFields() {
        let cal = Calendar.current
        let original = AlarmConfiguration(
            isEnabled: true,
            wakeTime: cal.date(from: DateComponents(hour: 6, minute: 30)),
            repeatDays: [1, 2, 3, 4, 5],
            leaveTime: cal.date(from: DateComponents(hour: 8, minute: 0)),
            tone: .push,
            intensity: .intense,
            voicePersona: .theDad,
            contentFlags: [.currentTime, .motivation],
            snoozeInterval: 10,
            customPrompt: "Test prompt",
            difficulty: .veryHard,
            whyContext: .work,
            soundFileName: "custom.mp3",
            isDemo: false
        )

        let data = try! JSONEncoder().encode([original])
        let decoded = try! JSONDecoder().decode([AlarmConfiguration].self, from: data)

        #expect(decoded.count == 1)
        #expect(decoded[0].id == original.id)
        #expect(decoded[0].isEnabled == original.isEnabled)
        #expect(decoded[0].repeatDays == original.repeatDays)
        #expect(decoded[0].tone == original.tone)
        #expect(decoded[0].intensity == original.intensity)
        #expect(decoded[0].voicePersona == original.voicePersona)
        #expect(decoded[0].contentFlags == original.contentFlags)
        #expect(decoded[0].snoozeInterval == original.snoozeInterval)
        #expect(decoded[0].customPrompt == original.customPrompt)
        #expect(decoded[0].difficulty == original.difficulty)
        #expect(decoded[0].whyContext == original.whyContext)
        #expect(decoded[0].soundFileName == original.soundFileName)
        #expect(decoded[0].isDemo == original.isDemo)
    }

    @Test("isDemo flag survives round-trip")
    func demoFlagRoundTrip() {
        let config = AlarmConfiguration(isDemo: true)
        let data = try! JSONEncoder().encode([config])
        let decoded = try! JSONDecoder().decode([AlarmConfiguration].self, from: data)
        #expect(decoded[0].isDemo == true)
    }

    @Test("Optional nil fields survive round-trip")
    func nilFieldsRoundTrip() {
        let config = AlarmConfiguration()
        let data = try! JSONEncoder().encode([config])
        let decoded = try! JSONDecoder().decode([AlarmConfiguration].self, from: data)
        #expect(decoded[0].wakeTime == nil)
        #expect(decoded[0].repeatDays == nil)
        #expect(decoded[0].tone == nil)
        #expect(decoded[0].soundFileName == nil)
    }

    // MARK: - Demo Injection

    @Test("Fresh load injects 2 demos")
    func freshLoadInjectsDemos() {
        UserDefaults.standard.removeObject(forKey: "alarm_configurations")
        let store = AlarmStore.create()
        store.load()

        let demos = store.alarms.filter(\.isDemo)
        #expect(demos.count == 2)
    }

    @Test("Load with existing demos does not duplicate")
    func existingDemosNotDuplicated() {
        UserDefaults.standard.removeObject(forKey: "alarm_configurations")
        let store = AlarmStore.create()
        store.load() // Injects demos

        let firstCount = store.alarms.count
        store.load() // Load again

        #expect(store.alarms.count == firstCount)
        #expect(store.alarms.filter(\.isDemo).count == 2)
    }

    @Test("New alarms appear before demos")
    func newAlarmsBeforeDemos() async {
        let store = makeStore()
        let alarm = makeConfig()
        await store.addAlarm(alarm)

        // First alarm should be the new one, demos after
        #expect(store.alarms[0].isDemo == false)
        #expect(store.alarms[0].id == alarm.id)

        let firstDemoIndex = store.alarms.firstIndex(where: \.isDemo)
        #expect(firstDemoIndex != nil)
        #expect(firstDemoIndex! > 0)
    }
}
