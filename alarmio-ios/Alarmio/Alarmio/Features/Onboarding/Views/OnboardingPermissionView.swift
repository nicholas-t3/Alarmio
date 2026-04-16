//
//  OnboardingPermissionView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import AlarmKit
import SwiftUI

/// Permission step — the user grants AlarmKit authorization before audio
/// generation runs. Dumb view by design: the container owns the auth
/// state and the scene-phase observer that detects return-from-Settings.
/// This view renders the hero and delegates button presentation to the
/// container's bottom bar (so the button style stays consistent with the
/// rest of onboarding).
struct OnboardingPermissionView: View {

    // MARK: - Environment

    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - State

    @State private var heroVisible = false
    @State private var iconPulse = false

    // MARK: - Constants

    let authorizationState: AlarmManager.AuthorizationState

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            Spacer()

            // Bell + title grouped — tighten the gap here without affecting
            // the title↔subtitle distance below.
            VStack(spacing: -30) {
                heroIcon
                    .premiumBlur(isVisible: heroVisible, duration: 0.5)

                Text("Permission to\nwake you up?")
                    .font(AppTypography.headlineLarge)
                    .tracking(AppTypography.headlineLargeTracking)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .premiumBlur(isVisible: heroVisible, delay: 0.1, duration: 0.5)
            }

            Spacer()
                .frame(height: 18)

            // State-aware subtitle
            Text(subtitleText)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.35), value: authorizationState)
                .padding(.horizontal, AppSpacing.screenHorizontal + 8)
                .premiumBlur(isVisible: heroVisible, delay: 0.2, duration: 0.5)

            Spacer()
            Spacer()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            heroVisible = true

            try? await Task.sleep(for: .milliseconds(400))
            iconPulse = true
        }
    }

    // MARK: - Subviews

    private var heroIcon: some View {
        ZStack {

            // Radial glow halo — gently breathes
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "FFB347").opacity(0.4),
                            Color(hex: "FFB347").opacity(0)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 110
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 22)
                .scaleEffect(iconPulse ? 1.06 : 0.94)
                .opacity(iconPulse ? 0.95 : 0.55)
                .animation(
                    .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                    value: iconPulse
                )

            // Inner glass disc
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 124, height: 124)
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                )

            // Bell — symbol morphs with authorization state
            Image(systemName: iconSystemName)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
                .contentTransition(.symbolEffect(.replace))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: authorizationState)
        }
    }

    // MARK: - Computed

    private var iconSystemName: String {
        switch authorizationState {
        case .authorized:    return "bell.badge.fill"
        case .denied:        return "bell.slash"
        case .notDetermined: return "bell"
        @unknown default:    return "bell"
        }
    }

    private var subtitleText: String {
        switch authorizationState {
        case .notDetermined:
            return "Alarmio uses Apple's AlarmKit to wake you up on time — even when your phone is silenced or on Do Not Disturb."
        case .denied:
            return "Alarms are turned off for Alarmio. Open Settings to turn them back on."
        case .authorized:
            return "You're all set. Let's build your wake-up call."
        @unknown default:
            return "Alarmio uses Apple's AlarmKit to wake you up on time."
        }
    }
}

// MARK: - Previews

#Preview("In Container") {
    OnboardingContainerView.preview(step: .permission)
}

#Preview("Not Determined") {
    ZStack {
        MorningSky(starOpacity: 0.6, sunriseProgress: 0, starSpinProgress: 0)
        OnboardingPermissionView(authorizationState: .notDetermined)
            .environment(\.deviceInfo, DeviceInfo())
    }
}

#Preview("Denied") {
    ZStack {
        MorningSky(starOpacity: 0.6, sunriseProgress: 0, starSpinProgress: 0)
        OnboardingPermissionView(authorizationState: .denied)
            .environment(\.deviceInfo, DeviceInfo())
    }
}

#Preview("Authorized") {
    ZStack {
        MorningSky(starOpacity: 0.6, sunriseProgress: 0, starSpinProgress: 0)
        OnboardingPermissionView(authorizationState: .authorized)
            .environment(\.deviceInfo, DeviceInfo())
    }
}
