//
//  OnboardingContainerView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case intro = 0
    case tone
    // Future steps: why, intensity, difficulty, voice, content, leaveTime, wakeTime, snooze
}

struct OnboardingContainerView: View {

    // MARK: - State

    @State private var currentStep: OnboardingStep = .intro
    @State private var stepVisible = false
    @State private var selectedTone: String? = nil

    // MARK: - Body

    var body: some View {
        ZStack {

            // Night sky background
            NightSkyBackground()

            // Step content
            stepContent
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation {
                stepVisible = true
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
