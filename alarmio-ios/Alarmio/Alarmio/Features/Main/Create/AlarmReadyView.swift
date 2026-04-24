//
//  AlarmReadyView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/19/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

/// Standalone "alarm is ready" confirmation concept. Replaces the old
/// confirmation card that was essentially a duplicate of the edit sheet.
/// Focus is on one cinematic moment — wake time displayed big, the voice
/// who'll speak to the user, a play button, and a back/edit arrow.
///
/// No duplicate rows of tone/reason/intensity toggles — those live in the
/// create screen and the edit sheet. This screen is the payoff.
///
/// Bindings + callbacks are intentionally minimal so the parent owns all
/// state; this view renders, animates, and forwards tap events.
struct AlarmReadyView: View {

    // MARK: - Environment

    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - Constants

    let alarm: AlarmConfiguration
    let isPlaying: Bool
    let isScheduling: Bool
    /// Drives the Play/Stop glyph swap + waveform activity.
    let bands: [CGFloat]
    /// Tapping the big center play pill.
    let onTogglePlay: () -> Void
    /// Tapping the Edit pill at the top-left. Returns the user to the
    /// create screen with its state intact.
    let onEdit: () -> Void
    /// Tapping the name row — parent opens the rename sheet.
    let onRenameTap: () -> Void
    /// Tapping the big Schedule button at the bottom.
    let onSchedule: () -> Void

    // MARK: - State

    @State private var heroVisible = false
    @State private var detailsVisible = false
    @State private var buttonVisible = false
    @State private var editArrowFlipped = false

    // MARK: - Body

    var body: some View {
        ZStack {

            VStack(spacing: 0) {

                Spacer().frame(height: 24 * deviceInfo.spacingScale)

                // Hero: wake time
                heroBlock
                    .padding(.top, 64 * deviceInfo.spacingScale)
                    .premiumBlur(isVisible: heroVisible, delay: 0, duration: 0.55)

                Spacer().frame(height: 28 * deviceInfo.spacingScale)

                // Details + name + edit, staggered in together.
                VStack(spacing: 12 * deviceInfo.spacingScale) {
                    detailsCard
                    nameRow
                    editButton
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .premiumBlur(isVisible: detailsVisible, delay: 0, duration: 0.45)

                Spacer(minLength: 0)

                // Schedule button
                scheduleButton
                    .padding(.horizontal, AppButtons.horizontalPadding)
                    .padding(.bottom, AppSpacing.screenBottom)
                    .premiumBlur(isVisible: buttonVisible, delay: 0, duration: 0.4)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(120))
            heroVisible = true
            try? await Task.sleep(for: .milliseconds(240))
            detailsVisible = true
            try? await Task.sleep(for: .milliseconds(280))
            buttonVisible = true
        }
    }

    // MARK: - Edit Button

    /// Full-width "Edit" button sitting beneath the name row. Takes the
    /// user back to the create screen with its state intact — no
    /// generating phase between. The arrow flips 180° on tap as a
    /// microinteraction before the parent transitions.
    private var editButton: some View {
        Button {
            HapticManager.shared.buttonTap()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                editArrowFlipped = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                onEdit()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13, weight: .semibold))
                    .rotationEffect(.degrees(editArrowFlipped ? -180 : 0))
                Text("Edit")
                    .font(AppTypography.labelMedium)
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero

    private var heroBlock: some View {
        VStack(spacing: 10) {

            // Small label
            Text("YOUR ALARM")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Wake time, huge
            Text(wakeTimeString)
                .font(.system(size: 72, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .tracking(-1.5)
                .shadow(color: Color(hex: "F5B971").opacity(0.25), radius: 28, y: 0)
                .contentTransition(.numericText())

            // Schedule summary (weekdays, one-time, etc.)
            Text(scheduleSummary)
                .font(AppTypography.labelMedium)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 16 * deviceInfo.spacingScale) {

            // Voice row
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(voiceName)
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white)
                    Text(voiceDescriptor)
                        .font(AppTypography.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer(minLength: 0)

                if alarm.alarmType == .pro {
                    proBadge
                }
            }

            // Waveform
            AlarmReadyWaveform(bands: bands, isPlaying: isPlaying)
                .frame(height: 36)

            // Play
            playButton
        }
        .padding(.vertical, 16 * deviceInfo.spacingScale)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    private var nameRow: some View {
        NameRowCard(name: alarm.name, style: .clear) {
            HapticManager.shared.softTap()
            onRenameTap()
        }
    }

    private var proBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.system(size: 10))
            Text("Pro")
                .font(AppTypography.labelSmall)
        }
        .foregroundStyle(Color(hex: "E9C46A"))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color(hex: "E9C46A").opacity(0.12))
        )
        .overlay(
            Capsule().strokeBorder(Color(hex: "E9C46A").opacity(0.3), lineWidth: 1)
        )
    }

    private var playButton: some View {
        Button {
            HapticManager.shared.buttonTap()
            onTogglePlay()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 15))
                    .contentTransition(.symbolEffect(.replace))

                Text(isPlaying ? "Stop preview" : "Preview")
                    .font(AppTypography.labelMedium)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(.white)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(isPlaying ? 0.18 : 0.12))
            .clipShape(Capsule())
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPlaying)
    }

    // MARK: - Schedule Button

    private var scheduleButton: some View {
        Button {
            HapticManager.shared.buttonTap()
            onSchedule()
        } label: {
            ZStack {
                if isScheduling {
                    ProgressView().tint(.black).transition(.opacity)
                } else {
                    HStack(spacing: 8) {
                        Text("Schedule Alarm")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isScheduling)
        }
        .primaryButton(isEnabled: !isScheduling)
        .disabled(isScheduling)
    }

    // MARK: - Derived Strings

    private var wakeTimeString: String {
        let date = alarm.wakeTime ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter.string(from: date)
    }

    private var scheduleSummary: String {
        guard let days = alarm.repeatDays, !days.isEmpty else {
            return "One-time"
        }
        let sorted = Set(days)
        if sorted == Set([1, 2, 3, 4, 5]) { return "Weekdays" }
        if sorted == Set([0, 6]) { return "Weekends" }
        if sorted.count == 7 { return "Every day" }
        let labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days.sorted().compactMap { $0 < labels.count ? labels[$0] : nil }
            .joined(separator: " · ")
    }

    private var voiceName: String {
        alarm.voicePersona?.displayName ?? "Default voice"
    }

    private var voiceDescriptor: String {
        alarm.voicePersona?.descriptor ?? ""
    }
}

// MARK: - Waveform

/// A centered symmetric bar visualizer. Resting state draws a gentle
/// sine silhouette; playing state drives from the live `bands` metering.
private struct AlarmReadyWaveform: View {

    // MARK: - Constants

    let bands: [CGFloat]
    let isPlaying: Bool

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 5
    private let minBarHeight: CGFloat = 3
    private let restingHeights: [CGFloat] = (0..<24).map { i in
        let t = CGFloat(i) / 23.0
        let hump = sin(t * .pi)
        return 0.18 + hump * 0.34
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<max(bands.count, restingHeights.count), id: \.self) { i in
                    let amplitude = isPlaying && i < bands.count
                        ? max(bands[i], 0.05)
                        : restingHeights[i % restingHeights.count]
                    let height = max(minBarHeight, amplitude * geo.size.height)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "F5B971").opacity(isPlaying ? 0.95 : 0.5),
                                    Color(hex: "C86B5F").opacity(isPlaying ? 0.9 : 0.3)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: barWidth, height: height)
                        .animation(.easeOut(duration: 0.08), value: amplitude)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .animation(.easeInOut(duration: 0.3), value: isPlaying)
        }
    }
}

