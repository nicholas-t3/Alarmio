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
                .frame(height: 80)

            // Header
            VStack(spacing: 12) {
                Text("What gets you")
                    .font(.system(size: 32, weight: .light))
                    .tracking(1)
                    .foregroundStyle(.white)

                Text("out of bed?")
                    .font(.system(size: 32, weight: .light))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .modifier(PremiumBlurEffectExplicit(isVisible: contentVisible, delay: 0))

            Spacer()
                .frame(height: 48)

            // Tone options
            VStack(spacing: 0) {
                ForEach(Array(tones.enumerated()), id: \.element.0) { index, tone in
                    toneRow(name: tone.0, icon: tone.1, index: index)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue button
            Button {
                HapticManager.shared.buttonTap()
                onContinue()
            } label: {
                Text("Continue")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(selectedTone != nil ? .black : .white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedTone != nil ? .white : .white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .animation(.easeOut(duration: 0.25), value: selectedTone)
            }
            .disabled(selectedTone == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
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
            HStack(spacing: 16) {

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 32)

                // Label
                Text(name)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.white)

                Spacer()

                // Selection indicator
                selectionCircle(isSelected: isSelected)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
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
                .strokeBorder(.white.opacity(isSelected ? 0 : 0.2), lineWidth: 1.5)
                .frame(width: 28, height: 28)

            if isSelected {
                Circle()
                    .fill(.white)
                    .frame(width: 28, height: 28)

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
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
