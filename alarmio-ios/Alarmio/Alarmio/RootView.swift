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
    @State private var deviceInfo = DeviceInfo()

    // MARK: - Body

    var body: some View {
        ZStack {

            // Onboarding
            OnboardingContainerView()

            // Global alert overlay — always on top
            GlobalAlertOverlay()
        }
        .environment(appState)
        .environment(\.alertManager, alertManager)
        .environment(\.deviceInfo, deviceInfo)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            deviceInfo.updateScreenSize(width: size.width, height: size.height)
        }
        .task {
            await appState.checkOnboardingStatus()
        }
    }
}

#Preview {
    RootView()
}
