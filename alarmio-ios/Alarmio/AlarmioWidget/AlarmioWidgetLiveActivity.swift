//
//  AlarmioWidgetLiveActivity.swift
//  AlarmioWidget
//
//  Created by Nicholas Towery on 4/9/26.
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// Live Activity for AlarmKit-scheduled alarms. Renders the pre-alert
/// countdown card ("Alarm ringing soon 1:32") on the lock screen and in
/// the Dynamic Island. AlarmKit owns the Activity lifecycle — we never
/// call `Activity.request`; the system auto-starts and auto-ends this
/// activity based on the AlarmConfiguration's `countdownDuration.preAlert`.
///
/// IMPORTANT: The generic parameter must exactly match the `AlarmioMetadata`
/// type the main app uses in `AlarmAttributes<AlarmioMetadata>`. Any
/// mismatch and the OS silently skips the Live Activity.
struct AlarmioWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<AlarmioMetadata>.self) { context in
            // Lock screen / banner card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alarm ringing soon")
                        .font(.headline)
                        .foregroundStyle(.white)
                    countdown(state: context.state)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(context.attributes.tintColor)
                }
                Spacer()
            }
            .padding(16)
            .activityBackgroundTint(.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Alarm")
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(state: context.state)
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    EmptyView()
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
            } compactTrailing: {
                countdown(state: context.state)
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "alarm.fill")
            }
            .keylineTint(context.attributes.tintColor)
        }
    }

    @ViewBuilder
    private func countdown(state: AlarmPresentationState) -> some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now ... countdown.fireDate, countsDown: true)
                .monospacedDigit()
                .lineLimit(1)
        case .paused(let paused):
            let remaining = Duration.seconds(paused.totalCountdownDuration - paused.previouslyElapsedDuration)
            Text(remaining.formatted(.time(pattern: .minuteSecond)))
                .monospacedDigit()
        default:
            EmptyView()
        }
    }
}
