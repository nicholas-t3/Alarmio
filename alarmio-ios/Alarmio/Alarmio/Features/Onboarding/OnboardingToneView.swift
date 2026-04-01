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

    // MARK: - State

    @State private var contentVisible = false

    // MARK: - Constants

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
        VStack(spacing: 0) {

            Spacer()
                .frame(height: AppSpacing.screenTopInset)

            // Header
            Text("What gets you\nout of bed?")
                .font(AppTypography.headlineLarge)
                .tracking(AppTypography.headlineLargeTracking)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .premiumBlur(isVisible: contentVisible, duration: 0.4)

            Spacer()
                .frame(height: AppSpacing.sectionGap)

            // Tone options — staggered entry
            VStack(spacing: 4) {
                ForEach(Array(tones.enumerated()), id: \.element.0) { index, tone in
                    toneRow(tone: tone.0, name: tone.1, icon: tone.2, index: index)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)

            Spacer()

            // Continue button
            Button {
                manager.completeTone()
            } label: {
                Text("Continue")
            }
            .primaryButton(isEnabled: manager.configuration.tone != nil)
            .disabled(manager.configuration.tone == nil)
            .padding(.horizontal, AppButtons.horizontalPadding)
            .padding(.bottom, AppSpacing.screenBottom)
            .animation(.easeOut(duration: 0.25), value: manager.configuration.tone)
            .blur(radius: contentVisible ? 0 : 8)
            .opacity(contentVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(Double(tones.count) * 0.06 + 0.15), value: contentVisible)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            contentVisible = true
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
        } label: {
            HStack(spacing: AppSpacing.rowIconGap) {

                // Icon
                Image(systemName: icon)
                    .font(AppTypography.bodyLarge)
                    .foregroundStyle(.white.opacity(isDeselected ? 0.3 : 0.6))
                    .frame(width: AppSpacing.rowIconWidth)

                // Label
                Text(name)
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(isDeselected ? 0.4 : 1))

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(.white.opacity(0.2), lineWidth: AppSpacing.selectionStrokeWidth)
                        .frame(width: AppSpacing.selectionCircleSize, height: AppSpacing.selectionCircleSize)
                        .opacity(isSelected ? 0 : 1)

                    Circle()
                        .fill(.white)
                        .frame(width: AppSpacing.selectionCircleSize, height: AppSpacing.selectionCircleSize)
                        .opacity(isSelected ? 1 : 0)
                        .scaleEffect(isSelected ? 1 : 0.5)

                    Image(systemName: "checkmark")
                        .font(.system(size: AppSpacing.selectionCheckmarkSize, weight: .bold))
                        .foregroundStyle(.black)
                        .opacity(isSelected ? 1 : 0)
                        .scaleEffect(isSelected ? 1 : 0.3)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
            }
            .padding(.horizontal, AppSpacing.rowHorizontal)
            .padding(.vertical, AppSpacing.rowVertical)
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
    ZStack {
        NightSkyBackground()
        OnboardingToneView()
            .environment(OnboardingManager())
    }
}

#Preview("With Selection") {
    let manager = OnboardingManager()

    ZStack {
        NightSkyBackground()
        OnboardingToneView()
            .environment(manager)
    }
    .onAppear {
        manager.configuration.tone = .calm
    }
}
