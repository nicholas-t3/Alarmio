//
//  OnboardingConfirmationView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct OnboardingConfirmationView: View {

    // MARK: - Environment
    @Environment(OnboardingManager.self) private var manager
    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - State
    @State private var contentVisible = false
    @State private var checkVisible = false

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {

            Spacer()

            // Center content
            VStack(spacing: 32) {

                // Success checkmark
                ZStack {
                    Circle()
                        .fill(Color(hex: "4AFF8E").opacity(0.08))
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color(hex: "4AFF8E"))
                        .opacity(checkVisible ? 1 : 0)
                        .scaleEffect(checkVisible ? 1 : 0.5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: checkVisible)
                }

                // Text
                VStack(spacing: 12) {
                    Text("Your alarm is ready")
                        .font(AppTypography.headlineLarge)
                        .tracking(AppTypography.headlineLargeTracking)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if let time = manager.configuration.wakeTime {
                        Text(time, style: .time)
                            .font(AppTypography.headlineMedium)
                            .tracking(AppTypography.headlineMediumTracking)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Text("Tap below to schedule it")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .premiumBlur(isVisible: contentVisible, duration: 0.5)

            Spacer()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            contentVisible = true

            try? await Task.sleep(for: .milliseconds(400))
            checkVisible = true
            HapticManager.shared.success()
        }
    }
}

// MARK: - Previews

#Preview {
    OnboardingContainerView.preview(step: .confirmation)
}
