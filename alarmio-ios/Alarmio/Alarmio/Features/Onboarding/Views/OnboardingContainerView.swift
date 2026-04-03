//
//  OnboardingContainerView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

enum OnboardingPhase {
    case splash
    case steps
}

enum OnboardingStep: Int, CaseIterable {
    case intro = 0
    case tone
    case why
    case intensity
    case difficulty
    case voice
    case time
    case snooze
    // case permission
    case generating
    case confirmation
}

struct OnboardingContainerView: View {

    // MARK: - State

    @Environment(\.previewStep) private var previewStep
    @State private var showHome = false
    @State private var manager = OnboardingManager()
    @State private var deviceInfo = DeviceInfo()
    @State private var splashVisible = true
    @State private var contentVisible = true
    @State private var buttonVisible = false
    @State private var backVisible = false
    @State private var buttonLabel = "Get Started"
    @State private var isTransitioning = false
    @State private var customBackground: [Color]? = nil
    @State private var starOpacity: Double = 1.0
    @State private var voiceVisualizerPalette: VisualizerPalette = .blue
    @State private var voiceVisualizerPlaying = false
    @State private var voiceVisualizerVisible = false
    @State private var sunriseProgress: Double = 0

    // MARK: - Body

    var body: some View {
        ZStack {

            // Shared night sky background — gradient is unaffected, only stars dim
            // Sunrise intensifies during generating step
            MorningSky(starOpacity: starOpacity, sunriseProgress: sunriseProgress)

            // Dynamic voice background (covers starfield when active)
            if let colors = customBackground {
                ZStack {
                    Color(hex: "020810")

                    LinearGradient(
                        stops: [
                            .init(color: colors[0].opacity(0.5), location: 0.2),
                            .init(color: colors[1].opacity(0.4), location: 0.5),
                            .init(color: colors[2].opacity(0.3), location: 0.8),
                            .init(color: Color(hex: "020810"), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.6), value: colors.map { $0.description })
            }

            // Voice visualizer background — always in hierarchy, faded via opacity
            VoiceVisualizer(palette: voiceVisualizerPalette, isPlaying: voiceVisualizerPlaying)
                .opacity(voiceVisualizerVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.5), value: voiceVisualizerVisible)
                .allowsHitTesting(false)
                .overlay(alignment: .top) {
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "020810"), location: 0),
                            .init(color: Color(hex: "020810").opacity(0.8), location: 0.4),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 180)
                    .allowsHitTesting(false)
                }

