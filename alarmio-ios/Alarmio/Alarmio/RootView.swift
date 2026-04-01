//
//  RootView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct RootView: View {

    // MARK: - State

    @State private var appState = AppState()
    @State private var alertManager = AlertManager()

    // MARK: - Body

    var body: some View {
        ZStack {
//            if appState.isLoading {
//                // Brief loading while checking status
//                Color(hex: "020810")
//                    .ignoresSafeArea()
//            } else if appState.hasCompletedOnboarding {
//                // Main app
//                HomeView()
//            } else {
//                // Onboarding
//                OnboardingContainerView()
//            }
            OnboardingContainerView()

            // Global alert overlay — always on top
            GlobalAlertOverlay()
        }
        .environment(appState)
        .environment(\.alertManager, alertManager)
        .task {
            await appState.checkOnboardingStatus()
        }
    }
}

// MARK: - Placeholder Home

struct HomeView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            NightSkyBackground()

            VStack(spacing: 24) {
                Text("alarmio")
                    .font(AppTypography.logo)
                    .foregroundStyle(.white)

                Text("No alarms yet")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(.white.opacity(0.4))

                // Dev: reset onboarding
                Button {
                    appState.resetOnboarding()
                } label: {
                    Text("Reset Onboarding (Dev)")
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
    }
}

#Preview {
    RootView()
}
