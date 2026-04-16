//
//  CountdownLiveActivity.swift
//  AlarmioWidget
//
//  Created by Parenthood ApS on 4/16/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import ActivityKit
import SwiftUI
import WidgetKit

/// Minimal diagnostic version — plain text only.
/// If this renders, we know the server push + ActivityKit pipeline works
/// and the earlier non-render was a widget UI issue (likely glassEffect).
struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownActivityAttributes.self) { context in

            // Lock screen
            VStack(alignment: .leading, spacing: 8) {
                Text("ALARMIO LIVE ACTIVITY")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))

                if let first = context.state.entries.first {
                    Text(first.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(timerInterval: Date()...first.fireDate,
                         countsDown: true,
                         showsHours: true)
                        .font(.title.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                } else {
                    Text("No alarms in window")
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Alarm")
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let first = context.state.entries.first {
                        Text(timerInterval: Date()...first.fireDate,
                             countsDown: true,
                             showsHours: false)
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let first = context.state.entries.first {
                        Text(first.title)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
            } compactTrailing: {
                if let first = context.state.entries.first {
                    Text(timerInterval: Date()...first.fireDate,
                         countsDown: true,
                         showsHours: false)
                        .monospacedDigit()
                        .frame(maxWidth: 60)
                }
            } minimal: {
                Image(systemName: "alarm.fill")
            }
        }
    }
}

#Preview("Lock Screen", as: .content, using: CountdownActivityAttributes(userID: "preview")) {
    CountdownLiveActivity()
} contentStates: {
    CountdownActivityAttributes.ContentState(
        entries: [
            .init(alarmID: "1", title: "Morning Wake Up", fireDate: .now.addingTimeInterval(600), tintHex: "3A6EAA")
        ],
        additionalCount: 0
    )
}
