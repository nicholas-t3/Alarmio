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
    case content
    case leaveTime
    case wakeTime
    case snooze
}

struct OnboardingContainerView: View {

    // MARK: - State

    @State private var manager = OnboardingManager()
    @State private var deviceInfo = DeviceInfo()
    @State private var splashVisible = true
    @State private var contentVisible = true
    @State private var buttonVisible = false
    @State private var backVisible = false
    @State private var buttonLabel = "Get Started"
    @State private var isTransitioning = false

    // MARK: - Body

    var body: some View {
        ZStack {

            // Shared night sky background
            NightSkyBackground()

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
            OnboardingToneView(onReadyForButton: {
                showButton()
            })

        default:
            Text("Step \(manager.currentStep.rawValue + 1)")
                .font(AppTypography.headlineLarge)
                .foregroundStyle(.white)
                .task {
                    try? await Task.sleep(for: .milliseconds(300))
                    showButton()
                }
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

        // Blur out content + button + back
        contentVisible = false
        buttonVisible = false
        backVisible = false

        Task {
            // Wait for blur-out
            try? await Task.sleep(for: .milliseconds(400))

            // Advance step (synchronous)
            manager.advanceToNextStep()
            buttonLabel = "Continue"

            // Show content — the new step's .task handles its own staggered entry
            contentVisible = true
            backVisible = manager.canGoBack

            isTransitioning = false
        }
    }

    private func goBack() {
        guard !isTransitioning else { return }
        isTransitioning = true

        // Blur out content + button + back
        contentVisible = false
        buttonVisible = false
        backVisible = false

        Task {
            // Wait for blur-out
            try? await Task.sleep(for: .milliseconds(400))

            // Go back (synchronous)
            manager.goBack()
            buttonLabel = manager.currentStep == .intro ? "Get Started" : "Continue"

            // Show content
            contentVisible = true
            backVisible = manager.canGoBack

            isTransitioning = false
        }
    }
}

#Preview {
    OnboardingContainerView()
}
