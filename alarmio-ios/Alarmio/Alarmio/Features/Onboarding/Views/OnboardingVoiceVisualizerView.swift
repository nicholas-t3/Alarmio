//
//  VoiceVisualizerView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

private let voiceEntries: [VoiceEntry] = [
    VoiceEntry(
        persona: .calmGuide,
        name: "Calm Guide",
        description: "A soothing, gentle voice that eases you awake",
        palette: .blue
    ),
    VoiceEntry(
        persona: .energeticCoach,
        name: "Energetic Coach",
        description: "An upbeat, motivating voice to get you moving",
        palette: .green
    ),
    VoiceEntry(
        persona: .hardSergeant,
        name: "Hard Sergeant",
        description: "A firm, no-nonsense voice that demands action",
        palette: .red
    ),
    VoiceEntry(
        persona: .evilSpaceLord,
        name: "Evil Space Lord",
        description: "A dramatic, commanding voice from beyond",
        palette: .purple
    ),
    VoiceEntry(
        persona: .playful,
        name: "Playful",
        description: "A fun, lighthearted voice that makes mornings bright",
        palette: .gold
    ),
    VoiceEntry(
        persona: .bro,
        name: "The Bro",
        description: "A casual, easygoing voice that keeps it chill",
        palette: .gold
    ),
    VoiceEntry(
        persona: .digitalAssistant,
        name: "Digital",
        description: "A robotic, helpful voice for the pragmatic wake-up",
        palette: .blue
    ),
]

// MARK: - Onboarding Voice View

struct OnboardingVoiceView: View {

    // MARK: - Environment
    @Environment(OnboardingManager.self) private var manager
    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - State
    @State private var selectedIndex = 0
    @State private var player = VoicePreviewPlayer()
    @State private var contentVisible = false

    // MARK: - Constants
    let onReadyForButton: () -> Void
    let onPaletteChange: (VisualizerPalette) -> Void
    let onPlayingChange: (Bool) -> Void

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {

            // Title — fixed, doesn't swipe
            Text("Choose\nyour voice")
                .font(AppTypography.headlineLarge)
                .tracking(AppTypography.headlineLargeTracking)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .premiumBlur(isVisible: contentVisible, duration: 0.4)

            // Swipeable voice cards
            TabView(selection: $selectedIndex) {
                ForEach(0..<voiceEntries.count, id: \.self) { index in

                    VStack {

                        Spacer()

                        // Voice card
                        VStack(spacing: 16) {

                            // Voice name
                            Text(voiceEntries[index].name)
                                .font(AppTypography.headlineMedium)
                                .tracking(AppTypography.headlineMediumTracking)
                                .foregroundStyle(.white)

                            // Description
                            Text(voiceEntries[index].description)
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)

                            // Preview / Stop button
                            Button {
                                HapticManager.shared.buttonTap()
                                togglePreview(for: index)
                            } label: {
                                Text(player.isPlaying && selectedIndex == index ? "Stop" : "Preview")
                                    .font(AppTypography.labelMedium)
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: player.isPlaying)
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

                        // Space for page dots + container bottom bar
                        Spacer()
                            .frame(height: 56)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
        .blur(radius: contentVisible ? 0 : 8)
        .opacity(contentVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.1), value: contentVisible)
        .onChange(of: selectedIndex) {
            HapticManager.shared.selection()
            manager.configuration.voicePersona = voiceEntries[selectedIndex].persona
            onPaletteChange(voiceEntries[selectedIndex].palette)

            if player.isPlaying {
                player.play(persona: voiceEntries[selectedIndex].persona)
            }
        }
        .onChange(of: player.isPlaying) {
            onPlayingChange(player.isPlaying)
        }
        .onDisappear {
            player.stop()
        }
        .task {
            manager.configuration.voicePersona = voiceEntries[selectedIndex].persona
            onPaletteChange(voiceEntries[selectedIndex].palette)

            try? await Task.sleep(for: .milliseconds(100))
            contentVisible = true

            try? await Task.sleep(for: .milliseconds(500))
            onReadyForButton()
        }
    }

    // MARK: - Private Methods

    private func togglePreview(for index: Int) {
        if player.isPlaying {
            player.stop()
        } else {
            player.play(persona: voiceEntries[index].persona)
        }
    }
}

// MARK: - Model

private struct VoiceEntry {
    let persona: VoicePersona
    let name: String
    let description: String
    let palette: VisualizerPalette
}

// MARK: - Previews

#Preview {
    OnboardingContainerView.preview(step: .voice)
}
