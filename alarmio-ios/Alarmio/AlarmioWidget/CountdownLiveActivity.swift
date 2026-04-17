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

/// Lock-screen + Dynamic Island UI for the consolidated countdown card.
///
/// Intentionally avoids `.ultraThinMaterial` and `.glassEffect` — both
/// flip the Activity to `running-active-NotVisible` in the widget
/// process. Visual depth is painted with gradients and shapes instead.
/// See memory: alarmio_live_activity_gotchas.
struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownActivityAttributes.self) { context in

            // Lock screen
            LockScreenView(state: context.state)

        } dynamicIsland: { context in
            DynamicIsland {
                // Leading/trailing registered but empty — the island needs
                // them declared, but we render everything in .bottom so the
                // notch can't clip content and rows share a width.
                DynamicIslandExpandedRegion(.leading) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedContent(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(LiveActivityTheme.accent(for: context.state.entries.first))
                    .padding(.leading, 8)
            } compactTrailing: {
                if let first = context.state.entries.first {
                    Text(timerInterval: Date()...first.fireDate,
                         countsDown: true,
                         showsHours: false)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: 60)
                }
            } minimal: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(LiveActivityTheme.accent(for: context.state.entries.first))
            }
        }
    }
}

// MARK: - Theme

/// Widget-safe palette. No materials, no glassEffect.
private enum LiveActivityTheme {

    static let cardCornerRadius: CGFloat = 22
    static let innerCornerRadius: CGFloat = 14

    /// Deep near-black base for the card.
    static let base = Color(red: 0.035, green: 0.035, blue: 0.045)

    /// Signature burgundy tint, used as the secondary color in the
    /// background gradient.
    static let burgundy = Color(red: 0.31, green: 0.12, blue: 0.18)

    /// Converts a stored tintHex string into a SwiftUI Color.
    static func tint(from hex: String) -> Color {
        Color(hex: hex) ?? .white
    }

    /// Returns an accent tint for an optional entry, falling back to
    /// a soft white if no entry is present.
    static func accent(for entry: CountdownActivityAttributes.Entry?) -> Color {
        guard let entry else { return .white.opacity(0.9) }
        return tint(from: entry.tintHex)
    }
}

// MARK: - Color hex init (widget-local)

private extension Color {
    /// Minimal hex → Color initializer duplicated locally so the widget
    /// target does not depend on the main app's `Global/Extensions/Color.swift`.
    init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else {
            return nil
        }
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}

// MARK: - Card Background

/// Painted pseudo-glass: near-black base, diagonal tint gradient,
/// radial highlight in the top-left, hairline stroke. Zero materials.
private struct CardBackground: View {

    /// Tint sampled from the primary entry (or neutral if empty).
    let tint: Color

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
                            tint.opacity(0.18),
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

    let state: CountdownActivityAttributes.ContentState

    private var primaryTint: Color {
        LiveActivityTheme.accent(for: state.entries.first)
    }

    var body: some View {
        ZStack {

            // Painted card background
            CardBackground(tint: primaryTint)

            // Content stack
            VStack(alignment: .leading, spacing: 12) {

                if state.entries.isEmpty {
                    emptyState
                } else {
                    // Primary alarm
                    if let first = state.entries.first {
                        PrimaryAlarmRow(entry: first)
                    }

                    // Secondary alarm
                    if state.entries.count > 1 {
                        dividerLine
                        SecondaryAlarmRow(entry: state.entries[1])
                    }

                    // Overflow footer
                    if state.additionalCount > 0 {
                        overflowFooter
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyState: some View {
        Text("No alarms in window")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 0.5)
    }

    private var overflowFooter: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.white.opacity(0.35))
                .frame(width: 3, height: 3)
            Text("+ \(state.additionalCount) more \(state.additionalCount == 1 ? "alarm" : "alarms")")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .tracking(0.3)
        }
        .padding(.top, 2)
    }
}

// MARK: - Primary Alarm Row

private struct PrimaryAlarmRow: View {

    let entry: CountdownActivityAttributes.Entry

    private var tint: Color { LiveActivityTheme.tint(from: entry.tintHex) }

    var body: some View {

        // Icon chip + title/subtitle on left, countdown on right
        HStack(alignment: .center, spacing: 12) {

            // Tinted icon chip
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.55), tint.opacity(0.25)],
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

            // Title + ring-at line
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Rings at \(entry.fireDate, format: .dateTime.hour().minute())")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .tracking(0.2)
            }

            Spacer(minLength: 8)

