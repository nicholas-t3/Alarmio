//
//  OnboardingProgressBar.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct OnboardingProgressBar: View {

    // MARK: - Constants

    let currentStep: Int
    let totalSteps: Int

    // MARK: - State

    @State private var glowPhase: CGFloat = 0

    private var progress: CGFloat {
        guard totalSteps > 0 else { return 0 }
        return CGFloat(currentStep) / CGFloat(totalSteps)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let filledWidth = width * progress

            ZStack(alignment: .leading) {

                // Track
                Capsule()
                    .fill(.white.opacity(0.08))
                    .frame(height: 4)

                // Filled portion
                Capsule()
                    .fill(.white.opacity(0.6))
                    .frame(width: max(4, filledWidth), height: 4)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)

                // Glow on leading edge
                Circle()
                    .fill(.white.opacity(0.8))
                    .frame(width: 6, height: 6)
                    .blur(radius: 3)
                    .offset(x: max(0, filledWidth - 3))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
                    .opacity(progress > 0 ? 1 : 0)

                // Star dots at each step position
                HStack(spacing: 0) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        Circle()
                            .fill(.white.opacity(step < currentStep ? 0.7 : 0.15))
                            .frame(width: step < currentStep ? 3 : 2, height: step < currentStep ? 3 : 2)
                            .animation(.easeOut(duration: 0.3), value: currentStep)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(height: 6)
    }
}

#Preview {
    ZStack {
        NightSkyBackground()

        VStack(spacing: 40) {
            OnboardingProgressBar(currentStep: 0, totalSteps: 9)
            OnboardingProgressBar(currentStep: 1, totalSteps: 9)
            OnboardingProgressBar(currentStep: 3, totalSteps: 9)
            OnboardingProgressBar(currentStep: 5, totalSteps: 9)
            OnboardingProgressBar(currentStep: 9, totalSteps: 9)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}
