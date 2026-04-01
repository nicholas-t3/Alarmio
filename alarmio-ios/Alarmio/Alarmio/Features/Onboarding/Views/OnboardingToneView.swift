//
//  OnboardingToneView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct OnboardingToneView: View {

    // MARK: - Environment

    @Environment(OnboardingManager.self) private var manager
    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - State

    @State private var contentVisible = false
    @State private var iconTriggers = Array(repeating: 0, count: 6)

    // MARK: - Constants

    let onReadyForButton: () -> Void

    private let tones: [(AlarmTone, String, String)] = [
        (.calm, "Calm", "leaf.fill"),
        (.encourage, "Encourage", "hand.thumbsup.fill"),
        (.push, "Push", "bolt.fill"),
        (.strict, "Strict", "exclamationmark.triangle.fill"),
        (.fun, "Fun", "face.smiling.fill"),
        (.other, "Other", "ellipsis.circle.fill")
    ]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                Spacer()
                    .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale))

                // Header
                Text("What gets you\nout of bed?")
                    .font(AppTypography.headlineLarge)
                    .tracking(AppTypography.headlineLargeTracking)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .premiumBlur(isVisible: contentVisible, duration: 0.4)

                Spacer()
                    .frame(height: AppSpacing.sectionGap(deviceInfo.spacingScale))

                // Tone options — staggered entry
                VStack(spacing: 4) {
                    ForEach(Array(tones.enumerated()), id: \.element.0) { index, tone in
                        toneRow(tone: tone.0, name: tone.1, icon: tone.2, index: index)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            contentVisible = true

            // Button appears right after the last row starts animating in
            let lastRowStart = Double(tones.count - 1) * 0.06 + 0.15
            try? await Task.sleep(for: .seconds(lastRowStart))
            onReadyForButton()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func toneRow(tone: AlarmTone, name: String, icon: String, index: Int) -> some View {
        let isSelected = manager.configuration.tone == tone
        let hasSelection = manager.configuration.tone != nil
        let isDeselected = hasSelection && !isSelected

        Button {
            manager.selectTone(tone)
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
        .animation(.easeOut(duration: 0.3), value: manager.configuration.tone)
        // Staggered entry
        .blur(radius: contentVisible ? 0 : 8)
        .opacity(contentVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.06), value: contentVisible)
    }
}

#Preview {
    OnboardingContainerView.preview(step: .tone)
}
