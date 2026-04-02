//
//  OnboardingVoiceView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct VoiceOption {
    let persona: VoicePersona
    let name: String
    let description: String
    let colors: [Color]
}

private let voiceOptions: [VoiceOption] = [
    VoiceOption(persona: .calmGuide, name: "Calm Guide", description: "A soothing, gentle voice that eases you awake", colors: [
        Color(hex: "1a3a5c"), Color(hex: "2d5a8e"), Color(hex: "1a4a6e")
    ]),
    VoiceOption(persona: .energeticCoach, name: "Energetic Coach", description: "An upbeat, motivating voice to get you moving", colors: [
        Color(hex: "2d6a1e"), Color(hex: "4a8e2d"), Color(hex: "3a7a28")
    ]),
    VoiceOption(persona: .hardSergeant, name: "Hard Sergeant", description: "A firm, no-nonsense voice that demands action", colors: [
        Color(hex: "6e1a1a"), Color(hex: "8e2d2d"), Color(hex: "7a2828")
    ]),
    VoiceOption(persona: .evilSpaceLord, name: "Evil Space Lord", description: "A dramatic, commanding voice from beyond", colors: [
        Color(hex: "3a1a5c"), Color(hex: "5a2d8e"), Color(hex: "4a1a7a")
    ]),
    VoiceOption(persona: .playful, name: "Playful", description: "A fun, lighthearted voice that makes mornings bright", colors: [
        Color(hex: "5c4a1a"), Color(hex: "8e7a2d"), Color(hex: "7a6a28")
    ])
]

struct OnboardingVoiceView: View {

    // MARK: - Environment

    @Environment(OnboardingManager.self) private var manager
    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - State

    @State private var contentVisible = false
    @State private var selectedIndex = 0
    @State private var previewActive = false
    @State private var player = VoicePreviewPlayer()

    // MARK: - Constants

    let onReadyForButton: () -> Void
    let onColorChange: ([Color]) -> Void

    // MARK: - Body

    var body: some View {
        ZStack {

            // Full-screen frequency visualizer background
            FrequencyVisualizer(
                bands: player.bands,
                colors: voiceOptions[selectedIndex].colors,
                isPlaying: player.isPlaying
            )
            .ignoresSafeArea()
            .opacity(contentVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.6), value: contentVisible)

            // Foreground content
            VStack(spacing: 0) {

                Spacer()
                    .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale))

                // Title
                Text("Choose\nyour voice")
                    .font(AppTypography.headlineLarge)
                    .tracking(AppTypography.headlineLargeTracking)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .premiumBlur(isVisible: contentVisible, duration: 0.4)

                // Swipeable voice pager
                TabView(selection: $selectedIndex) {
                    ForEach(0..<voiceOptions.count, id: \.self) { index in
                        VStack(spacing: 32) {

                            Spacer()

                            // Voice card
                            VoiceCard(
                                option: voiceOptions[index],
                                isPlaying: player.isPlaying && selectedIndex == index,
                                onPreviewTap: {
                                    HapticManager.shared.buttonTap()
                                    togglePreview(for: index)
                                }
                            )

                            Spacer()
                                .frame(height: 40)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .blur(radius: contentVisible ? 0 : 8)
                .opacity(contentVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: contentVisible)
                .onChange(of: selectedIndex) {
                    HapticManager.shared.selection()
                    manager.selectVoice(voiceOptions[selectedIndex].persona)
                    onColorChange(voiceOptions[selectedIndex].colors)

                    // Auto-play on swipe only if preview is active
                    if previewActive {
                        player.play(persona: voiceOptions[selectedIndex].persona)
                    }
                }
            }
        }
        .onDisappear {
            player.stop()
            previewActive = false
        }
        .task {
            onColorChange(voiceOptions[selectedIndex].colors)
            manager.selectVoice(voiceOptions[selectedIndex].persona)

            try? await Task.sleep(for: .milliseconds(100))
            contentVisible = true

            try? await Task.sleep(for: .milliseconds(500))
            onReadyForButton()
        }
    }

    // MARK: - Private Methods

    private func togglePreview(for index: Int) {
        if previewActive {
            previewActive = false
            player.stop()
        } else {
            previewActive = true
            player.play(persona: voiceOptions[index].persona)
        }
    }
}

// MARK: - Voice Card

private struct VoiceCard: View {

    let option: VoiceOption
    let isPlaying: Bool
    let onPreviewTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {

            // Voice name
            Text(option.name)
                .font(AppTypography.headlineMedium)
                .tracking(AppTypography.headlineMediumTracking)
                .foregroundStyle(.white)

            // Description
            Text(option.description)
                .font(AppTypography.bodySmall)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            // Preview / Stop button
            Button(action: onPreviewTap) {
                HStack(spacing: 8) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 14))
                        .contentTransition(.symbolEffect(.replace))

                    Text(isPlaying ? "Stop" : "Preview")
                        .font(AppTypography.labelMedium)
                }
                .foregroundStyle(.white)
                .frame(height: 40)
                .frame(width: 130)
                .background(.white.opacity(0.15))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                )
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

// MARK: - Frequency Visualizer

private struct FrequencyVisualizer: View {

    let bands: [CGFloat]
    let colors: [Color]
    let isPlaying: Bool