            // Current phase
            switch manager.phase {
            case .splash:
                SplashContentView(onFinished: {
                    transitionToSteps()
                })
                .premiumBlur(isVisible: splashVisible, duration: 0.5)

            case .steps:
                VStack(spacing: 0) {

                    // Nav bar
                    HStack {
                        Button {
                            goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .opacity(backVisible ? 1 : 0)
                        .blur(radius: backVisible ? 0 : 8)
                        .animation(.easeOut(duration: 0.3), value: backVisible)
                        .disabled(!backVisible)

                        Spacer()

                        // Dev: skip to home (intro only)
                        if manager.currentStep == .intro {
                            Button {
                                HapticManager.shared.buttonTap()
                                showHome = true
                            } label: {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal - 8)
                    .frame(height: 44)

                    // Step content — blur controlled for exit, each step handles entry
                    stepContent
                        .frame(maxHeight: .infinity)
                        .opacity(contentVisible ? 1 : 0)
                        .blur(radius: contentVisible ? 0 : 10)
                        .animation(.easeOut(duration: 0.3), value: contentVisible)

                    // Bottom bar
                    bottomBar
                }
            }
        }
        .environment(manager)
        .environment(\.deviceInfo, deviceInfo)
        .fullScreenCover(isPresented: $showHome) {
            HomeView()
                .environment(AppState())
                .environment(\.deviceInfo, deviceInfo)
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            deviceInfo.updateScreenSize(width: size.width, height: size.height)
        }
        .task {
            await manager.startOnboarding()

            // DEV: Skip to a specific step on launch. Comment out for production.
            // let devStartStep: OnboardingStep? = .snooze
            let devStartStep: OnboardingStep? = nil

            if let step = devStartStep ?? previewStep {
                manager.phase = .steps
                manager.currentStep = step
                contentVisible = true
                backVisible = manager.canGoBack

                // Set up backgrounds/opacity for specific steps in preview
                starOpacity = starOpacityForStep(step)
                if step == .generating {
                    sunriseProgress = 0
                    // Seed example selections so personalized messages appear
                    manager.configuration.tone = .fun
                    manager.configuration.whyContext = .gym
                    manager.configuration.intensity = .intense
                    manager.configuration.voicePersona = .hardSergeant
                }
                if step == .voice {
                    voiceVisualizerPalette = .blue
                    voiceVisualizerVisible = true
                }
                if step == .confirmation {
                    buttonLabel = "Schedule Alarm"
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        buttonVisible = true
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var stepContent: some View {
        switch manager.currentStep {
        case .intro:
            OnboardingIntroView(onTitleComplete: {
                showButton()
            })

        case .tone:
            OnboardingToneView(onReadyForButton: { showButton() })

        case .why:
            OnboardingWhyView(onReadyForButton: { showButton() })

        case .intensity:
            OnboardingIntensityView(onReadyForButton: { showButton() })

        case .difficulty:
            OnboardingDifficultyView(onReadyForButton: { showButton() })

        case .voice:
            OnboardingVoiceView(
                onReadyForButton: { showButton() },
                onPaletteChange: { palette in
                    voiceVisualizerPalette = palette
                },
                onPlayingChange: { playing in
                    voiceVisualizerPlaying = playing
                }
            )

        case .time:
            OnboardingTimeView(onReadyForButton: { showButton() })

        case .snooze:
            OnboardingSnoozeView(onReadyForButton: { showButton() })

//        case .permission:
//            OnboardingPermissionView(onReadyForButton: { showButton() })

        case .generating:
            OnboardingGeneratingView(
                onComplete: { autoAdvanceFromGenerating() },
                onSunriseProgress: { progress in sunriseProgress = progress }
            )

        case .confirmation:
            OnboardingConfirmationView()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {

            // Continue / Get Started button
            Button {
                guard !isTransitioning else { return }
                navigateForward()
            } label: {
                if manager.isSyncing {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text(buttonLabel)
                }
            }
            .primaryButton(isEnabled: manager.canContinue && !isTransitioning)
            .disabled(!manager.canContinue || manager.isSyncing || isTransitioning)
            .padding(.horizontal, AppButtons.horizontalPadding)
            .opacity(buttonVisible ? 1 : 0)
            .blur(radius: buttonVisible ? 0 : 8)
            .animation(.easeOut(duration: 0.35), value: buttonVisible)
        }
        .padding(.bottom, AppSpacing.screenBottom)
    }

    // MARK: - Private Methods

    private func showButton() {
        buttonVisible = true
    }

    private func starOpacityForStep(_ step: OnboardingStep) -> Double {
        switch step {
        case .intro: return 1.0
        case .confirmation: return 0.35
        default: return 0.5
        }
    }

    private func transitionToHome() {
        isTransitioning = true
        HapticManager.shared.success()

        // Blur out everything
        contentVisible = false
        buttonVisible = false
        backVisible = false

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            showHome = true
        }
    }

    private func transitionToSteps() {
        HapticManager.shared.softTap()
        splashVisible = false

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            manager.phase = .steps
            buttonLabel = "Get Started"
            contentVisible = true
        }
    }

    private func navigateForward() {
        // On confirmation step, transition to home
        if manager.currentStep == .confirmation {
            transitionToHome()
            return
        }

        isTransitioning = true

        // Blur out content + button + back + backgrounds
        contentVisible = false
        buttonVisible = false
        backVisible = false
        voiceVisualizerVisible = false
        withAnimation(.easeOut(duration: 0.4)) {
            customBackground = nil
        }

        Task {
            // Wait for blur-out
            try? await Task.sleep(for: .milliseconds(400))

            // Advance step (synchronous)
            manager.advanceToNextStep()
            buttonLabel = "Continue"

            // Star opacity per step
            withAnimation(.easeInOut(duration: 0.5)) {
                starOpacity = starOpacityForStep(manager.currentStep)
            }

            // Show/hide special backgrounds
            voiceVisualizerVisible = manager.currentStep == .voice

            // Reset sunrise if entering generating step (it will animate itself)
            if manager.currentStep == .generating {
                sunriseProgress = 0
            }

            // Show content — the new step's .task handles its own staggered entry
            contentVisible = true

            // Hide back/button on generating and confirmation
            let isAutoStep = manager.currentStep == .generating || manager.currentStep == .confirmation
            backVisible = !isAutoStep && manager.canGoBack
            if isAutoStep {
                buttonVisible = false
            }

            isTransitioning = false
        }
    }

    private func autoAdvanceFromGenerating() {
        isTransitioning = true
        contentVisible = false

        Task {
            try? await Task.sleep(for: .milliseconds(500))

            // Set step directly — bypass canContinue which returns false for .generating
            manager.currentStep = .confirmation
            buttonLabel = "Schedule Alarm"

            // Fade sunrise back down for confirmation screen
            withAnimation(.easeOut(duration: 1.0)) {
                sunriseProgress = 0
            }

            // Dim stars heavily for confirmation screen
            withAnimation(.easeInOut(duration: 0.5)) {
                starOpacity = 0.2
            }

            contentVisible = true
            backVisible = true

            isTransitioning = false

            // Show the Schedule Alarm button after the hero + card sequence (~3s)
            try? await Task.sleep(for: .seconds(3))
            buttonVisible = true
        }
    }

    private func goBack() {
        guard !isTransitioning else { return }
        isTransitioning = true

        // Blur out content + button + back + custom background
        contentVisible = false
        buttonVisible = false
        backVisible = false
        voiceVisualizerVisible = false
        withAnimation(.easeOut(duration: 0.4)) {
            customBackground = nil
        }

        Task {
            // Wait for blur-out
            try? await Task.sleep(for: .milliseconds(400))

            // Go back — skip .generating (it's not a user-navigable step)
            manager.goBack()
            if manager.currentStep == .generating {
                manager.goBack()
            }
            buttonLabel = manager.currentStep == .intro ? "Get Started" : "Continue"

            // Restore star opacity for the new step
            withAnimation(.easeInOut(duration: 0.5)) {
                starOpacity = starOpacityForStep(manager.currentStep)
            }

            // Show/hide special backgrounds
            voiceVisualizerVisible = manager.currentStep == .voice

            // Reset sunrise when navigating away
            withAnimation(.easeOut(duration: 0.3)) {
                sunriseProgress = 0
            }

            // Show content
            contentVisible = true
            backVisible = manager.canGoBack

            isTransitioning = false
        }
    }
}

// MARK: - Preview Helper

struct OnboardingStepPreview: View {
    let step: OnboardingStep

    var body: some View {
        OnboardingContainerView()
            .onAppear {
                // Handled via the startStep environment key
            }
    }
}

extension OnboardingContainerView {
    @MainActor
    static func preview(step: OnboardingStep) -> some View {
        OnboardingContainerView()
            .environment(\.previewStep, step)
    }
}

private struct PreviewStepKey: EnvironmentKey {
    static let defaultValue: OnboardingStep? = nil
}

extension EnvironmentValues {
    var previewStep: OnboardingStep? {
        get { self[PreviewStepKey.self] }
        set { self[PreviewStepKey.self] = newValue }
    }
}

#Preview {
    OnboardingContainerView()
}
