//
//  OnboardingPermissionView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct OnboardingPermissionView: View {

    // MARK: - Environment

    @Environment(OnboardingManager.self) private var manager
    @Environment(\.alertManager) private var alertManager
    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - State

    @State private var contentVisible = false
    @State private var iconBounce = 0
    @State private var isRequesting = false

    // MARK: - Constants

    let onReadyForButton: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            Spacer()

            // Icon
            Image(systemName: "alarm.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.8))
                .symbolEffect(.bounce.down.byLayer, value: iconBounce)
                .blur(radius: contentVisible ? 0 : 8)
                .opacity(contentVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: contentVisible)

            Spacer()
                .frame(height: AppSpacing.sectionGap(deviceInfo.spacingScale) * 0.6)

            // Title
            Text("Allow Alarms")
                .font(AppTypography.headlineLarge)
                .tracking(AppTypography.headlineLargeTracking)
                .foregroundStyle(.white)
                .premiumBlur(isVisible: contentVisible, duration: 0.4)

            Spacer()
                .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale))

            // Description
            Text("Alarmio needs permission to set alarms\nthat wake you up — even in silent mode.")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .blur(radius: contentVisible ? 0 : 8)
                .opacity(contentVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: contentVisible)

            Spacer()
                .frame(height: AppSpacing.sectionGap(deviceInfo.spacingScale))

            // Permission status
            if manager.alarmPermissionGranted {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)

                    Text("Permission granted")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if manager.alarmPermissionDenied {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.red.opacity(0.8))

                        Text("Permission denied")
                            .font(AppTypography.labelLarge)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Text("Tap below to open Settings")
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(.white.opacity(0.3))
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if !isRequesting {
                // Request button
                Button {
                    requestPermission()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 16))
                        Text("Enable Alarms")
                            .font(AppTypography.labelLarge)
                    }
                    .foregroundStyle(.white)
                    .frame(height: 50)
                    .frame(maxWidth: 220)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    )
                }
                .blur(radius: contentVisible ? 0 : 8)
                .opacity(contentVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.15), value: contentVisible)
            } else {
                ProgressView()
                    .tint(.white)
            }

            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.alarmPermissionGranted)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.alarmPermissionDenied)
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            contentVisible = true
            iconBounce += 1

            try? await Task.sleep(for: .milliseconds(600))
            onReadyForButton()
        }
    }

    // MARK: - Private Methods

    private func requestPermission() {
        HapticManager.shared.buttonTap()
        isRequesting = true

        Task {
            await manager.requestAlarmPermission()
            isRequesting = false

            if manager.alarmPermissionDenied {
                // Show modal telling them to go to Settings
                alertManager.showModal(
                    title: "Permission Required",
                    message: "Alarmio can't set alarms without permission.\nPlease enable it in Settings.",
                    dismissible: true,
                    primaryAction: AlertAction(label: "Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondaryAction: AlertAction(label: "Not Now") {}
                )
            }
        }
    }
}

#Preview {
    OnboardingContainerView.preview(step: .permission)
}
