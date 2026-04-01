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

    // MARK: - Constants

    let onTitleComplete: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            Spacer()

            // Title — word by word reveal
            WordRevealText(
                "Wake Up Your Way.",
                font: AppTypography.logoSubhead,
                wordDelay: 0.4,
                onComplete: {
                    subtitleRevealed = true
                    onTitleComplete()
                }
            )
            .padding(.horizontal, AppSpacing.screenHorizontal)

            // Subtitle
            Text("Personalized alarms that actually\nmake you want to get up.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, AppSpacing.itemGap(1.0))
                .premiumBlur(isVisible: subtitleRevealed, duration: 0.4)

            Spacer()
        }
    }
}

#Preview {
    ZStack {
        NightSkyBackground()
        OnboardingIntroView(onTitleComplete: {})
    }
}
