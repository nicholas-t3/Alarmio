//
//  OnboardingTimeView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct OnboardingTimeView: View {

    // MARK: - Environment

    @Environment(OnboardingManager.self) private var manager
    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - State

    @State private var contentVisible = false
    @State private var wakeHour = 7
    @State private var wakeMinute = 0
    @State private var includeLeaveTime = false
    @State private var leaveHour = 8
    @State private var leaveMinute = 0

    // MARK: - Constants

    let onReadyForButton: () -> Void

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                Spacer()
                    .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale))

                // Header
                Text("When should we\nwake you up?")
                    .font(AppTypography.headlineLarge)
                    .tracking(AppTypography.headlineLargeTracking)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .premiumBlur(isVisible: contentVisible, duration: 0.4)

                Spacer()
                    .frame(height: AppSpacing.sectionGap(deviceInfo.spacingScale))

                // Wake time picker
                timePickerCard(
                    label: "WAKE UP",
                    hour: $wakeHour,
                    minute: $wakeMinute,
                    index: 0
                )
                .padding(.horizontal, AppSpacing.screenHorizontal)

                Spacer()
                    .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale) * 1.5)

                // Leave time toggle + picker
                VStack(spacing: AppSpacing.itemGap(deviceInfo.spacingScale)) {

                    // Toggle
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            includeLeaveTime.toggle()
                            syncTimes()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: includeLeaveTime ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(includeLeaveTime ? 0.9 : 0.3))
                                .symbolEffect(.bounce.down.byLayer, value: includeLeaveTime)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("I have a time to leave")
                                    .font(AppTypography.labelLarge)
                                    .foregroundStyle(.white.opacity(includeLeaveTime ? 1 : 0.5))

                                Text("Your alarm will remind you how much time you have")
                                    .font(AppTypography.labelSmall)
                                    .foregroundStyle(.white.opacity(0.3))
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .blur(radius: contentVisible ? 0 : 8)
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.15), value: contentVisible)

                    // Leave time picker (conditional)
                    if includeLeaveTime {
                        timePickerCard(
                            label: "LEAVE BY",
                            hour: $leaveHour,
                            minute: $leaveMinute,
                            index: 1
                        )
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }

                Spacer()
                    .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale))
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            contentVisible = true
            syncTimes()

            try? await Task.sleep(for: .milliseconds(500))
            onReadyForButton()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func timePickerCard(label: String, hour: Binding<Int>, minute: Binding<Int>, index: Int) -> some View {
        VStack(spacing: 12) {

            // Label
            Text(label)
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Time display
            HStack(spacing: 4) {

                // Hour
                timeWheel(value: hour, range: 0...23)

                // Colon
                Text(":")
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .offset(y: -2)

                // Minute
                timeWheel(value: minute, range: 0...59, step: 5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .blur(radius: contentVisible ? 0 : 8)
        .opacity(contentVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.08), value: contentVisible)
    }

    @ViewBuilder
    private func timeWheel(value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1) -> some View {
        let values = stride(from: range.lowerBound, through: range.upperBound, by: step).map { $0 }

        Picker("", selection: value) {
            ForEach(values, id: \.self) { v in
                Text(String(format: "%02d", v))
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .tag(v)
            }
        }
        .pickerStyle(.wheel)
        .frame(width: 80, height: 120)
        .clipped()
        .onChange(of: value.wrappedValue) {
            HapticManager.shared.selection()
            syncTimes()
        }
    }

    // MARK: - Private Methods

    private func syncTimes() {
        var calendar = Calendar.current
        calendar.timeZone = .current

        var wakeComponents = DateComponents()
        wakeComponents.hour = wakeHour
        wakeComponents.minute = wakeMinute
        if let date = calendar.date(from: wakeComponents) {
            manager.setWakeTime(date)
        }

        if includeLeaveTime {
            var leaveComponents = DateComponents()
            leaveComponents.hour = leaveHour
            leaveComponents.minute = leaveMinute
            if let date = calendar.date(from: leaveComponents) {
                manager.setLeaveTime(date)
            }
        } else {
            manager.setLeaveTime(nil)
        }
    }
}

#Preview {
    OnboardingContainerView.preview(step: .time)
}
