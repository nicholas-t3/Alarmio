//
//  OnboardingIntensityView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct OnboardingIntensityView: View {

    // MARK: - Environment

    @Environment(OnboardingManager.self) private var manager
    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - State

    @State private var contentVisible = false
    @State private var iconTriggers = Array(repeating: 0, count: 3)

    // MARK: - Constants

    let onReadyForButton: () -> Void

    private let options: [(AlarmIntensity, String, String)] = [
        (.gentle, "Gentle", "wind"),
        (.balanced, "Balanced", "equal.circle.fill"),
        (.intense, "Intense", "flame.fill")
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            Spacer()
                .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale))

            // Header
            Text("How intense\nshould we be?")
                .font(AppTypography.headlineLarge)
                .tracking(AppTypography.headlineLargeTracking)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .premiumBlur(isVisible: contentVisible, duration: 0.4)

            Spacer()
                .frame(height: AppSpacing.sectionGap(deviceInfo.spacingScale))

            // Options
            VStack(spacing: 4) {
                ForEach(Array(options.enumerated()), id: \.element.0) { index, option in
                    optionRow(value: option.0, name: option.1, icon: option.2, index: index)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)

            Spacer()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            contentVisible = true

            let lastRowStart = Double(options.count - 1) * 0.06 + 0.15
            try? await Task.sleep(for: .seconds(lastRowStart))
            onReadyForButton()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func optionRow(value: AlarmIntensity, name: String, icon: String, index: Int) -> some View {
        let isSelected = manager.configuration.intensity == value
        let hasSelection = manager.configuration.intensity != nil
        let isDeselected = hasSelection && !isSelected

        Button {
            manager.selectIntensity(value)
            iconTriggers[index] += 1
        } label: {
            HStack(spacing: AppSpacing.rowIconGap) {

                // Icon
                Image(systemName: icon)
                    .font(AppTypography.bodyLarge)
                    .symbolEffect(.bounce.down.byLayer, value: iconTriggers[index])
                    .foregroundStyle(.white.opacity(isDeselected ? 0.3 : 0.6))
                    .frame(width: AppSpacing.rowIconWidth)

                // Label
                Text(name)
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(isDeselected ? 0.4 : 1))

                Spacer()

                // Selection indicator
                SelectionCircle(isSelected: isSelected)
            }
            .padding(.horizontal, AppSpacing.rowHorizontal)
            .padding(.vertical, AppSpacing.rowVertical(deviceInfo.spacingScale))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isDeselected ? 0.6 : 1)
        .blur(radius: isDeselected ? 1.5 : 0)
        .animation(.easeOut(duration: 0.3), value: manager.configuration.intensity)
        .blur(radius: contentVisible ? 0 : 8)
        .opacity(contentVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.06), value: contentVisible)
    }
}

#Preview {
    OnboardingContainerView.preview(step: .intensity)
}
