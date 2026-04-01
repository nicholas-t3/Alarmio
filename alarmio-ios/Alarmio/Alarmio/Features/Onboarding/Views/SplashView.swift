//
//  SplashView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct SplashContentView: View {

    // MARK: - State

    @State private var logoText = "."
    @State private var logoVisible = false
    @State private var glowPulse = false

    // MARK: - Constants

    let onFinished: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            Spacer()

            // Logo
            VStack(spacing: 12) {

                // Logo text — hidden dot seeds numericText, blur-in synced with morph
                Text(logoText)
                    .font(AppTypography.logo)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: logoText)
                    .premiumBlur(isVisible: logoVisible, duration: 0.6)

                // Glow underneath logo
                Ellipse()
                    .fill(.white.opacity(glowPulse ? 0.06 : 0.02))
                    .frame(width: 180, height: 6)
                    .blur(radius: 16)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: glowPulse)
            }

            Spacer()
        }
        .task {
            await runSequence()
        }
    }

    // MARK: - Private Methods

    @MainActor
    private func runSequence() async {
        // 1. Swap dot → "alarmio" and blur-in together
        try? await Task.sleep(for: .milliseconds(800))
        logoText = "alarmio"
        logoVisible = true
        HapticManager.shared.softTap()

        // 2. Start glow pulse
        try? await Task.sleep(for: .milliseconds(700))
        glowPulse = true

        // 3. Hold for a moment, then signal done
        try? await Task.sleep(for: .milliseconds(2000))
        HapticManager.shared.lightTap()
        onFinished()
    }
}

#Preview {
    ZStack {
        NightSkyBackground()
        SplashContentView(onFinished: {})
    }
}
