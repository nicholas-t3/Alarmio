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
                .headlineLarge()
                .multilineTextAlignment(.center)
                .modifier(PremiumBlurEffectExplicit(isVisible: contentVisible, delay: 0))

            Spacer()
                .frame(height: AppSpacing.sectionGap)

            // Tone options
            VStack(spacing: 0) {
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
            .animation(.easeOut(duration: 0.3).delay(Double(tones.count) * 0.03 + 0.1), value: contentVisible)
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

        Button {
            HapticManager.shared.selection()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedTone = name
            }
        } label: {
            HStack(spacing: AppSpacing.rowIconGap) {

                // Icon
                Image(systemName: icon)
                    .font(AppTypography.bodyLarge)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: AppSpacing.rowIconWidth)

                // Label
                Text(name)
                    .labelLarge()

                Spacer()

                // Selection indicator
                selectionCircle(isSelected: isSelected)
            }
            .padding(.horizontal, AppSpacing.rowHorizontal)
            .padding(.vertical, AppSpacing.rowVertical)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .blur(radius: contentVisible ? 0 : 8)
        .opacity(contentVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.03), value: contentVisible)
    }

    @ViewBuilder
    private func selectionCircle(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(isSelected ? 0 : 0.2), lineWidth: AppSpacing.selectionStrokeWidth)
                .frame(width: AppSpacing.selectionCircleSize, height: AppSpacing.selectionCircleSize)

            if isSelected {
                Circle()
                    .fill(.white)
                    .frame(width: AppSpacing.selectionCircleSize, height: AppSpacing.selectionCircleSize)

                Image(systemName: "checkmark")
                    .font(.system(size: AppSpacing.selectionCheckmarkSize, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        OnboardingToneView(selectedTone: .constant(nil), onContinue: {})
    }
}

#Preview("With Selection") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        OnboardingToneView(selectedTone: .constant("Calm"), onContinue: {})
    }
}
