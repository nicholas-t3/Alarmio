//
//  GlobalAlertOverlay.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct GlobalAlertOverlay: View {

    // MARK: - Environment

    @Environment(\.alertManager) private var alertManager

    // MARK: - State

    @State private var showMotionModal = false

    // MARK: - Body

    var body: some View {
        ZStack {
            if let alert = alertManager.currentAlert {
                MotionModal(isPresented: $showMotionModal, dismissible: alert.dismissible) {
                    ModalAlertContent(alert: alert)
                }
            }
        }
        .onChange(of: alertManager.isPresenting) { _, isPresenting in
            if isPresenting {
                showMotionModal = true
            } else {
                showMotionModal = false
            }
        }
        .onChange(of: showMotionModal) { _, isShowing in
            if !isShowing && alertManager.isPresenting {
                alertManager.dismiss()
            }
        }
    }
}

// MARK: - Modal Alert Content

private struct ModalAlertContent: View {

    // MARK: - Environment

    @Environment(\.alertManager) private var alertManager

    // MARK: - Constants

    let alert: AlertItem

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {

            // Title
            Text(alert.title)
                .font(AppTypography.headlineLarge)
                .tracking(AppTypography.headlineLargeTracking)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)

            // Message
            Text(alert.message)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // Actions
            VStack(spacing: 16) {

                // Primary
                if let primary = alert.primaryAction {
                    Button {
                        HapticManager.shared.buttonTap()
                        primary.action()
                        alertManager.dismiss()
                    } label: {
                        Text(primary.label)
                    }
                    .primaryButton()
                }

                // Secondary
                if let secondary = alert.secondaryAction {
                    Button {
                        HapticManager.shared.lightTap()
                        secondary.action()
                        alertManager.dismiss()
                    } label: {
                        Text(secondary.label)
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
    }
}

#Preview {
    let alertManager = AlertManager()

    ZStack {
        NightSkyBackground()
        GlobalAlertOverlay()
    }
    .environment(\.alertManager, alertManager)
    .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            alertManager.showModal(
                title: "Permission Required",
                message: "Alarmio needs alarm permission to wake you up.\nPlease enable it in Settings.",
                dismissible: false,
                primaryAction: AlertAction(label: "Open Settings") {
                    print("Open settings")
                },
                secondaryAction: AlertAction(label: "Not Now") {
                    print("Dismissed")
                }
            )
        }
    }
}
