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
    @State private var skyVisible = false

    // MARK: - Body

    var body: some View {
        ZStack {

            // Night sky background
            NightSkyBackground()
                .opacity(skyVisible ? 1 : 0)
                .animation(.easeIn(duration: 2.0), value: skyVisible)

            // Content
            VStack(spacing: 0) {

                Spacer()

                // Logo
                VStack(spacing: 12) {

                    // Logo text — hidden dot seeds numericText, blur-in synced with morph
                    Text(logoText)
                        .font(.system(size: 52, weight: .black, design: .rounded))
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
        }
        .task {
            await runSequence()
        }
    }

    // MARK: - Private Methods

    @MainActor
    private func runSequence() async {
        // 1. Sky fades in
        try? await Task.sleep(for: .milliseconds(200))
        skyVisible = true

        // 2. Swap dot → "alarmio" and blur-in together
        try? await Task.sleep(for: .milliseconds(800))
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
