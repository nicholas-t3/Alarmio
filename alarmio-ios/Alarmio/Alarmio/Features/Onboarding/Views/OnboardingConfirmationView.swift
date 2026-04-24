//
//  OnboardingConfirmationView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

/// Final step of onboarding. Identical shape to CreateAlarmView's
/// confirming phase — hero, then the same stack of alarm-preview / compact
/// voice / name / customize cards plus a regenerate button. The container
/// owns persistence; tapping Schedule flows back through the container's
/// scheduleAlarm().
struct OnboardingConfirmationView: View {

    // MARK: - Environment

    @Environment(OnboardingManager.self) private var manager
    @Environment(\.deviceInfo) private var deviceInfo
    @Environment(\.composerService) private var composerService
    @Environment(\.alarmStore) private var alarmStore
    @Environment(\.alertManager) private var alertManager

    // MARK: - State

    @State private var heroVisible = false
    @State private var checkVisible = false
    @State private var heroExited = false
    @State private var cardsVisible = false
    @State private var voicePlayer = VoicePreviewPlayer()
    @State private var voiceIndex: Int = 0
    @State private var proToggle: Bool = false
    /// Flips true after a regeneration completes; drives a pulsing opacity
    /// on the alarm-preview Play button to nudge the user to preview the
    /// new audio. Cleared when Play is tapped or when the bottom Schedule
    /// button is tapped.
    @State private var playPulseActive: Bool = false

    // MARK: - Constants

    /// Container-owned state surfaced so the confirmation view can react
    /// without owning the regeneration logic itself. The bottom primary
    /// button is also owned by the container — this view just renders the
    /// preview, voice, name, and customize cards.
    let onSchedule: () -> Void
    let isScheduling: Bool
    let isRegenerating: Bool
    /// Incremented by the container after each successful regenerate. Our
    /// `onChange` pulses the Play button when it changes.
    let regenerationNonce: Int

    // MARK: - Body

    var body: some View {
        ZStack {

            // Phase 1: Hero
            if !heroExited {
                heroView
            }

            // Phase 2: Same card stack as CreateAlarmView.confirmationCard
            if heroExited {
                detailView
                    .transition(.opacity)
            }
        }
        .task {
            voiceIndex = heroVoices.firstIndex { $0.persona == manager.configuration.voicePersona } ?? 0
            await runEntrySequence()
        }
        .onDisappear {
            voicePlayer.stop()
        }
        .onChange(of: regenerationNonce) { _, _ in
            // Container just finished a regen — nudge the user toward
            // previewing the new audio.
            withAnimation(.easeInOut(duration: 0.3)) {
                playPulseActive = true
            }
        }
        .onChange(of: isScheduling) { _, newValue in
            // Container started scheduling — clear the pulse so the Play
            // button isn't still glowing as we transition out.
            if newValue, playPulseActive {
                withAnimation(.easeOut(duration: 0.25)) {
                    playPulseActive = false
                }
            }
        }
        .onChange(of: manager.configuration.voicePersona) { _, _ in
            // User cycled voice → configuration drifts from committed →
            // the button flips to Regenerate. Clear the lingering pulse
            // so we don't advertise stale audio.
            if playPulseActive {
                withAnimation(.easeOut(duration: 0.25)) {
                    playPulseActive = false
                }
            }
        }
    }

    /// The snapshot of the most recently-generated audio. Used for the
    /// Play button's sound file lookup. Falls back to `manager.configuration`
    /// for the window between step entry and first generation.
    private var committedConfig: AlarmConfiguration {
        manager.committedConfiguration ?? manager.configuration
    }

    // MARK: - Hero

    private var heroView: some View {
        VStack(spacing: 20) {

            Spacer()

            // Checkmark + title
            VStack(spacing: 0) {

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

                Text("Your alarm is ready")
                    .font(AppTypography.headlineLarge)
                    .tracking(AppTypography.headlineLargeTracking)
                    .foregroundStyle(.white)
            }
            .premiumBlur(isVisible: heroVisible, duration: 0.5)

            Spacer()
        }
    }

    // MARK: - Detail View (mirrors CreateAlarmView.confirmationCard)

