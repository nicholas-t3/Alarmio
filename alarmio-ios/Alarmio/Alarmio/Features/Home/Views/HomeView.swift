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
    @State private var fabVisible = false
    @State private var glowPulse = false
    @State private var showCreateAlarm = false
    @State private var showSettings = false
    @State private var editingAlarmId: UUID?
    @State private var showEditModal = false

    // MARK: - Constants

    private let demoAlarms: [AlarmConfiguration] = [
        AlarmConfiguration(
            isEnabled: true,
            wakeTime: Calendar.current.date(from: DateComponents(hour: 6, minute: 30)),
            repeatDays: [1, 2, 3, 4, 5],
            tone: .calm,
            intensity: .gentle,
            voicePersona: .calmGuide,
            snoozeInterval: 5
        ),
        AlarmConfiguration(
            isEnabled: false,
            wakeTime: Calendar.current.date(from: DateComponents(hour: 9, minute: 0)),
            repeatDays: [0, 6],
            tone: .fun,
            intensity: .balanced,
            voicePersona: .playful,
            snoozeInterval: 5
        )
    ]

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
        }
        .fullScreenCover(isPresented: $showCreateAlarm) {
            CreateAlarmView { newAlarm in
                Task { await alarmStore.addAlarm(newAlarm) }
            }
        }
        .motionModal(isPresented: $showSettings) {
            SettingsView()
        }
        .motionModal(isPresented: $showEditModal) {
            if let alarmId = editingAlarmId, let alarm = alarmStore.alarm(for: alarmId) {
                EditAlarmView(
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
                            await alarmStore.deleteAlarm(id: id)
                        }
                    }
                )
            }
        }
        .onChange(of: showEditModal) { _, showing in
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

    private var alarmList: some View {
        ScrollView {
            VStack(spacing: AppSpacing.itemGap(deviceInfo.spacingScale)) {

                // Top spacer
                Spacer()
                    .frame(height: 4)

                // Real alarm cards
                if alarmStore.alarms.isEmpty {
                    emptyState
                        .premiumBlur(isVisible: contentVisible, delay: 0.1, duration: 0.4)
                } else {
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
                        .premiumBlur(isVisible: contentVisible, delay: Double(index) * 0.08 + 0.1, duration: 0.4)
                    }
                }

                // Demo separator
                demoSeparator
                    .premiumBlur(isVisible: contentVisible, delay: 0.3, duration: 0.4)

                // Demo cards
                ForEach(Array(demoAlarms.enumerated()), id: \.element.id) { index, alarm in
                    AlarmCardView(
                        alarm: alarm,
                        onToggle: {},
                        onEdit: {}
                    )
                    .premiumBlur(isVisible: contentVisible, delay: Double(index) * 0.08 + 0.4, duration: 0.4)
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

    private var demoSeparator: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
            Text("DEMO")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.25))
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.titleSubtitleGap) {
            Image(systemName: "alarm")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.15))

            Text("No alarms yet")
                .font(AppTypography.bodySmall)
                .foregroundStyle(.white.opacity(0.3))

            Text("Tap + to create your first alarm")
                .captionStyle()
        }
        .padding(.vertical, 32)
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
