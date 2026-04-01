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

    @State private var titleRevealed = false
    @State private var subtitleRevealed = false
    @State private var buttonRevealed = false

    // MARK: - Constants

    let onContinue: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            Spacer()

            // Title block
            VStack(spacing: 0) {
                Text("Wake up your way")
                    .displayLarge()
                    .multilineTextAlignment(.center)
                    .blur(radius: titleRevealed ? 0 : 12)
                    .opacity(titleRevealed ? 1 : 0)
                    .scaleEffect(titleRevealed ? 1 : 0.95)
                    .animation(.easeOut(duration: 0.5), value: titleRevealed)
            }

            // Subtitle
            Text("Personalized alarms that actually\nmake you want to get up.")
                .bodyMedium()
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, AppSpacing.itemGap)
                .blur(radius: subtitleRevealed ? 0 : 8)
                .opacity(subtitleRevealed ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: subtitleRevealed)

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
            .blur(radius: buttonRevealed ? 0 : 8)
            .opacity(buttonRevealed ? 1 : 0)
            .offset(y: buttonRevealed ? 0 : 20)
            .animation(.easeOut(duration: 0.4), value: buttonRevealed)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            titleRevealed = true

            try? await Task.sleep(for: .milliseconds(300))
            subtitleRevealed = true

            try? await Task.sleep(for: .milliseconds(200))
            buttonRevealed = true
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        OnboardingIntroView(onContinue: {})
    }
}
