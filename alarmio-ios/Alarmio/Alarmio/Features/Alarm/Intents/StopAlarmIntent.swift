//
//  StopAlarmIntent.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/3/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import AppIntents

struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Alarm"

    func perform() async throws -> some IntentResult {
        // Future: analytics, server sync, mark alarm as "fired today"
        return .result()
    }
}

