//
//  OnboardingGeneratingView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

/// Renders the rotating personalized status text over the shared sky while
/// OnboardingContainerView drives the real ComposerService call. Dumb view
/// by design — sunrise/star-spin animations and the composer call are all
/// owned by the container (mirrors CreateAlarmView's generating phase).
struct OnboardingGeneratingView: View {

    // MARK: - Constants

    let statusText: String
    let isVisible: Bool

    // MARK: - Body

    var body: some View {
        VStack {

            Spacer()

            Text(statusText)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 0)
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 0)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .premiumBlur(isVisible: isVisible, duration: 0.4, disableScale: true, disableOffset: true)

            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("In Container — Generating") {
    OnboardingContainerView.preview(step: .generating)
}

#Preview("Standalone") {
    ZStack {
        MorningSky(starOpacity: 0.3, sunriseProgress: 0.6, starSpinProgress: 1.0)
        OnboardingGeneratingView(statusText: "Calling the drill sergeant", isVisible: true)
    }
}
