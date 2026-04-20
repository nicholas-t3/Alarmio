//
//  StopAlarmIntent.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/3/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import AppIntents
import Foundation

struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Alarm"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() {}

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        AlarmDebugLog.log("stop.enter", "alarmID=\(alarmID)")
        print("[StopAlarmIntent] fired for alarmID=\(alarmID)")

        guard let uuid = UUID(uuidString: alarmID) else {
            print("[StopAlarmIntent] no alarmID, nothing to reset")
            return .result()
        }

        // Reset the snooze counter so the next fire of this alarm starts
        // fresh with maxSnoozes available again. Uses App Group defaults
        // because this intent may run in the widget extension process.
        guard let data = AppGroup.defaults.data(forKey: AppGroup.alarmConfigurationsKey),
              var alarms = try? JSONDecoder().decode([AlarmConfiguration].self, from: data),
              let index = alarms.firstIndex(where: { $0.id == uuid }) else {
            return .result()
        }

        let prevCount = alarms[index].currentSnoozeCount ?? 0
        alarms[index].currentSnoozeCount = 0
        print("[StopAlarmIntent] resetting snooze count from \(prevCount) → 0")
        if let encoded = try? JSONEncoder().encode(alarms) {
            AppGroup.defaults.set(encoded, forKey: AppGroup.alarmConfigurationsKey)
            print("[StopAlarmIntent] reset snooze count for alarm")
        }

        // AlarmKit manages the native Live Activity lifecycle — when the
        // alarm is stopped, iOS tears down the Activity automatically.
        // No ActivityKit call needed here.

        return .result()
    }
}
