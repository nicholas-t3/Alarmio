//
//  OnboardingVoiceView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct OnboardingVoiceViewOld: View {

    // MARK: - Environment

    @Environment(OnboardingManager.self) private var manager
    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - State

    @State private var contentVisible = false
    @State private var iconTriggers = Array(repeating: 0, count: 5)

    // MARK: - Constants

    let onReadyForButton: () -> Void

    private let options: [(VoicePersona, String, String)] = [
        (.calmGuide, "Calm Guide", "person.and.background.dotted"),
        (.energeticCoach, "Energetic Coach", "figure.run"),
        (.hardSergeant, "Hard Sergeant", "shield.fill"),
        (.evilSpaceLord, "Evil Space Lord", "sparkles"),
        (.playful, "Playful", "theatermask.and.paintbrush.fill")
    ]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                Spacer()
                    .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale))

                // Header
                Text("What kind\nof voice?")
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
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
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
    private func optionRow(value: VoicePersona, name: String, icon: String, index: Int) -> some View {
        let isSelected = manager.configuration.voicePersona == value
        let hasSelection = manager.configuration.voicePersona != nil
        let isDeselected = hasSelection && !isSelected

        Button {
            manager.selectVoice(value)
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
        .animation(.easeOut(duration: 0.3), value: manager.configuration.voicePersona)
        .blur(radius: contentVisible ? 0 : 8)
        .opacity(contentVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.06), value: contentVisible)
    }
}

#Preview {
    OnboardingContainerView.preview(step: .voice)
}
