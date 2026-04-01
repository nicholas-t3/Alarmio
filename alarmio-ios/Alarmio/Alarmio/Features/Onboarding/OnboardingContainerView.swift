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
    // Future steps: why, intensity, difficulty, voice, content, leaveTime, wakeTime, snooze
}

struct OnboardingContainerView: View {

    // MARK: - State

    @State private var phase: OnboardingPhase = .splash
    @State private var currentStep: OnboardingStep = .intro
    @State private var stepVisible = false
    @State private var splashVisible = true
    @State private var selectedTone: String? = nil

    // MARK: - Body

    var body: some View {
        ZStack {

            // Shared night sky background
            NightSkyBackground()

            // Current phase
            switch phase {
            case .splash:
                SplashContentView(onFinished: {
                    transitionToSteps()
                })
                .premiumBlur(isVisible: splashVisible, duration: 0.5)

            case .steps:
                stepContent
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .intro:
            OnboardingIntroView(onContinue: { advanceToStep(.tone) })
                .premiumBlur(isVisible: stepVisible)

        case .tone:
            OnboardingToneView(
                selectedTone: $selectedTone,
                onContinue: { /* next step */ }
            )
            .premiumBlur(isVisible: stepVisible)
        }
    }

    // MARK: - Private Methods

    private func transitionToSteps() {
        HapticManager.shared.softTap()

        // Blur out splash
        splashVisible = false

        Task {
            // Wait for blur-out to finish
            try? await Task.sleep(for: .milliseconds(500))

            // Swap phase
            phase = .steps

            // Blur in first step
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeOut(duration: 0.4)) {
                stepVisible = true
            }
        }
    }

    private func advanceToStep(_ step: OnboardingStep) {
        HapticManager.shared.softTap()

        withAnimation(.easeOut(duration: 0.3)) {
            stepVisible = false
        }

        Task {
            try? await Task.sleep(for: .milliseconds(350))
            currentStep = step

            withAnimation(.easeOut(duration: 0.4)) {
                stepVisible = true
            }
        }
    }
}

#Preview {
    OnboardingContainerView()
}
