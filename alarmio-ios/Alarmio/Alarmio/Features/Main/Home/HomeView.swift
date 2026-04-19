//
//  HomeView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import AlarmKit
import StoreKit
import SwiftUI
import UIKit

struct HomeView: View {

    // MARK: - Environment

    @Environment(AppState.self) private var appState
    @Environment(\.deviceInfo) private var deviceInfo
    @Environment(\.alarmStore) private var alarmStore
    @Environment(\.alertManager) private var alertManager
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - State

    @State private var contentVisible = false
    @State private var alarmsVisible = false
    @State private var fabVisible = false
    @State private var glowPulse = false
    /// One-shot guard — set the first time the post-onboarding review
    /// prompt fires so we never ask again on this install. Apple also
    /// rate-limits requestReview to 3 per 365 days regardless.
    @AppStorage("hasRequestedPostOnboardingReview") private var hasRequestedPostOnboardingReview = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showCreateAlarm = false
    @State private var showSettings = false
    @State private var editingAlarmId: UUID?
    @State private var showEditModal = false
    @State private var emptyStateOpacity: Double = 0
    /// Single shared player for the home-screen alarm preview taps.
    /// Tracked alongside `playingAlarmId` so only one alarm can preview
    /// at a time — tapping Play on alarm B automatically stops alarm A.
    @State private var homePreviewPlayer = VoicePreviewPlayer()
    @State private var playingAlarmId: UUID?

    // MARK: - Body