    @State private var displayBands: [CGFloat] = Array(repeating: 0, count: 24)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let barCount = bands.count
                guard barCount > 0 else { return }

                let barSpacing = size.width / CGFloat(barCount)
                let barWidth = barSpacing * 0.55
                let maxBarHeight = size.height * 0.75

                for i in 0..<barCount {
                    let centerX = barSpacing * CGFloat(i) + barSpacing / 2

                    // Smooth toward target
                    let target: CGFloat
                    if isPlaying {
                        target = bands[i]
                    } else {
                        // Gentle idle breathing
                        let phase = Double(i) * 0.35 + now * 0.5
                        let wave = sin(phase) * 0.5 + sin(phase * 1.6 + 1.2) * 0.3
                        target = CGFloat(wave * 0.03 + 0.05)
                    }

                    let current = displayBands[i]
                    let smoothed = current + (target - current) * 0.14
                    displayBands[i] = smoothed

                    let barHeight = max(3, maxBarHeight * smoothed)

                    // Bar grows from bottom of screen
                    let barRect = CGRect(
                        x: centerX - barWidth / 2,
                        y: size.height - barHeight,
                        width: barWidth,
                        height: barHeight
                    )

                    // Color — interpolate across the bar array
                    let progress = CGFloat(i) / CGFloat(barCount - 1)
                    let barColor = interpolateColor(colors: colors, at: progress)

                    let baseOpacity: Double = isPlaying
                        ? 0.35 + Double(smoothed) * 0.45
                        : 0.08 + Double(smoothed) * 0.15

                    // Glow pass — soft bloom behind each strip
                    context.drawLayer { glowCtx in
                        glowCtx.opacity = baseOpacity * 0.4
                        glowCtx.addFilter(.blur(radius: 16))
                        glowCtx.fill(
                            RoundedRectangle(cornerRadius: barWidth / 2).path(in: barRect.insetBy(dx: -4, dy: 0)),
                            with: .color(barColor)
                        )
                    }

                    // Sharp pass — the visible strip
                    context.opacity = baseOpacity
                    context.fill(
                        RoundedRectangle(cornerRadius: barWidth / 2).path(in: barRect),
                        with: .color(barColor)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func interpolateColor(colors: [Color], at progress: CGFloat) -> Color {
        guard colors.count >= 2 else { return colors.first ?? .white }

        let segment = progress * CGFloat(colors.count - 1)
        let index = min(Int(segment), colors.count - 2)
        let localProgress = segment - CGFloat(index)

        let c0 = UIColor(colors[index])
        let c1 = UIColor(colors[index + 1])
        var r0: CGFloat = 0, g0: CGFloat = 0, b0: CGFloat = 0, a0: CGFloat = 0
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        c0.getRed(&r0, green: &g0, blue: &b0, alpha: &a0)
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)

        return Color(
            red: Double(r0 * (1 - localProgress) + r1 * localProgress),
            green: Double(g0 * (1 - localProgress) + g1 * localProgress),
            blue: Double(b0 * (1 - localProgress) + b1 * localProgress)
        )
    }
}

/* ============================================================
   MARK: - Old Waveform Visualizer (kept for reference)
   ============================================================

struct WaveformVisualizer: View {

    let colors: [Color]
    let isPlaying: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let barCount = 40
                let barWidth: CGFloat = size.width / CGFloat(barCount) * 0.6
                let gap = size.width / CGFloat(barCount) * 0.4
                let centerY = size.height / 2

                for i in 0..<barCount {
                    let x = CGFloat(i) * (barWidth + gap) + gap / 2
                    let phase = Double(i) * 0.3 + now * (isPlaying ? 3.0 : 0.5)

                    let wave1 = sin(phase) * (isPlaying ? 0.8 : 0.15)
                    let wave2 = sin(phase * 1.7 + 1.3) * (isPlaying ? 0.5 : 0.1)
                    let amplitude = abs(wave1 + wave2)

                    let maxHeight = size.height * 0.8
                    let barHeight = max(2, maxHeight * CGFloat(amplitude))

                    let rect = CGRect(
                        x: x,
                        y: centerY - barHeight / 2,
                        width: barWidth,
                        height: barHeight
                    )

                    let progress = CGFloat(i) / CGFloat(barCount)
                    let c0 = UIColor(colors[0])
                    let c1 = UIColor(colors[1])
                    var r0: CGFloat = 0, g0: CGFloat = 0, b0: CGFloat = 0, a0: CGFloat = 0
                    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
                    c0.getRed(&r0, green: &g0, blue: &b0, alpha: &a0)
                    c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)

                    let blended = Color(
                        red: Double(r0 * (1 - progress) + r1 * progress),
                        green: Double(g0 * (1 - progress) + g1 * progress),
                        blue: Double(b0 * (1 - progress) + b1 * progress)
                    )

                    context.opacity = isPlaying ? 0.8 : 0.3
                    context.fill(
                        RoundedRectangle(cornerRadius: barWidth / 2).path(in: rect),
                        with: .color(blended.opacity(0.6 + amplitude * 0.4))
                    )
                }
            }
        }
    }
}

============================================================ */

#Preview {
    OnboardingContainerView.preview(step: .voice)
}
