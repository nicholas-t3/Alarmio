//
//  OnboardingConfirmationView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct OnboardingConfirmationView: View {

    // MARK: - Environment
    @Environment(OnboardingManager.self) private var manager
    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - State
    @State private var heroVisible = false
    @State private var checkVisible = false
    @State private var heroExited = false
    @State private var cardsVisible = false
    @State private var player = VoicePreviewPlayer()
    @State private var isRegenerating = false
    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5]

    // MARK: - Body
    var body: some View {
        ZStack {

            // Phase 1: Hero
            if !heroExited {
                heroView
            }

            // Phase 2: Alarm detail cards
            if heroExited {
                detailView
            }
        }
        .task {
            await runEntrySequence()
        }
        .onDisappear {
            player.stop()
        }
    }

    // MARK: - Hero

    private var heroView: some View {
        VStack(spacing: 20) {

            Spacer()

            // Checkmark + title stacked
            VStack(spacing: 0) {

                // Checkmark
                ZStack {
                    Circle()
                        .fill(Color(hex: "4AFF8E").opacity(0.08))
                        .frame(width: 80, height: 80)
                        .blur(radius: 16)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(hex: "4AFF8E"))
                        .opacity(checkVisible ? 1 : 0)
                        .scaleEffect(checkVisible ? 1 : 0.5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: checkVisible)
                }

                // Title
                Text("Your alarm is ready")
                    .font(AppTypography.headlineLarge)
                    .tracking(AppTypography.headlineLargeTracking)
                    .foregroundStyle(.white)
            }
            .premiumBlur(isVisible: heroVisible, duration: 0.5)

            Spacer()
        }
    }

    // MARK: - Detail Cards

    private var detailView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.itemGap(deviceInfo.spacingScale)) {

                Spacer()
                    .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale))

                // Wake time
                timeCard
                    .premiumBlur(isVisible: cardsVisible, delay: 0, duration: 0.4)

                // Audio preview
                audioCard
                    .premiumBlur(isVisible: cardsVisible, delay: 0.1, duration: 0.4)

                // Repeat schedule
                scheduleCard
                    .premiumBlur(isVisible: cardsVisible, delay: 0.2, duration: 0.4)

                // Snooze info
                snoozeCard
                    .premiumBlur(isVisible: cardsVisible, delay: 0.3, duration: 0.4)

                Spacer()
                    .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale))
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Cards

    private var timeCard: some View {
        VStack(spacing: 12) {

            // Label
            Text("WAKE TIME")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Time
            if let time = manager.configuration.wakeTime {
                Text(time, style: .time)
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Text("7:00 AM")
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    private var audioCard: some View {
        VStack(spacing: 16) {

            // Label
            Text("VOICE PREVIEW")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Waveform visual
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { i in
                    let height = waveformBarHeight(index: i)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.white.opacity(player.isPlaying ? 0.6 : 0.2))
                        .frame(width: 3, height: height)
                }
            }
            .frame(height: 32)

            // Play + Regenerate buttons inline
            HStack(spacing: 12) {

                // Play / Stop
                Button {
                    HapticManager.shared.buttonTap()
                    togglePreview()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 14))
                            .contentTransition(.symbolEffect(.replace))

                        Text(player.isPlaying ? "Stop" : "Play")
                            .font(AppTypography.labelMedium)
                    }
                    .foregroundStyle(.white)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
                }

                // Regenerate
                Button {
                    HapticManager.shared.buttonTap()
                    regenerate()
                } label: {
                    HStack(spacing: 8) {
                        if isRegenerating {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                        }

                        Text(isRegenerating ? "Generating" : "Regenerate")
                            .font(AppTypography.labelMedium)
                    }
                    .foregroundStyle(.white.opacity(isRegenerating ? 0.5 : 1))
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .disabled(isRegenerating)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    private var scheduleCard: some View {
        VStack(spacing: 14) {

            // Label
            Text("REPEAT")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Day buttons
            HStack(spacing: 8) {
                ForEach(dayLabels, id: \.self) { day in
                    let isSelected = selectedDays.contains(day.index)

                    Button {
                        HapticManager.shared.selection()
                        toggleDay(day.index)
                    } label: {
                        Text(day.letter)
                            .font(AppTypography.labelSmall)
                            .foregroundStyle(isSelected ? .black : .white.opacity(0.5))
                            .frame(width: 36, height: 36)
                            .background(isSelected ? .white : .white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .animation(.easeOut(duration: 0.2), value: isSelected)
                }
            }

            // Summary
            Text(scheduleSummary)
                .font(AppTypography.bodySmall)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    private var snoozeCard: some View {
        HStack {

            VStack(alignment: .leading, spacing: 4) {
                Text("SNOOZE")
                    .font(AppTypography.caption)
                    .tracking(AppTypography.captionTracking)
                    .foregroundStyle(.white.opacity(0.4))

                let count = manager.configuration.snoozeCount
                let interval = manager.configuration.snoozeInterval

                if count == 0 {
                    Text("Disabled")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    Text("\(count) \(count == 1 ? "snooze" : "snoozes"), \(interval) min each")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            Image(systemName: "zzz")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Private Methods

    private func runEntrySequence() async {
        try? await Task.sleep(for: .milliseconds(200))
        heroVisible = true

        try? await Task.sleep(for: .milliseconds(400))
        checkVisible = true
        HapticManager.shared.success()

        try? await Task.sleep(for: .seconds(1.5))

        // Premium blur out hero, then show cards
        heroVisible = false

        try? await Task.sleep(for: .milliseconds(500))
        heroExited = true

        try? await Task.sleep(for: .milliseconds(100))
        cardsVisible = true
    }

    private func togglePreview() {
        if player.isPlaying {
            player.stop()
        } else if let persona = manager.configuration.voicePersona {
            player.play(persona: persona)
        }
    }

    private func regenerate() {
        player.stop()
        isRegenerating = true

        // TODO: Replace with real Composer API call
        Task {
            try? await Task.sleep(for: .seconds(3))
            isRegenerating = false
            HapticManager.shared.success()
        }
    }

    private func waveformBarHeight(index: Int) -> CGFloat {
        // Static waveform shape — taller in the middle, shorter at edges
        let center = 10.0
        let dist = abs(Double(index) - center) / center
        let base: CGFloat = 6
        let peak: CGFloat = 28
        return base + (peak - base) * (1.0 - dist * dist)
    }

    // MARK: - Schedule Helpers

    private struct DayLabel: Hashable {
        let index: Int
        let letter: String
    }

    private var dayLabels: [DayLabel] {
        [
            DayLabel(index: 0, letter: "S"),
            DayLabel(index: 1, letter: "M"),
            DayLabel(index: 2, letter: "T"),
            DayLabel(index: 3, letter: "W"),
            DayLabel(index: 4, letter: "T"),
            DayLabel(index: 5, letter: "F"),
            DayLabel(index: 6, letter: "S"),
        ]
    }

    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
        manager.configuration.repeatDays = Array(selectedDays).sorted()
    }

    private var scheduleSummary: String {
        if selectedDays.isEmpty {
            return "One-time alarm"
        } else if selectedDays == Set([1, 2, 3, 4, 5]) {
            return "Weekdays"
        } else if selectedDays == Set([0, 6]) {
            return "Weekends"
        } else if selectedDays.count == 7 {
            return "Every day"
        } else {
            return "\(selectedDays.count) days per week"
        }
    }
}

// MARK: - Previews

#Preview {
    OnboardingContainerView.preview(step: .confirmation)
}
