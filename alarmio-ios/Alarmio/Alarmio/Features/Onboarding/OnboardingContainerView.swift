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
    @State private var stepVisible = false
    @State private var splashVisible = true
    @State private var previousStep: OnboardingStep = .intro

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
                stepContent
            }
        }
        .environment(manager)
        .task {
            await manager.startOnboarding()
        }
        .onChange(of: manager.currentStep) { oldStep, newStep in
            guard manager.phase == .steps, oldStep != newStep else { return }
            animateStepTransition()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var stepContent: some View {
        switch manager.currentStep {
        case .intro:
            OnboardingIntroView()
                .premiumBlur(isVisible: stepVisible)

        case .tone:
            OnboardingToneView()
                .premiumBlur(isVisible: stepVisible)

        // Future steps
        default:
            Text("Step \(manager.currentStep.rawValue + 1)")
                .font(AppTypography.headlineLarge)
                .foregroundStyle(.white)
                .premiumBlur(isVisible: stepVisible)
        }
    }

    // MARK: - Private Methods

    private func transitionToSteps() {
        HapticManager.shared.softTap()
        splashVisible = false

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            manager.phase = .steps

            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeOut(duration: 0.4)) {
                stepVisible = true
            }
        }
    }

    private func animateStepTransition() {
        withAnimation(.easeOut(duration: 0.3)) {
            stepVisible = false
        }

        Task {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeOut(duration: 0.4)) {
                stepVisible = true
            }
        }
    }
}

#Preview {
    OnboardingContainerView()
}
