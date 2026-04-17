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
        persona: .darkSpaceLord,
        name: "Dark Space Lord",
        description: "A dark, commanding voice from across the galaxy",
        palette: .purple
    ),
    VoiceEntry(
        persona: .drillSergeant,
        name: "Drill Sergeant",
        description: "A firm, no-nonsense voice that demands action",
        palette: .red
    ),
    VoiceEntry(
        persona: .asmrWhisper,
        name: "ASMR Whisper",
        description: "A soft, tingly whisper that coaxes you awake",
        palette: .blue
    ),
    VoiceEntry(
        persona: .strongAussie,
        name: "Strong Aussie",
        description: "A warm, laid-back Aussie drawl to start the day",
        palette: .gold
    ),
    VoiceEntry(
        persona: .playfulFemmeFatale,
        name: "Playful Femme Fatale",
        description: "A flirty, mischievous voice with a wink",
        palette: .red
    ),
    VoiceEntry(
        persona: .princeOfTheNorth,
        name: "Prince of the North",
        description: "A noble, regal voice that rouses the realm",
        palette: .purple
    ),
    VoiceEntry(
        persona: .movieTrailer,
        name: "Movie Trailer",
        description: "An epic, cinematic voice that makes every morning a premiere",
        palette: .gold
    ),
    VoiceEntry(
        persona: .theBro,
        name: "The Bro",
        description: "A casual, easygoing voice that keeps it chill",
        palette: .gold
    ),
    VoiceEntry(
        persona: .rythmicSinger,
        name: "Rythmic Singer",
        description: "A melodic voice that sings you out of bed",
        palette: .green
    ),
    VoiceEntry(
        persona: .theDad,
        name: "The Dad",
        description: "A caring, grounded voice that's already made coffee",
        palette: .gold
    ),
    VoiceEntry(
        persona: .meditationGuru,
        name: "Meditation Guru",
        description: "A calm, grounded voice that eases you into the day",
        palette: .green
    ),
    VoiceEntry(
        persona: .smoothBoyfriend,
        name: "Smooth Boyfriend",
        description: "A tender, confident voice that makes mornings ours",
        palette: .red
    ),
    VoiceEntry(
        persona: .soothingSarah,
        name: "Soothing Sarah",
        description: "A gentle, reassuring voice that lets the day wait for you",
        palette: .blue
    ),
    VoiceEntry(
        persona: .reptilianMonster,
        name: "Reptilian Monster",
        description: "An unsettling, hissing voice — if you can handle it",
        palette: .green
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
