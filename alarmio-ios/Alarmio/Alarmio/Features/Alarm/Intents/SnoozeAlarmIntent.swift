//
//  SnoozeAlarmIntent.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/3/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import AppIntents

struct SnoozeAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Snooze Alarm"

    func perform() async throws -> some IntentResult {
        // Future: increment snooze count, enforce max snooze limit,
        // analytics tracking via shared UserDefaults/persistence
        return .result()
    }
}

