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
    @State private var alarmStore: AlarmStore
    @State private var composerService: ComposerService

    // MARK: - Init

    init() {
        // Share the same AudioFileManager instance with the AlarmStore so
        // files ComposerService writes are visible to AlarmScheduler.
        let store = AlarmStore.create()
        _alarmStore = State(initialValue: store)
        _composerService = State(initialValue: ComposerService(audioFileManager: store.audioFileManager))
    }

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
        .environment(\.composerService, composerService)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            deviceInfo.updateScreenSize(width: size.width, height: size.height)
        }
        .task {
            // Local-first boot: alarms live in the App Group defaults and
            // must render even with no network. Auth and reschedule run in
            // the background so a dead connection can never block the UI.
            alarmStore.audioFileManager.ensureSetup()
            alarmStore.load()
            await appState.checkOnboardingStatus()

            Task {
                do {
                    try await APIClient.shared.ensureSession()
                } catch {
                    print("[RootView] Auth failed: \(error)")
                }
            }
            Task { await alarmStore.rescheduleAllEnabled() }
            Task { await alarmStore.startObserving() }
        }
    }
}

#Preview {
    RootView()
}