            // Countdown
            Text(timerInterval: Date()...entry.fireDate,
                 countsDown: true,
                 showsHours: true)
                .font(.title2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Secondary Alarm Row

private struct SecondaryAlarmRow: View {

    let entry: CountdownActivityAttributes.Entry

    private var tint: Color { LiveActivityTheme.tint(from: entry.tintHex) }

    var body: some View {

        // Smaller tint dot + title + compact countdown
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(tint.opacity(0.85))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
                .frame(width: 8, height: 8)

            Text(entry.title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(timerInterval: Date()...entry.fireDate,
                 countsDown: true,
                 showsHours: true)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.white.opacity(0.72))
        }
    }
}

// MARK: - Dynamic Island

private struct ExpandedContent: View {

    let state: CountdownActivityAttributes.ContentState

    var body: some View {

        // Three-column HStack: countdown half, divider, name half.
        // Each half owns equal flex via Spacer — divider lands at true midpoint
        // regardless of text width, and padding controls gap to the divider.
        if let first = state.entries.first {
            HStack(spacing: 0) {

                // Left half — countdown pushed toward the divider
                HStack(spacing: 0) {
                    Spacer()
                    Text(timerInterval: Date()...first.fireDate,
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

                // Right half — name pushed toward the divider
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(first.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Rings at \(first.fireDate, format: .dateTime.hour().minute())")
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
        }
    }
}

// MARK: - Previews

#Preview("Lock — single alarm",
         as: .content,
         using: CountdownActivityAttributes(userID: "preview")) {
    CountdownLiveActivity()
} contentStates: {
    CountdownActivityAttributes.ContentState(
        entries: [
            .init(alarmID: "1",
                  title: "Morning Wake Up",
                  fireDate: .now.addingTimeInterval(3600 * 2 + 1500),
                  tintHex: "3A6EAA")
        ],
        additionalCount: 0
    )
}

#Preview("Lock — two alarms",
         as: .content,
         using: CountdownActivityAttributes(userID: "preview")) {
    CountdownLiveActivity()
} contentStates: {
    CountdownActivityAttributes.ContentState(
        entries: [
            .init(alarmID: "1",
                  title: "Morning Wake Up",
                  fireDate: .now.addingTimeInterval(3600 * 2 + 1500),
                  tintHex: "3A6EAA"),
            .init(alarmID: "2",
                  title: "Flight Check-in",
                  fireDate: .now.addingTimeInterval(3600 * 6),
                  tintHex: "8A3A3A")
        ],
        additionalCount: 0
    )
}

#Preview("Lock — two + overflow",
         as: .content,
         using: CountdownActivityAttributes(userID: "preview")) {
    CountdownLiveActivity()
} contentStates: {
    CountdownActivityAttributes.ContentState(
        entries: [
            .init(alarmID: "1",
                  title: "Morning Wake Up",
                  fireDate: .now.addingTimeInterval(1800),
                  tintHex: "3A6EAA"),
            .init(alarmID: "2",
                  title: "Standup",
                  fireDate: .now.addingTimeInterval(3600 * 3),
                  tintHex: "8A3A3A")
        ],
        additionalCount: 3
    )
}

#Preview("Lock — unnamed fallback",
         as: .content,
         using: CountdownActivityAttributes(userID: "preview")) {
    CountdownLiveActivity()
} contentStates: {
    CountdownActivityAttributes.ContentState(
        entries: [
            .init(alarmID: "1",
                  title: "Alarmio Alarm",
                  fireDate: .now.addingTimeInterval(600),
                  tintHex: "3A6EAA")
        ],
        additionalCount: 0
    )
}

#Preview("Island — compact",
         as: .dynamicIsland(.compact),
         using: CountdownActivityAttributes(userID: "preview")) {
    CountdownLiveActivity()
} contentStates: {
    CountdownActivityAttributes.ContentState(
        entries: [
            .init(alarmID: "1",
                  title: "Morning Wake Up",
                  fireDate: .now.addingTimeInterval(1500),
                  tintHex: "3A6EAA")
        ],
        additionalCount: 0
    )
}

#Preview("Island — minimal",
         as: .dynamicIsland(.minimal),
         using: CountdownActivityAttributes(userID: "preview")) {
    CountdownLiveActivity()
} contentStates: {
    CountdownActivityAttributes.ContentState(
        entries: [
            .init(alarmID: "1",
                  title: "Morning Wake Up",
                  fireDate: .now.addingTimeInterval(1500),
                  tintHex: "3A6EAA")
        ],
        additionalCount: 0
    )
}

#Preview("Island — expanded",
         as: .dynamicIsland(.expanded),
         using: CountdownActivityAttributes(userID: "preview")) {
    CountdownLiveActivity()
} contentStates: {
    CountdownActivityAttributes.ContentState(
        entries: [
            .init(alarmID: "1",
                  title: "Morning Wake Up",
                  fireDate: .now.addingTimeInterval(3600 * 2),
                  tintHex: "3A6EAA"),
            .init(alarmID: "2",
                  title: "Flight Check-in",
                  fireDate: .now.addingTimeInterval(3600 * 6),
                  tintHex: "8A3A3A")
        ],
        additionalCount: 2
    )
}
