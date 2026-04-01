//
//  WordRevealText.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct WordRevealText: View {

    // MARK: - State

    @State private var visibleCount = 0
    @State private var hasStarted = false

    // MARK: - Constants

    let words: [String]
    let font: Font
    let color: Color
    let wordDelay: Double
    let initialDelay: Double
    let lineSpacing: CGFloat
    let onComplete: (() -> Void)?

    init(
        _ text: String,
        font: Font = AppTypography.logo,
        color: Color = .white,
        wordDelay: Double = 0.35,
        initialDelay: Double = 0,
        lineSpacing: CGFloat = -4,
        onComplete: (() -> Void)? = nil
    ) {
        self.words = text.components(separatedBy: " ")
        self.font = font
        self.color = color
        self.wordDelay = wordDelay
        self.initialDelay = initialDelay
        self.lineSpacing = lineSpacing
        self.onComplete = onComplete
    }

    // MARK: - Body

    var body: some View {
        // Hidden full text defines the frame on any screen size
        Text(words.joined(separator: " "))
            .font(font)
            .multilineTextAlignment(.center)
            .lineSpacing(lineSpacing)
            .frame(maxWidth: .infinity)
            .hidden()
            .overlay {
                // Visible text inherits exact same width — wraps identically
                GeometryReader { geometry in
                    Text(visibleText)
                        .font(font)
                        .multilineTextAlignment(.center)
                        .lineSpacing(lineSpacing)
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: visibleCount)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        .task {
            guard !hasStarted else { return }
            hasStarted = true

            if initialDelay > 0 {
                try? await Task.sleep(for: .seconds(initialDelay))
            }

            for i in 1...words.count {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    visibleCount = i
                }
                HapticManager.shared.lightTap()

                if i < words.count {
                    try? await Task.sleep(for: .seconds(wordDelay))
                }
            }

            try? await Task.sleep(for: .milliseconds(200))
            onComplete?()
        }
    }

    // MARK: - Private Methods

    private var visibleText: String {
        guard visibleCount > 0 else { return "." }
        return words.prefix(visibleCount).joined(separator: " ")
    }
}

// MARK: - Previews

#Preview("Logo Style") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()

        WordRevealText(
            "Wake Up Your Way.",
            font: AppTypography.logo,
            wordDelay: 0.4
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("Headline Style") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()

        WordRevealText(
            "What Gets You Out Of Bed?",
            font: AppTypography.headlineLarge,
            wordDelay: 0.25
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("Long Text Wrap") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()

        WordRevealText(
            "Personalized Alarms That Actually Make You Want To Get Up.",
            font: AppTypography.logo,
            wordDelay: 0.3
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("iPhone SE") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()

        WordRevealText(
            "Wake Up Your Way.",
            font: AppTypography.logo,
            wordDelay: 0.4
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
    .frame(width: 375, height: 667)
}

#Preview("iPhone Pro Max") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()

        WordRevealText(
            "Wake Up Your Way.",
            font: AppTypography.logo,
            wordDelay: 0.4
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
    .frame(width: 440, height: 956)
}
