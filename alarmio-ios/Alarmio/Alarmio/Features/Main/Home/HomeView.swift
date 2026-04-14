//
//  HomeView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct HomeView: View {

    // MARK: - Environment

    @Environment(AppState.self) private var appState
    @Environment(\.deviceInfo) private var deviceInfo
    @Environment(\.alarmStore) private var alarmStore

    // MARK: - State

    @State private var contentVisible = false
    @State private var alarmsVisible = false
    @State private var fabVisible = false
    @State private var glowPulse = false
    @State private var showCreateAlarm = false
    @State private var showSettings = false
    @State private var editingAlarmId: UUID?
    @State private var showEditModal = false
    @State private var editBlurVisible = false
    @State private var deletingAlarmIds: Set<UUID> = []
    @State private var emptyStateOpacity: Double = 0

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

            // Blur overlay for edit modal
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(editBlurVisible ? 0.7 : 0)
                .animation(.easeOut(duration: 0.3), value: editBlurVisible)
                .allowsHitTesting(false)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            contentVisible = true
            try? await Task.sleep(for: .milliseconds(400))
            fabVisible = true
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
                        Task {
                            try? await Task.sleep(for: .milliseconds(500))
                            deletingAlarmIds.insert(id)
                            try? await Task.sleep(for: .milliseconds(400))
                            _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                Task { await alarmStore.deleteAlarm(id: id) }
                            }
                            try? await Task.sleep(for: .milliseconds(400))
                            deletingAlarmIds.remove(id)
                        }
                    }
                )
            }
        }
        .onChange(of: showEditModal) { _, showing in
            editBlurVisible = showing
            if !showing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    editingAlarmId = nil
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
            ScrollView {
                VStack(spacing: AppSpacing.itemGap(deviceInfo.spacingScale)) {

                    // Top spacer
                    Spacer()
                        .frame(height: 4)

                    // Alarm cards
                    ForEach(Array(alarmStore.alarms.enumerated()), id: \.element.id) { index, alarm in
                        AlarmCardView(
                            alarm: alarm,
                            onToggle: {
                                Task { await alarmStore.toggleAlarm(id: alarm.id) }
                            },
                            onEdit: {
                                HapticManager.shared.softTap()
                                editingAlarmId = alarm.id
                                showEditModal = true
                            }
                        )
                        .premiumBlur(
                        isVisible: alarmsVisible && !deletingAlarmIds.contains(alarm.id),
                        delay: deletingAlarmIds.contains(alarm.id) ? 0 : Double(index) * 0.08 + 0.1,
                        duration: 0.4
                    )
                    .transition(.opacity)
                    }

                    // Bottom spacer to clear FAB
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
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
