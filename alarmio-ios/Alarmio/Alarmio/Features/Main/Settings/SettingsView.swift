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
    @Environment(\.subscriptionService) private var subscription
    @Environment(\.alertManager) private var alertManager

    // MARK: - State

    @State private var showPaywall = false
    @State private var safariURL: IdentifiableURL?

    // MARK: - Constants

    private let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }()

    private let appVersionShort: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return version
    }()

    private let termsURL = URL(string: "https://alarmioapp.com/terms-of-use")!
    private let privacyURL = URL(string: "https://alarmioapp.com/privacy-policy")!
    private let supportEmail = "support@alarmioapp.com"

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // Subscription badge
            subscriptionBadge
                .padding(.bottom, 28)

            // Menu rows
            VStack(spacing: 2) {
                settingsRow(icon: "doc.text", title: "Terms of Service") {
                    HapticManager.shared.softTap()
                    safariURL = IdentifiableURL(url: termsURL)
                }

                settingsRow(icon: "lock.shield", title: "Privacy Policy") {
                    HapticManager.shared.softTap()
                    safariURL = IdentifiableURL(url: privacyURL)
                }

                settingsRow(icon: "envelope", title: "Contact Support") {
                    HapticManager.shared.softTap()
                    openSupportEmail()
                }

                settingsRow(icon: "arrow.clockwise", title: "Restore Purchases") {
                    HapticManager.shared.softTap()
                    restorePurchases()
                }
            }

            #if DEBUG
            debugSubscriptionMenu
                .padding(.top, 24)
            #endif

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
        .sheet(isPresented: $showPaywall) {
            PaywallSheet()
        }
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
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
            Text(subscription.isPro ? "PRO" : "FREE")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.5))
                .contentTransition(.numericText())

            if subscription.isPro {
                Text("Subscription active")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            } else {
                // Upgrade nudge
                Text("Unlock all voices & unlimited alarms")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)

                // Upgrade button
                Button {
                    HapticManager.shared.buttonTap()
                    showPaywall = true
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
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))
        .animation(.easeInOut(duration: 0.25), value: subscription.isPro)
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

    // MARK: - Debug Menu

    #if DEBUG
    private var debugSubscriptionMenu: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("DEBUG — SUBSCRIPTION")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.orange.opacity(0.6))
                .padding(.horizontal, AppSpacing.rowHorizontal)

            VStack(spacing: 2) {
                debugRow(
                    title: "Force Pro",
                    isActive: subscription.simulatorOverride == .forcePro
                ) {
                    subscription.setSimulatorOverride(.forcePro)
                }

                debugRow(
                    title: "Force Free",
                    isActive: subscription.simulatorOverride == .forceFree
                ) {
                    subscription.setSimulatorOverride(.forceFree)
                }

                debugRow(
                    title: "Use RevenueCat",
                    isActive: subscription.simulatorOverride == nil
                ) {
                    subscription.setSimulatorOverride(nil)
                }
            }
        }
        .padding(.vertical, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func debugRow(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            HStack {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isActive ? .orange : .white.opacity(0.3))
                    .frame(width: AppSpacing.rowIconWidth)

                Text(title)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, AppSpacing.rowHorizontal)
            .contentShape(Rectangle())
        }
    }
    #endif

    // MARK: - Support

    private func openSupportEmail() {
        let subject = "Alarmio (v\(appVersionShort)) Support"
        let body = "\n\n\n--\nAlarmio \(appVersion)"

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Restore

    private func restorePurchases() {
        Task {
            do {
                let restored = try await subscription.restorePurchases()
                if restored {
                    HapticManager.shared.success()
                } else {
                    alertManager.showModal(
                        title: "Nothing to restore",
                        message: "We couldn't find an active subscription on this Apple ID.",
                        primaryAction: AlertAction(label: "OK") {}
                    )
                }
            } catch {
                print("[SettingsView] Restore failed: \(error)")
                alertManager.showModal(
                    title: "Restore failed",
                    message: "Please check your connection and try again.",
                    primaryAction: AlertAction(label: "OK") {}
                )
            }
        }
    }
}

// MARK: - IdentifiableURL

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - Previews

#Preview("Settings Modal") {
    struct PreviewContainer: View {
        @State private var showSettings = true

        var body: some View {
            ZStack {
                MorningSky(starOpacity: 0.8, showConstellations: false)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color(hex: "0f1a2e"))
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
