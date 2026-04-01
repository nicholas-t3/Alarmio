//
//  SplashView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct SplashView: View {

    // MARK: - State

    @State private var logoText = "."
    @State private var logoVisible = false
    @State private var glowPulse = false
    @State private var gradientActive = false

    // MARK: - Body

    var body: some View {
        ZStack {

            // Background
            Color(hex: "050505")
                .ignoresSafeArea()

            // Ambient mesh gradient
            MeshGradientBackground(speed: 0.015, opacity: gradientActive ? 0.3 : 0)
                .animation(.easeIn(duration: 2.5), value: gradientActive)

            // Content
            VStack(spacing: 0) {

                Spacer()

                // Logo
                VStack(spacing: 16) {

                    // Logo text — hidden dot seeds numericText, blur-in synced with morph
                    Text(logoText)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: logoText)
                        .premiumBlur(isVisible: logoVisible, duration: 0.6)

                    // Glow underneath logo
                    Ellipse()
                        .fill(.white.opacity(glowPulse ? 0.08 : 0.03))
                        .frame(width: 200, height: 8)
                        .blur(radius: 20)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: glowPulse)
                }


                Spacer()
            }
        }
        .task {
            await runSequence()
        }
    }

    // MARK: - Private Methods

    @MainActor
    private func runSequence() async {
        // 1. Gradient starts warming up
        try? await Task.sleep(for: .milliseconds(300))
        gradientActive = true

        // 2. Swap dot → "alarmio" and blur-in at the same time
        //    The dot is never seen — it just seeds the numericText transition
        try? await Task.sleep(for: .milliseconds(500))
        logoText = "alarmio"
        logoVisible = true

        // 3. Start glow pulse
        try? await Task.sleep(for: .milliseconds(700))
        glowPulse = true

    }
}

#Preview {
    SplashView()
}
