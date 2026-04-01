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
    @State private var stepVisible = false
    @State private var splashVisible = true
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

                    // Back button
                    HStack {
                        if manager.canGoBack {
                            Button {
                                goBack()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .premiumBlur(isVisible: backVisible, duration: 0.3)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal - 8)
                    .frame(height: 44)

                    // Step content
                    stepContent
                        .frame(maxHeight: .infinity)

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
                withAnimation(.easeOut(duration: 0.4)) {
                    buttonVisible = true
                }
            })
            .premiumBlur(isVisible: stepVisible)

        case .tone:
            OnboardingToneView()
                .premiumBlur(isVisible: stepVisible)

        default:
            Text("Step \(manager.currentStep.rawValue + 1)")
                .font(AppTypography.headlineLarge)
                .foregroundStyle(.white)
                .premiumBlur(isVisible: stepVisible)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {

            // Continue / Get Started button
            Button {
                guard !isTransitioning else { return }
                continueForward()
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
            .premiumBlur(isVisible: buttonVisible, duration: 0.4)

            // Progress bar (commented out for now)
//            if manager.currentStep != .intro {
//                OnboardingProgressBar(
//                    currentStep: manager.progressStep,
//                    totalSteps: OnboardingManager.interactiveStepCount
//                )
//                .padding(.horizontal, AppButtons.horizontalPadding + 8)
//            }
        }
        .padding(.bottom, AppSpacing.screenBottom)
    }

    // MARK: - Private Methods

    private func transitionToSteps() {
        HapticManager.shared.softTap()
        splashVisible = false

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            manager.phase = .steps
            buttonLabel = "Get Started"

            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeOut(duration: 0.4)) {
                stepVisible = true
            }
        }
    }

    private func continueForward() {
        isTransitioning = true

        // Blur everything out together
        withAnimation(.easeOut(duration: 0.3)) {
            stepVisible = false
            buttonVisible = false
            backVisible = false
        }

        // Let the manager do its sync + advance
        manager.continueToNextStep()

        Task {
            // Wait for blur-out + sync
            try? await Task.sleep(for: .milliseconds(400))

            // Update button label while hidden
            buttonLabel = "Continue"

            // Blur everything back in
            withAnimation(.easeOut(duration: 0.4)) {
                stepVisible = true
                backVisible = manager.canGoBack
            }

            // Button comes in slightly after content
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.4)) {
                buttonVisible = true
            }

            isTransitioning = false
        }
    }

    private func goBack() {
        guard !isTransitioning else { return }
        isTransitioning = true

        // Blur everything out
        withAnimation(.easeOut(duration: 0.3)) {
            stepVisible = false
            buttonVisible = false
            backVisible = false
        }

        Task {
            try? await Task.sleep(for: .milliseconds(350))

            manager.goBack()

            // Update button label
            buttonLabel = manager.currentStep == .intro ? "Get Started" : "Continue"

            // Blur in
            withAnimation(.easeOut(duration: 0.4)) {
                stepVisible = true
                backVisible = manager.canGoBack
            }

            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.4)) {
                buttonVisible = true
            }

            isTransitioning = false
        }
    }
}

#Preview {
    OnboardingContainerView()
}
