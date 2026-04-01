//
//  OnboardingIntroView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct OnboardingIntroView: View {

    // MARK: - State

    @State private var subtitleRevealed = false
    @State private var buttonRevealed = false

    // MARK: - Constants

    let onContinue: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            Spacer()

            // Title — word by word reveal in logo font
            WordRevealText(
                "Wake Up Your Way.",
                font: AppTypography.logo,
                wordDelay: 0.4,
                lineSpacing: 2,
                onComplete: { revealRest() }
            )
            .padding(.horizontal, AppSpacing.screenHorizontal)

            // Subtitle
            Text("Personalized alarms that actually\nmake you want to get up.")
                .bodyMedium()
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, AppSpacing.itemGap)
                .premiumBlur(isVisible: subtitleRevealed, duration: 0.4)

            Spacer()

            // Get started button
            Button {
                HapticManager.shared.buttonTap()
                onContinue()
            } label: {
                Text("Get started")
            }
            .primaryButton()
            .padding(.horizontal, AppButtons.horizontalPadding)
            .padding(.bottom, AppSpacing.screenBottom)
            .premiumBlur(isVisible: buttonRevealed, duration: 0.4)
        }
    }

    // MARK: - Private Methods

    private func revealRest() {
        subtitleRevealed = true

        Task {
            try? await Task.sleep(for: .milliseconds(300))
            buttonRevealed = true
        }
    }
}

#Preview {
    ZStack {
        NightSkyBackground()
        OnboardingIntroView(onContinue: {})
    }
}
