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
    @State private var alarmStore = AlarmStore.create()

    // MARK: - Body

    var body: some View {
        ZStack {

            // Onboarding
            //OnboardingContainerView()
            
            HomeView()

            // Global alert overlay — always on top
            GlobalAlertOverlay()
        }
        .environment(appState)
        .environment(\.alertManager, alertManager)
        .environment(\.deviceInfo, deviceInfo)
        .environment(\.alarmStore, alarmStore)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            deviceInfo.updateScreenSize(width: size.width, height: size.height)
        }
        .task {
            alarmStore.audioFileManager.ensureSetup()
            alarmStore.load()
            await appState.checkOnboardingStatus()
            await alarmStore.rescheduleAllEnabled()
            Task { await alarmStore.startObserving() }
        }
    }
}

#Preview {
    RootView()
}
