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

    // Read synchronously on first render so we never flash a loading state
    // while UserDefaults is consulted. AppState.completeOnboarding() writes
    // to the same key, which updates this view automatically.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var appState = AppState()
    @State private var alertManager = AlertManager()
    @State private var deviceInfo = DeviceInfo()
    @State private var alarmStore: AlarmStore
    @State private var composerService: ComposerService
    @State private var subscriptionService = SubscriptionService()

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

            // Root branch — @AppStorage reads synchronously so the correct
            // view mounts on first frame, no black-screen flicker.
            if hasCompletedOnboarding {
                HomeView()
                    .transition(.premiumBlur)
            } else {
                OnboardingContainerView()
                    .transition(.premiumBlur)
            }

            // Global alert overlay — always on top
            GlobalAlertOverlay()
        }
        .animation(.easeInOut(duration: 0.6), value: hasCompletedOnboarding)
        .environment(appState)
        .environment(\.alertManager, alertManager)
        .environment(\.deviceInfo, deviceInfo)
        .environment(\.alarmStore, alarmStore)
        .environment(\.composerService, composerService)
        .environment(\.subscriptionService, subscriptionService)
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
            subscriptionService.configure()

            Task {
                do {
                    try await APIClient.shared.ensureSession()
                    if let userId = SupabaseClient.shared.currentUserId {
                        await subscriptionService.identify(userId: userId.uuidString)
                    }
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
