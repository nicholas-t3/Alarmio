//
//  OnboardingSnoozeView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct OnboardingSnoozeView: View {

    // MARK: - Environment

    @Environment(OnboardingManager.self) private var manager
    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - State

    @State private var contentVisible = false
    @State private var snoozeCount: Double = 0
    @State private var snoozeInterval: Double = 5

    private var hasSnooze: Bool { Int(snoozeCount) > 0 }

    // MARK: - Constants

    let onReadyForButton: () -> Void

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                Spacer()
                    .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale))

                // Header
                Text("How should\nsnooze work?")
                    .font(AppTypography.headlineLarge)
                    .tracking(AppTypography.headlineLargeTracking)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .premiumBlur(isVisible: contentVisible, duration: 0.4)

                Spacer()
                    .frame(height: AppSpacing.sectionGap(deviceInfo.spacingScale))

                // Snooze count
                sliderCard(
                    label: "SNOOZE LIMIT",
                    showLabel: hasSnooze,
                    description: hasSnooze ? "How many times you can snooze" : "Snooze is disabled",
                    value: $snoozeCount,
                    range: 0...5,
                    step: 1,
                    displayValue: Int(snoozeCount) == 0 ? "Off" : "\(Int(snoozeCount))",
                    displayUnit: Int(snoozeCount) == 0 ? "" : (Int(snoozeCount) == 1 ? "time" : "times"),
                    index: 0
                )
                .padding(.horizontal, AppSpacing.screenHorizontal)

                Spacer()
                    .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale) * 1.5)

                // Snooze interval — only visible when count > 0
                if hasSnooze {
                    sliderCard(
                        label: "SNOOZE DURATION",
                        showLabel: true,
                        description: "Time between each snooze",
                        value: $snoozeInterval,
                        range: 1...15,
                        step: 1,
                        displayValue: "\(Int(snoozeInterval))",
                        displayUnit: Int(snoozeInterval) == 1 ? "minute" : "minutes",
                        index: 1
                    )
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }

                Spacer()
                    .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale))
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: hasSnooze)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            contentVisible = true

            try? await Task.sleep(for: .milliseconds(500))
            onReadyForButton()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func sliderCard(
        label: String,
        showLabel: Bool,
        description: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        displayValue: String,
        displayUnit: String,
        index: Int
    ) -> some View {
        VStack(spacing: 16) {

            // Label
            Text(label)
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))
                .premiumBlur(isVisible: showLabel, duration: 0.3)

            // Value display
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(displayValue)
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: displayValue)

                if !displayUnit.isEmpty {
                    Text(displayUnit)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(.white.opacity(0.4))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: displayUnit)
                }
            }

            // Description
            Text(description)
                .font(AppTypography.labelSmall)
                .foregroundStyle(.white.opacity(0.3))

            // Slider
            Slider(value: value, in: range, step: step)
                .tint(.white)
                .padding(.horizontal, 8)
                .onChange(of: value.wrappedValue) {
                    HapticManager.shared.selection()
                    manager.setSnoozeCount(Int(snoozeCount))
                    manager.setSnoozeInterval(Int(snoozeInterval))
                }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
        .blur(radius: contentVisible ? 0 : 8)
        .opacity(contentVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.1), value: contentVisible)
    }
}

#Preview {
    OnboardingContainerView.preview(step: .snooze)
}