    private var detailView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.itemGap(deviceInfo.spacingScale)) {

                // Alarm audio preview
                alarmPreviewCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0, duration: 0.5)

                // Compact voice selector — consolidated card with its own
                // Play affordance (previews the voice persona, not the
                // generated alarm audio).
                compactPlayableVoiceSection
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0.1, duration: 0.5)

                // Customize (no Pro row in onboarding)
                CustomizeCard(
                    tone: Bindable(manager).configuration.tone,
                    whyContext: Bindable(manager).configuration.whyContext,
                    intensity: Bindable(manager).configuration.intensity,
                    leaveTime: Bindable(manager).configuration.leaveTime,
                    customPromptIncludes: Bindable(manager).configuration.customPromptIncludes,
                    wakeTime: manager.configuration.wakeTime,
                    isProOn: $proToggle,
                    showProRow: false
                )
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .premiumBlur(isVisible: cardsVisible, delay: 0.2, duration: 0.5)

                Spacer(minLength: 0)
                    .frame(height: 20)
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .mask(scrollFadeMask)
    }

    // MARK: - Alarm Preview Card

    private var alarmPreviewCard: some View {
        let isPlaying = voicePlayer.isPlaying

        return VStack(spacing: 14) {

            Text("ALARM PREVIEW")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            VoiceWaveform(bands: voicePlayer.bands, isPlaying: isPlaying)
                .frame(height: 40)
                .padding(.horizontal, 8)

            Button {
                HapticManager.shared.buttonTap()
                toggleAlarmPreview()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 14))
                        .contentTransition(.symbolEffect(.replace))

                    Text(isPlaying ? "Stop" : "Play")
                        .font(AppTypography.labelMedium)
                        .contentTransition(.numericText())
                }
                .foregroundStyle(.white)
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(playPulseActive ? 0.28 : 0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color(hex: "4AFF8E").opacity(playPulseActive ? 0.55 : 0), lineWidth: 1.2)
                )
                .shadow(color: Color(hex: "4AFF8E").opacity(playPulseActive ? 0.28 : 0), radius: 14, y: 0)
            }
            .disabled(committedConfig.soundFileName == nil || isRegenerating)
            .opacity(committedConfig.soundFileName == nil ? 0.4 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPlaying)
            .animation(
                playPulseActive
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                    : .easeInOut(duration: 0.35),
                value: playPulseActive
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Compact Playable Voice Section

    /// Consolidated voice card with its own Play button that previews the
    /// voice persona (bundled clip), separate from the alarm-audio Play
    /// button in `alarmPreviewCard`. Having both here is intentional — one
    /// previews the voice, the other previews the full generated alarm.
    private var compactPlayableVoiceSection: some View {
        let voice = heroVoices[voiceIndex]
        let isPlayingThis = voicePlayer.isPlaying && voicePlayer.currentPersona == voice.persona
        return CompactPlayableVoiceCard(
            voice: voice,
            isPlayingThis: isPlayingThis,
            onPrev: { cycleVoice(by: -1) },
            onNext: { cycleVoice(by: 1) },
            onTogglePlay: { toggleVoicePreview() }
        )
    }

    private func toggleVoicePreview() {
        let voice = heroVoices[voiceIndex]
        if voicePlayer.isPlaying && voicePlayer.currentPersona == voice.persona {
            voicePlayer.stop()
        } else {
            voicePlayer.play(persona: voice.persona)
        }
    }

    // MARK: - Private Methods

    private func runEntrySequence() async {
        // 1. Hero blurs in
        try? await Task.sleep(for: .milliseconds(100))
        heroVisible = true

        // 2. Checkmark pops
        try? await Task.sleep(for: .milliseconds(250))
        checkVisible = true
        HapticManager.shared.success()

        // 3. Hold the hero
        try? await Task.sleep(for: .seconds(1.5))

        // 4. Blur hero out
        heroVisible = false

        // 5. Swap to cards
        try? await Task.sleep(for: .milliseconds(500))
        heroExited = true

        try? await Task.sleep(for: .milliseconds(100))
        cardsVisible = true
    }

    private func toggleAlarmPreview() {
        // Any interaction clears the post-regen pulse.
        if playPulseActive {
            withAnimation(.easeOut(duration: 0.25)) {
                playPulseActive = false
            }
        }
        if voicePlayer.isPlaying {
            voicePlayer.stop()
        } else {
            guard let fileName = committedConfig.soundFileName else { return }
            let url = alarmStore.audioFileManager.soundFileURL(named: fileName)
            voicePlayer.playFromFile(url: url, persona: committedConfig.voicePersona)
        }
    }

    private func cycleVoice(by delta: Int) {
        let newIndex = (voiceIndex + delta + heroVoices.count) % heroVoices.count
        voiceIndex = newIndex
        manager.configuration.voicePersona = heroVoices[newIndex].persona

        // Preview playback is tied to the previously-generated file; stop
        // it so the user can hear the new voice after regenerating.
        voicePlayer.stop()
    }

    // MARK: - Scroll Fade Mask

    private var scrollFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 16)

            Color.white

            LinearGradient(
                stops: [
                    .init(color: .white, location: 0),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 16)
        }
    }

    // MARK: - Hero Voice Data

    private var heroVoices: [HeroVoice] { VoiceCatalog.all }
}

// MARK: - Voice Waveform (shared shape used by CreateAlarmView)

private struct VoiceWaveform: View {

    // MARK: - Constants

    let bands: [CGFloat]
    let isPlaying: Bool

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 4
    private let minBarHeight: CGFloat = 3
    private let restingHeights: [CGFloat] = (0..<24).map { i in
        let t = CGFloat(i) / 23.0
        let hump = sin(t * .pi)
        return 0.2 + hump * 0.3
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<bands.count, id: \.self) { i in
                    let amplitude = isPlaying ? max(bands[i], 0.05) : restingHeights[i]
                    let height = max(minBarHeight, amplitude * geo.size.height)

                    Capsule()
                        .fill(.white.opacity(isPlaying ? 0.9 : 0.35))
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

#Preview {
    OnboardingContainerView.preview(step: .confirmation)
}
