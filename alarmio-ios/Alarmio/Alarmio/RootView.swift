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
            // Anonymous Supabase auth — runs before anything else so the
            // rest of the app boots into an authenticated state. If it
            // fails we continue anyway; the Composer call will surface a
            // clearer error to the user later.
            do {
                try await SupabaseClient.shared.ensureAuthenticated()
            } catch {
                print("[RootView] Supabase auth failed: \(error)")
            }
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
