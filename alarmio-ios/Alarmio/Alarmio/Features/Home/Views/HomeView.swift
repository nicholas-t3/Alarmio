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

    // MARK: - State

    @State private var viewModel = HomeViewModel()
    @State private var contentVisible = false
    @State private var fabVisible = false
    @State private var glowPulse = false

    // MARK: - Body

    var body: some View {
        ZStack {

            // Background
            MorningSky(starOpacity: 0.8, showConstellations: false)

            // Main content
            VStack(spacing: 0) {

                // Header
                headerBar
                    .premiumBlur(isVisible: contentVisible, delay: 0, duration: 0.4)

                // Alarm list or empty state
                if viewModel.alarms.isEmpty {
                    emptyState
                        .premiumBlur(isVisible: contentVisible, delay: 0.1, duration: 0.4)
                } else {
                    alarmList
                }
            }

            // Floating add button
            addButton
                .premiumBlur(isVisible: fabVisible, delay: 0, duration: 0.3)
        }
        .task {
            viewModel.loadAlarms()
            try? await Task.sleep(for: .milliseconds(100))
            contentVisible = true
            try? await Task.sleep(for: .milliseconds(400))
            fabVisible = true
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
                    .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale))

                // Alarm cards
                ForEach(Array(viewModel.alarms.enumerated()), id: \.element.id) { index, _ in
                    AlarmCardView(
                        alarm: $viewModel.alarms[index],
                        onToggle: {},
                        onEdit: {}
                    )
                    .premiumBlur(isVisible: contentVisible, delay: Double(index) * 0.08 + 0.1, duration: 0.4)
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

    private var emptyState: some View {
        VStack(spacing: AppSpacing.titleSubtitleGap) {

            Spacer()

            Image(systemName: "alarm")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.2))

            Text("No alarms yet")
                .font(AppTypography.bodyLarge)
                .foregroundStyle(.white.opacity(0.4))

            Text("Tap + to create your first alarm")
                .captionStyle()

            Spacer()
        }
    }

    private var addButton: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button {
                    HapticManager.shared.buttonTap()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .glassEffect(.clear, in: Circle())
                        .shadow(color: .white.opacity(0.1), radius: 16, y: 4)
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
