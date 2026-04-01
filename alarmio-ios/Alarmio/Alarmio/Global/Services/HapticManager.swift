//
//  HapticManager.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    func buttonTap() {
        rigidGenerator.impactOccurred()
    }

    func softTap() {
        softGenerator.impactOccurred(intensity: 0.9)
    }

    func lightTap() {
        lightGenerator.impactOccurred()
    }

    func selection() {
        selectionGenerator.selectionChanged()
    }

    func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }

    func error() {
        notificationGenerator.notificationOccurred(.error)
    }
}
