//
//  AlertManager.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

@Observable
@MainActor
final class AlertManager {

    // MARK: - State

    private(set) var currentAlert: AlertItem?
    private(set) var isPresenting = false

    private(set) var currentToast: ToastItem?

    var hasAlert: Bool { currentAlert != nil }

    private var toastDismissTask: Task<Void, Never>?

    // MARK: - Show Modal

    func showModal(
        title: String,
        message: String,
        dismissible: Bool = true,
        primaryAction: AlertAction? = nil,
        secondaryAction: AlertAction? = nil
    ) {
        let alert = AlertItem(
            title: title,
            message: message,
            dismissible: dismissible,
            primaryAction: primaryAction,
            secondaryAction: secondaryAction
        )
        currentAlert = alert

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isPresenting = true
        }
    }

    // MARK: - Dismiss

    func dismiss() {
        let onDismiss = currentAlert?.onDismiss

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isPresenting = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.currentAlert = nil
            onDismiss?()
        }
    }

    // MARK: - Show Toast

    func showToast(message: String, kind: ToastKind, duration: TimeInterval = 2.0) {
        toastDismissTask?.cancel()

        let toast = ToastItem(message: message, kind: kind)

        // If one is already showing, replace it cleanly.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentToast = toast
        }

        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.dismissToast()
            }
        }
    }

    func dismissToast() {
        toastDismissTask?.cancel()
        toastDismissTask = nil

        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            currentToast = nil
        }
    }
}

// MARK: - Models

struct AlertItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let dismissible: Bool
    let primaryAction: AlertAction?
    let secondaryAction: AlertAction?
    var onDismiss: (() -> Void)? = nil

    static func == (lhs: AlertItem, rhs: AlertItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct AlertAction: Equatable {
    let label: String
    let action: () -> Void

    static func == (lhs: AlertAction, rhs: AlertAction) -> Bool {
        lhs.label == rhs.label
    }
}

enum ToastKind: Equatable {
    case success
    case failure
}

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let kind: ToastKind
}

// MARK: - Environment Key

struct AlertManagerKey: EnvironmentKey {
    static let defaultValue = AlertManager()
}

extension EnvironmentValues {
    var alertManager: AlertManager {
        get { self[AlertManagerKey.self] }
        set { self[AlertManagerKey.self] = newValue }
    }
}
