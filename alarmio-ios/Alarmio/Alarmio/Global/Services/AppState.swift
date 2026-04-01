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

    // MARK: - State

    var hasCompletedOnboarding = false
    var isLoading = true

    // MARK: - Lifecycle

    func checkOnboardingStatus() async {
        // TODO: Check Supabase for user onboarding completion
        // For now, read from UserDefaults
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        isLoading = false
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        hasCompletedOnboarding = true
    }

    /// For development: reset onboarding
    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        hasCompletedOnboarding = false
    }
}
