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

    var hasAlert: Bool { currentAlert != nil }

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
