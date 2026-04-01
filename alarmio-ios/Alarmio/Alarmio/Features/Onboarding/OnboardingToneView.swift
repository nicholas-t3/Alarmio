//
//  OnboardingToneView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct OnboardingToneView: View {

    // MARK: - State

    @Binding var selectedTone: String?
    @State private var contentVisible = false

    // MARK: - Constants

    let onContinue: () -> Void

    private let tones = [
        ("Calm", "leaf.fill"),
        ("Encourage", "hand.thumbsup.fill"),
        ("Push", "bolt.fill"),
        ("Strict", "exclamationmark.triangle.fill"),
        ("Fun", "face.smiling.fill"),
        ("Other", "ellipsis.circle.fill")
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
                    toneRow(name: tone.0, icon: tone.1, index: index)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)

            Spacer()

            // Continue button
            Button {
                HapticManager.shared.buttonTap()
                onContinue()
            } label: {
                Text("Continue")
            }
            .primaryButton(isEnabled: selectedTone != nil)
            .disabled(selectedTone == nil)
            .padding(.horizontal, AppButtons.horizontalPadding)
            .padding(.bottom, AppSpacing.screenBottom)
            .animation(.easeOut(duration: 0.25), value: selectedTone)
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
    private func toneRow(name: String, icon: String, index: Int) -> some View {
        let isSelected = selectedTone == name
        let hasSelection = selectedTone != nil
        let isDeselected = hasSelection && !isSelected

        Button {
            HapticManager.shared.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTone = name
            }
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
                    // Empty circle
                    Circle()
                        .strokeBorder(.white.opacity(0.2), lineWidth: AppSpacing.selectionStrokeWidth)
                        .frame(width: AppSpacing.selectionCircleSize, height: AppSpacing.selectionCircleSize)
                        .opacity(isSelected ? 0 : 1)

                    // Filled circle + checkmark
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
        .animation(.easeOut(duration: 0.3), value: selectedTone)
        // Staggered entry — per row
        .blur(radius: contentVisible ? 0 : 8)
        .opacity(contentVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.06), value: contentVisible)
    }
}

#Preview {
    ZStack {
        NightSkyBackground()
        OnboardingToneView(selectedTone: .constant(nil), onContinue: {})
    }
}

#Preview("With Selection") {
    ZStack {
        NightSkyBackground()
        OnboardingToneView(selectedTone: .constant("Calm"), onContinue: {})
    }
}
