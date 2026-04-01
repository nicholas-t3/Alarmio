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

            // Title
            VStack(spacing: 16) {
                Text("Wake up")
                    .font(.system(size: 48, weight: .light))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .blur(radius: titleRevealed ? 0 : 12)
                    .opacity(titleRevealed ? 1 : 0)
                    .scaleEffect(titleRevealed ? 1 : 0.95)
                    .animation(.easeOut(duration: 0.5), value: titleRevealed)

                Text("your way")
                    .font(.system(size: 48, weight: .light))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.6))
                    .blur(radius: titleRevealed ? 0 : 12)
                    .opacity(titleRevealed ? 1 : 0)
                    .scaleEffect(titleRevealed ? 1 : 0.95)
                    .animation(.easeOut(duration: 0.5).delay(0.15), value: titleRevealed)
            }

            // Subtitle
            Text("Personalized alarms that actually\nmake you want to get up.")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 24)
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
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
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
