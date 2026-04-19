//
//  AlarmioWidgetLiveActivity.swift
//  AlarmioWidget
//
//  Created by Nicholas Towery on 4/15/26.
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

// DO NOT ADD: `.ultraThinMaterial`, `.regularMaterial`, `.thinMaterial`,
// `.glassEffect()`, `.background(.thin/.regular/.ultraThin/.ultraThick)`.
// Widget process silently fails these → `running-active-NotVisible` on
// lockscreen. Activity is alive but renders nothing. Use painted
// gradients + shapes only. (Hazard H7 — see memory alarmio_live_activity_gotchas.)

import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// Native AlarmKit-managed Live Activity. AlarmKit starts/updates/ends
/// this automatically based on `countdownDuration.preAlert` and the
/// alarm lifecycle. No `ActivityKit.Activity.request` anywhere.
///
/// Phases exposed via `context.state.mode`:
/// - `.countdown(Countdown)` — ticking down to fire (`.fireDate`)
/// - `.alert` — ringing (alert sheet takes over, brief flash here)
/// - `.paused(_)` — unused (we don't offer pause for wake alarms)
struct AlarmioWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<AlarmioMetadata>.self) { context in

            // Lock screen
            LockScreenView(context: context)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedIslandContent(context: context)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(LiveActivityTheme.accent)
                    .padding(.leading, 8)
            } compactTrailing: {
                if case let .countdown(countdown) = context.state.mode {
                    Text(timerInterval: Date()...countdown.fireDate,
                         countsDown: true,
                         showsHours: false)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: 60)
                } else {
                    Text("Ring")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            } minimal: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(LiveActivityTheme.accent)
            }
        }
    }
}

// MARK: - Theme

/// Widget-safe palette. No materials, no glassEffect.
private enum LiveActivityTheme {

    static let cardCornerRadius: CGFloat = 22
    static let base = Color(red: 0.035, green: 0.035, blue: 0.045)
    static let burgundy = Color(red: 0.31, green: 0.12, blue: 0.18)
    static let accent = Color(red: 0.227, green: 0.431, blue: 0.667)  // hex 3A6EAA
}

// MARK: - Card Background

/// Painted pseudo-glass — no materials (H7).
private struct CardBackground: View {

    var body: some View {
        ZStack {

            // Base fill
            RoundedRectangle(cornerRadius: LiveActivityTheme.cardCornerRadius, style: .continuous)
                .fill(LiveActivityTheme.base)

            // Diagonal tint wash
            RoundedRectangle(cornerRadius: LiveActivityTheme.cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            LiveActivityTheme.burgundy.opacity(0.35),
                            LiveActivityTheme.accent.opacity(0.18),
                            Color.black.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Soft top-left highlight for depth
            RoundedRectangle(cornerRadius: LiveActivityTheme.cardCornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 160
                    )
                )

            // Hairline edge stroke
            RoundedRectangle(cornerRadius: LiveActivityTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {

    let context: ActivityViewContext<AlarmAttributes<AlarmioMetadata>>

    var body: some View {
        ZStack {

            // Painted card background
            CardBackground()

            // Content stack
            HStack(alignment: .center, spacing: 12) {

                // Tinted icon chip
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [LiveActivityTheme.accent.opacity(0.55), LiveActivityTheme.accent.opacity(0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6)
                        )
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)

                // Title + rings-at line
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alarmio")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if case let .countdown(countdown) = context.state.mode {
                        Text("Rings at \(countdown.fireDate, format: .dateTime.hour().minute())")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                            .tracking(0.2)
                    } else {
                        Text("Ringing")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                            .tracking(0.2)
                    }
                }

                Spacer(minLength: 8)

                // Countdown
                if case let .countdown(countdown) = context.state.mode {
                    Text(timerInterval: Date()...countdown.fireDate,
                         countsDown: true,
                         showsHours: true)
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Dynamic Island Expanded

private struct ExpandedIslandContent: View {

    let context: ActivityViewContext<AlarmAttributes<AlarmioMetadata>>

    var body: some View {

        // Three-column HStack: countdown | divider | name. Spacer-based
        // flex keeps the divider at the true midpoint regardless of text width.
        if case let .countdown(countdown) = context.state.mode {
            HStack(spacing: 0) {

                // Left — countdown pushed toward the divider
                HStack(spacing: 0) {
                    Spacer()
                    Text(timerInterval: Date()...countdown.fireDate,
                         countsDown: true,
                         showsHours: true)
                        .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.trailing, 14)

                // Centered vertical divider
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.45),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1.5, height: 52)

                // Right — name pushed toward the divider
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alarmio")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Rings at \(countdown.fireDate, format: .dateTime.hour().minute())")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                            .tracking(0.2)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, 14)
            }
            .padding(.vertical, 4)
        } else {
            HStack {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(LiveActivityTheme.accent)
                Text("Ringing")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
