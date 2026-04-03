//
//  SettingsView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/3/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct SettingsView: View {

    // MARK: - Environment

    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - Constants

    private let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // Subscription badge
            subscriptionBadge
                .padding(.bottom, 28)

            // Menu rows
            VStack(spacing: 2) {
                settingsRow(icon: "doc.text", title: "Terms of Service") {
                    // TODO: Open terms URL
                    HapticManager.shared.softTap()
                }

                settingsRow(icon: "lock.shield", title: "Privacy Policy") {
                    // TODO: Open privacy URL
                    HapticManager.shared.softTap()
                }

                settingsRow(icon: "envelope", title: "Contact Support") {
                    // TODO: Open support email
                    HapticManager.shared.softTap()
                }

                settingsRow(icon: "arrow.clockwise", title: "Restore Purchases") {
                    // TODO: RevenueCat restore
                    HapticManager.shared.softTap()
                }
            }

            Spacer()
                .frame(height: 24)

            // App info footer
            VStack(spacing: 6) {
                Text("alarmio")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.2))

                Text(appVersion)
                    .font(AppTypography.caption)
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.15))
            }

            Spacer()
                .frame(height: 12)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.vertical, 24)
    }

    // MARK: - Subviews

    private var subscriptionBadge: some View {
        VStack(spacing: 10) {

            // Moon icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 56, height: 56)

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "E8A060"),
                                Color(hex: "CC6A20")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Tier label
            Text("FREE")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.5))

            // Upgrade nudge
            Text("Unlock all voices & unlimited alarms")
                .font(AppTypography.bodySmall)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)

            // Upgrade button
            Button {
                HapticManager.shared.buttonTap()
                // TODO: Present paywall
            } label: {
                Text("Upgrade to Pro")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "E8A060"),
                                        Color(hex: "D4854A")
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    private func settingsRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.rowIconGap) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: AppSpacing.rowIconWidth)

                Text(title)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, AppSpacing.rowHorizontal)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Previews

#Preview("Settings Modal") {
    struct PreviewContainer: View {
        @State private var showSettings = true

        var body: some View {
            ZStack {
                MorningSky(starOpacity: 0.8, showConstellations: false)

                MotionModal(isPresented: $showSettings, dismissible: true) {
                    SettingsView()
                }
            }
        }
    }

    return PreviewContainer()
}

#Preview("Settings Content") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        SettingsView()
    }
}
