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

            // Modal alert
            if let alert = alertManager.currentAlert {
                MotionModal(isPresented: $showMotionModal, dismissible: alert.dismissible) {
                    ModalAlertContent(alert: alert)
                }
            }

            // Toast
            ToastOverlay(toast: alertManager.currentToast) {
                alertManager.dismissToast()
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

// MARK: - Toast Overlay

private struct ToastOverlay: View {

    let toast: ToastItem?
    let onTap: () -> Void

    var body: some View {
        VStack {
            Spacer()

            if let toast {
                ToastView(toast: toast)
                    .onTapGesture { onTap() }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        )
                    )
                    .id(toast.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(toast != nil)
    }
}

// MARK: - Toast View

private struct ToastView: View {

    let toast: ToastItem

    private var tint: Color {
        switch toast.kind {
        case .success: return Color(hex: "4AFF8E")
        case .failure: return Color(hex: "FF5A5A")
        }
    }

    private var icon: String {
        switch toast.kind {
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {

            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)

            Text(toast.message)
                .font(AppTypography.labelMedium)
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(tint.opacity(0.4), lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(width: 3)
                .padding(.vertical, 10)
                .padding(.leading, 4)
        }
        .shadow(color: tint.opacity(0.25), radius: 18, y: 8)
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

#Preview("Modal") {
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

#Preview("Toast Success") {
    let alertManager = AlertManager()

    ZStack {
        NightSkyBackground()
        GlobalAlertOverlay()
    }
    .environment(\.alertManager, alertManager)
    .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            alertManager.showToast(message: "Success", kind: .success)
        }
    }
}

#Preview("Toast Failure") {
    let alertManager = AlertManager()

    ZStack {
        NightSkyBackground()
        GlobalAlertOverlay()
    }
    .environment(\.alertManager, alertManager)
    .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            alertManager.showToast(
                message: "Something went wrong. Please try again. (timeout)",
                kind: .failure,
                duration: 5.0
            )
        }
    }
}

#Preview("Toast Cycle") {
    ToastCyclePreview()
}

private struct ToastCyclePreview: View {

    // MARK: - State

    @State private var alertManager = AlertManager()
    @State private var cycleTask: Task<Void, Never>?

    // MARK: - Constants

    private let sequence: [(ToastKind, String)] = [
        (.success, "Success"),
        (.failure, "Something went wrong. Please try again. (429)"),
        (.success, "Alarm regenerated"),
        (.failure, "Something went wrong. Please try again. (timeout)"),
        (.success, "Saved")
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            NightSkyBackground()

            VStack(spacing: 12) {
                Text("Toast cycle")
                    .font(AppTypography.headlineLarge)
                    .tracking(AppTypography.headlineLargeTracking)
                    .foregroundStyle(.white.opacity(0.9))

                Text("Alternating success / failure toasts")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(.white.opacity(0.5))
            }

            GlobalAlertOverlay()
        }
        .environment(\.alertManager, alertManager)
        .onAppear {
            cycleTask = Task { await runCycle() }
        }
        .onDisappear {
            cycleTask?.cancel()
        }
    }

    // MARK: - Private Methods

    @MainActor
    private func runCycle() async {
        var index = 0
        try? await Task.sleep(for: .milliseconds(400))

        while !Task.isCancelled {
            let (kind, message) = sequence[index % sequence.count]
            alertManager.showToast(message: message, kind: kind, duration: 1.8)

            // Show duration + gap between toasts
            try? await Task.sleep(for: .milliseconds(2400))
            index += 1
        }
    }
}