// MARK: - Previews

#Preview("Basic alarm") {
    ZStack {
        MorningSky(starOpacity: 0.6, showConstellations: false, sunriseProgress: 1, starSpinProgress: 1)
        AlarmReadyView(
        alarm: AlarmConfiguration(
            isEnabled: true,
            name: "Morning run",
            wakeTime: Calendar.current.date(from: DateComponents(hour: 6, minute: 30)),
            repeatDays: [1, 2, 3, 4, 5],
            tone: .encourage,
            intensity: .balanced,
            voicePersona: .soothingSarah,
            whyContext: .gym
        ),
        isPlaying: false,
        isScheduling: false,
        bands: Array(repeating: 0, count: 24),
        onTogglePlay: {},
        onEdit: {},
        onRenameTap: {},
        onSchedule: {}
    )
    }
}

#Preview("Pro alarm, playing") {
    ZStack {
        MorningSky(starOpacity: 0.6, showConstellations: false, sunriseProgress: 1, starSpinProgress: 1)
        AlarmReadyView(
            alarm: AlarmConfiguration(
                isEnabled: true,
                name: "Early meeting",
                wakeTime: Calendar.current.date(from: DateComponents(hour: 7, minute: 15)),
                repeatDays: nil,
                tone: .fun,
                intensity: .intense,
                voicePersona: .darkSpaceLord,
                whyContext: .work,
                alarmType: .pro
            ),
            isPlaying: true,
            isScheduling: false,
            bands: (0..<24).map { _ in CGFloat.random(in: 0.2...0.95) },
            onTogglePlay: {},
            onEdit: {},
            onRenameTap: {},
            onSchedule: {}
        )
    }
}

#Preview("Scheduling in flight") {
    ZStack {
        MorningSky(starOpacity: 0.6, showConstellations: false, sunriseProgress: 1, starSpinProgress: 1)
        AlarmReadyView(
            alarm: AlarmConfiguration(
                isEnabled: true,
                wakeTime: Calendar.current.date(from: DateComponents(hour: 8, minute: 0)),
                repeatDays: [0, 1, 2, 3, 4, 5, 6],
                tone: .calm,
                intensity: .gentle,
                voicePersona: .soothingSarah,
                whyContext: .personalGoal
            ),
            isPlaying: false,
            isScheduling: true,
            bands: Array(repeating: 0, count: 24),
            onTogglePlay: {},
            onEdit: {},
            onRenameTap: {},
            onSchedule: {}
        )
    }
}