    var body: some View {
        ZStack {

            // Background
            MorningSky(starOpacity: 0.8, showConstellations: false, shootingStarFrequency: .frequent)

            // Main content
            VStack(spacing: 0) {

                // Header
                headerBar
                    .premiumBlur(isVisible: contentVisible, delay: 0, duration: 0.4)

                // Alarm list
                alarmList
            }

            // Floating add button
            addButton
                .premiumBlur(isVisible: fabVisible, delay: 0, duration: 0.3)

        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            contentVisible = true
            try? await Task.sleep(for: .milliseconds(400))
            fabVisible = true

            // Fire the native rating prompt once, the first time HomeView
            // appears after onboarding has completed. Gated on an
            // @AppStorage flag so we never ask a second time even if the
            // user backgrounds and returns.
            if hasCompletedOnboarding, !hasRequestedPostOnboardingReview {
                hasRequestedPostOnboardingReview = true
                try? await Task.sleep(for: .milliseconds(800))
                requestAppReview()
            }
        }
        .onChange(of: alarmStore.alarms.isEmpty) { _, isEmpty in
            // Trigger card animation once alarms first populate (load is async
            // from RootView). Without this, alarms snap in because contentVisible
            // is already true by the time they arrive from the store.
            if !isEmpty && !alarmsVisible {
                Task {
                    try? await Task.sleep(for: .milliseconds(50))
                    alarmsVisible = true
                }
            }

            // When the list transitions from non-empty → empty, reset the
            // empty state's visibility flag so its next mount starts hidden.
            // The empty view itself flips the flag to true in its onAppear,
            // which drives the blur-in.
            if isEmpty {
                emptyStateOpacity = 0
            }
        }
        .onAppear {
            if !alarmStore.alarms.isEmpty && !alarmsVisible {
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    alarmsVisible = true
                }
            }
        }
        .fullScreenCover(isPresented: $showCreateAlarm) {
            CreateAlarmView { newAlarm in
                Task { await alarmStore.addAlarm(newAlarm) }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "0f1a2e"))
        }
        .sheet(isPresented: $showEditModal) {
            if let alarmId = editingAlarmId, let alarm = alarmStore.alarm(for: alarmId) {
                EditAlarmSheetContent(
                    alarm: alarm,
                    onSave: { updatedAlarm in
                        Task { await alarmStore.updateAlarm(updatedAlarm) }
                        showEditModal = false
                    },
                    onDelete: {
                        let id = alarmId
                        showEditModal = false
                        deleteAlarm(id: id)
                    }
                )
            }
        }
        .onChange(of: showEditModal) { _, showing in
            if !showing {
                editingAlarmId = nil
            }
        }
        // Detect a Settings round-trip that revoked AlarmKit authorization
        // while the app was backgrounded. Flip every scheduled alarm off to
        // match reality, then surface the modal so the user sees why.
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            if AlarmManager.shared.authorizationState == .denied {
                if alarmStore.handlePermissionRevoked() {
                    showAlarmsDisabledModal()
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerBar: some View {
        HStack {

            // Logo with glow layers (matches splash pattern)
            ZStack {
                Text("alarmio")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "3A6EAA").opacity(glowPulse ? 0.5 : 0.3))
                    .blur(radius: 6)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: glowPulse)

                Text("alarmio")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "2A5A9A").opacity(0.7))
                    .offset(x: -0.8)

                Text("alarmio")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "2A5A9A").opacity(0.7))
                    .offset(x: 0.8)

                Text("alarmio")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .onAppear {
                glowPulse = true
            }

            Spacer()

            // Settings
            Button {
                HapticManager.shared.buttonTap()
                showSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 1.0).onEnded { _ in
                    appState.resetOnboarding()
                }
            )
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var alarmList: some View {
        if alarmStore.alarms.isEmpty {
            emptyState
        } else {
            List {

                // Top spacer
                Color.clear
                    .frame(height: 4)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())

                // Alarm cards — enabled alarms first (by time), then disabled (by time)
                ForEach(sortedAlarms, id: \.id) { alarm in
                    AlarmCardView(
                        alarm: alarm,
                        isPlayingThis: playingAlarmId == alarm.id && homePreviewPlayer.isPlaying,
                        onToggle: {
                            // Only enforce auth when flipping OFF→ON. Turning
                            // an alarm off doesn't require permission.
                            let turningOn = !alarm.isEnabled
                            if turningOn, AlarmManager.shared.authorizationState == .denied {
                                showAlarmsDisabledModal()
                                return
                            }
                            Task { await alarmStore.toggleAlarm(id: alarm.id) }
                        },
                        onEdit: {
                            editingAlarmId = alarm.id
                            showEditModal = true
                        },
                        onTogglePlay: { toggleHomePreview(for: alarm) }
                    )
                    .premiumBlur(
                        isVisible: alarmsVisible,
                        delay: Double(sortedAlarms.firstIndex(where: { $0.id == alarm.id }) ?? 0) * 0.08 + 0.1,
                        duration: 0.4
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: AppSpacing.itemGap(deviceInfo.spacingScale) / 2,
                        leading: AppSpacing.screenHorizontal,
                        bottom: AppSpacing.itemGap(deviceInfo.spacingScale) / 2,
                        trailing: AppSpacing.screenHorizontal
                    ))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteAlarm(id: alarm.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                // Bottom spacer to clear FAB
                Color.clear
                    .frame(height: 100)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
            .listSectionSpacing(0)
            .environment(\.defaultMinListHeaderHeight, 0)
            .contentMargins(.top, -40, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: sortedAlarms.map(\.id))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {

            Spacer()

            // Icon
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.04))
                        .frame(width: 96, height: 96)

                    Image(systemName: "alarm.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white.opacity(0.25))
                }

                // Headline + subtitle (kept tight; icon stays 16pt from headline)
                VStack(spacing: 6) {
                    Text("No alarms yet")
                        .font(AppTypography.headlineLarge)
                        .tracking(AppTypography.headlineLargeTracking)
                        .foregroundStyle(.white.opacity(0.7))

                    Text("Tap + to create your first\npersonalized wake-up call")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .opacity(emptyStateOpacity)
        .onAppear {
            emptyStateOpacity = 0
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.easeOut(duration: 0.6)) {
                    emptyStateOpacity = 1
                }
            }
        }
    }

    private var addButton: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button {
                    HapticManager.shared.buttonTap()
                    if AlarmManager.shared.authorizationState == .denied {
                        showAlarmsDisabledModal()
                        return
                    }
                    showCreateAlarm = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .glassEffect(.clear, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
            }
            .padding(.trailing, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.screenBottom)
        }
    }

    // MARK: - Private Methods

    // Enabled alarms first, then disabled. Within each group, earliest time-of-day first.
    private var sortedAlarms: [AlarmConfiguration] {
        alarmStore.alarms.sorted { lhs, rhs in
            if lhs.isEnabled != rhs.isEnabled { return lhs.isEnabled }
            return minutesOfDay(lhs.wakeTime) < minutesOfDay(rhs.wakeTime)
        }
    }

    private func minutesOfDay(_ date: Date?) -> Int {
        guard let date else { return .max }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    /// Present Apple's native rating prompt. iOS silently throttles this
    /// to 3 requests per 365 days per user, and may choose not to show it
    /// at all based on its own heuristics — both are expected.
    private func requestAppReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }
        AppStore.requestReview(in: scene)
    }

    private func showAlarmsDisabledModal() {
        HapticManager.shared.warning()
        alertManager.showModal(
            title: "Alarms are off",
            message: "Alarmio can't ring until you turn alarms back on for this app in Settings.",
            dismissible: true,
            primaryAction: AlertAction(label: "Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            },
            secondaryAction: AlertAction(label: "Not Now") {}
        )
    }

    private func deleteAlarm(id: UUID) {
        Task { await alarmStore.deleteAlarm(id: id) }
    }

    /// Shared home-preview toggle — tapping Play on another alarm while
    /// one is already playing stops the previous and starts the new one.
    /// Tapping Play on the currently-playing alarm stops it.
    private func toggleHomePreview(for alarm: AlarmConfiguration) {
        let isThisPlaying = playingAlarmId == alarm.id && homePreviewPlayer.isPlaying

        // Stop whatever is currently playing.
        homePreviewPlayer.stop()

        if isThisPlaying {
            playingAlarmId = nil
            return
        }

        guard let fileName = alarm.soundFileName else { return }
        let url = alarmStore.audioFileManager.soundFileURL(named: fileName)
        homePreviewPlayer.playFromFile(url: url, persona: alarm.voicePersona)
        playingAlarmId = alarm.id
    }
}

// MARK: - Previews

#Preview("With Alarms") {
    HomeView()
        .environment(AppState())
}

#Preview("Empty State") {
    HomeView()
        .environment(AppState())
}
