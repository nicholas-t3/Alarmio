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
    case permission
}

struct OnboardingContainerView: View {

    // MARK: - State

    @Environment(\.previewStep) private var previewStep
    @State private var manager = OnboardingManager()
    @State private var deviceInfo = DeviceInfo()
    @State private var splashVisible = true
    @State private var contentVisible = true
    @State private var buttonVisible = false
    @State private var backVisible = false
    @State private var buttonLabel = "Get Started"
    @State private var isTransitioning = false
    @State private var customBackground: [Color]? = nil
    @State private var starDimmed = false
    @State private var voiceVisualizerPalette: VisualizerPalette? = nil
    @State private var voiceVisualizerPlaying = false
    @State private var voiceVisualizerVisible = false

    // MARK: - Body

    var body: some View {
        ZStack {

            // Shared night sky background — gradient is unaffected, only stars dim
            MorningSky(starOpacity: starDimmed ? 0.5 : 1.0)

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

            // Voice visualizer background — full screen, behind all content
            if let palette = voiceVisualizerPalette {
                VoiceVisualizer(palette: palette, isPlaying: voiceVisualizerPlaying)
                    .opacity(voiceVisualizerVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5), value: voiceVisualizerVisible)
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

                    // Back button — always reserve the space
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
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            deviceInfo.updateScreenSize(width: size.width, height: size.height)
        }
        .task {
            await manager.startOnboarding()

            // If previewing a specific step, skip splash
            if let step = previewStep {
                manager.phase = .steps
                manager.currentStep = step
                contentVisible = true
                backVisible = manager.canGoBack
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

        case .permission:
            OnboardingPermissionView(onReadyForButton: { showButton() })
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

            // Dim stars from the tone screen onward
            let shouldDim = manager.currentStep.rawValue >= OnboardingStep.tone.rawValue
            withAnimation(.easeInOut(duration: 0.5)) {
                starDimmed = shouldDim
            }

            // Show/hide voice visualizer background
            voiceVisualizerVisible = manager.currentStep == .voice

            // Show content — the new step's .task handles its own staggered entry
            contentVisible = true
            backVisible = manager.canGoBack

            isTransitioning = false
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

            // Go back (synchronous)
            manager.goBack()
            buttonLabel = manager.currentStep == .intro ? "Get Started" : "Continue"

            // Restore star brightness if back before tone
            withAnimation(.easeInOut(duration: 0.5)) {
                starDimmed = manager.currentStep.rawValue >= OnboardingStep.tone.rawValue
            }

            // Show/hide voice visualizer background
            voiceVisualizerVisible = manager.currentStep == .voice

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
