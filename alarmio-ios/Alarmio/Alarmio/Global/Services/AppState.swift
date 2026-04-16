//
//  AppState.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

@Observable
@MainActor
final class AppState {

    // MARK: - Lifecycle

    /// Persist onboarding completion. RootView reads the same UserDefaults
    /// key via @AppStorage, so the branch updates automatically.
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    /// For development: reset onboarding.
    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
}
