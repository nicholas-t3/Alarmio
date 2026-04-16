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
    @State private var snoozeCount: Int = 2
    @State private var snoozeInterval: Int = 5

    // MARK: - Constants

    let onReadyForButton: () -> Void

    private let minCount: Int = 0
    private let maxCount: Int = 5
    private let minInterval: Int = 1
    private let maxInterval: Int = 15

    private var showsInterval: Bool { snoozeCount > 0 }

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

                // Single hero card — count is the primary display, duration
                // collapses in/out as a secondary row when count > 0.
                snoozeHeroCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: contentVisible, delay: 0.1, duration: 0.4)

                Spacer()
                    .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale))
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .task {
            // Seed the manager so .canContinue is satisfied and the user
            // sees a real default if they tap Continue immediately.
            manager.configuration.maxSnoozes = snoozeCount
            manager.setSnoozeInterval(snoozeInterval)

            try? await Task.sleep(for: .milliseconds(100))
            contentVisible = true

            try? await Task.sleep(for: .milliseconds(500))
            onReadyForButton()
        }
    }

    // MARK: - Subviews

    private var snoozeHeroCard: some View {
        VStack(spacing: 20) {

            // Count section — the H1 moment
            countSection

            // Divider + duration section, collapses when count == 0
            if showsInterval {
                divider
                intervalSection
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: -8)),
                            removal: .opacity.combined(with: .offset(y: -8))
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 28))
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showsInterval)
    }

    private var countSection: some View {
        VStack(spacing: 16) {

            // Label
            Text("SNOOZES")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Big value
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if snoozeCount == 0 {
                    Text("Off")
                        .font(.system(size: 50, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                } else {
                    Text("\(snoozeCount)")
                        .font(.system(size: 50, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(snoozeCount == 1 ? "time" : "times")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(.white.opacity(0.4))
                        .contentTransition(.numericText())
                }
            }
            .frame(minHeight: 54)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: snoozeCount)

            // Stepper
            stepper(
                value: snoozeCount,
                decrement: {
                    let next = max(minCount, snoozeCount - 1)
                    snoozeCount = next
                    manager.configuration.maxSnoozes = next
                },
                increment: {
                    let next = min(maxCount, snoozeCount + 1)
                    snoozeCount = next
                    manager.configuration.maxSnoozes = next
                },
                canDecrement: snoozeCount > minCount,
                canIncrement: snoozeCount < maxCount
            )
        }
    }

    private var intervalSection: some View {
        VStack(spacing: 16) {

            // Label
            Text("DURATION")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Value display — same scale as the count so they read as peers
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(snoozeInterval)")
                    .font(.system(size: 50, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(snoozeInterval == 1 ? "minute" : "minutes")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(.white.opacity(0.4))
                    .contentTransition(.numericText())
            }
            .frame(minHeight: 54)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: snoozeInterval)

            // Stepper
            stepper(
                value: snoozeInterval,
                decrement: {
                    let next = max(minInterval, snoozeInterval - 1)
                    snoozeInterval = next
                    manager.setSnoozeInterval(next)
                },
                increment: {
                    let next = min(maxInterval, snoozeInterval + 1)
                    snoozeInterval = next
                    manager.setSnoozeInterval(next)
                },
                canDecrement: snoozeInterval > minInterval,
                canIncrement: snoozeInterval < maxInterval
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, -8)
    }

    private func stepper(
        value: Int,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void,
        canDecrement: Bool,
        canIncrement: Bool
    ) -> some View {
        HStack(spacing: 20) {

            Button {
                HapticManager.shared.selection()
                decrement()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(canDecrement ? 1 : 0.3))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(canDecrement ? 0.1 : 0.04))
                    .clipShape(Circle())
            }
            .disabled(!canDecrement)

            Button {
                HapticManager.shared.selection()
                increment()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(canIncrement ? 1 : 0.3))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(canIncrement ? 0.1 : 0.04))
                    .clipShape(Circle())
            }
            .disabled(!canIncrement)
        }
    }
}

// MARK: - Previews

#Preview("Snooze Step") {
    OnboardingContainerView.preview(step: .snooze)
}

#Preview("Card (standalone)") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        OnboardingSnoozeView(onReadyForButton: {})
            .environment(OnboardingManager())
            .environment(\.deviceInfo, DeviceInfo())
    }
}
