//
//  SnoozeCard.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/10/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct SnoozeCard: View {

    // MARK: - Bindings

    @Binding var maxSnoozes: Int
    @Binding var snoozeInterval: Int
    @Binding var unlimitedSnooze: Bool

    // MARK: - Constants

    let mode: CardMode
    let allowUnlimited: Bool
    private static let stepperLabelWidth: CGFloat = 110

    // MARK: - Init

    init(
        maxSnoozes: Binding<Int>,
        snoozeInterval: Binding<Int>,
        unlimitedSnooze: Binding<Bool> = .constant(false),
        allowUnlimited: Bool = false,
        mode: CardMode = .standard
    ) {
        self._maxSnoozes = maxSnoozes
        self._snoozeInterval = snoozeInterval
        self._unlimitedSnooze = unlimitedSnooze
        self.allowUnlimited = allowUnlimited
        self.mode = mode
    }

    // MARK: - Computed Properties

    private var showInterval: Bool {
        maxSnoozes > 0 || unlimitedSnooze
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 14) {

            // Label
            Text("SNOOZE")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Count stepper
            countRow

            // Interval stepper
            intervalRow
                .premiumBlur(isVisible: showInterval, duration: 0.3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: mode))
    }

    // MARK: - Subviews

    private var countRow: some View {
        HStack(spacing: 16) {

            // Minus
            Button {
                HapticManager.shared.selection()
                if allowUnlimited && unlimitedSnooze {
                    unlimitedSnooze = false
                    maxSnoozes = 3
                } else {
                    maxSnoozes = max(0, maxSnoozes - 1)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }

            // Label
            HStack(spacing: 6) {
                if allowUnlimited && unlimitedSnooze {
                    Text("Unlimited")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                } else if maxSnoozes == 0 {
                    Text("No snooze")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.numericText())
                } else {
                    Text("\(maxSnoozes)")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(maxSnoozes == 1 ? "snooze" : "snoozes")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.numericText())
                }
            }
            .frame(width: Self.stepperLabelWidth)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: maxSnoozes)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: unlimitedSnooze)

            // Plus
            Button {
                HapticManager.shared.selection()
                if allowUnlimited {
                    if unlimitedSnooze {
                        // Already unlimited, no-op
                    } else if maxSnoozes >= 3 {
                        unlimitedSnooze = true
                    } else {
                        maxSnoozes = min(3, maxSnoozes + 1)
                    }
                } else {
                    maxSnoozes = min(3, maxSnoozes + 1)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    private var intervalRow: some View {
        HStack(spacing: 16) {

            // Minus
            Button {
                HapticManager.shared.selection()
                snoozeInterval = max(1, snoozeInterval - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }

            // Label
            HStack(spacing: 6) {
                Text("\(snoozeInterval)")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(snoozeInterval == 1 ? "minute" : "minutes")
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.7))
                    .contentTransition(.numericText())
            }
            .frame(width: Self.stepperLabelWidth)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: snoozeInterval)

            // Plus
            Button {
                HapticManager.shared.selection()
                snoozeInterval = min(15, snoozeInterval + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - Previews

#Preview("Standard") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        SnoozeCard(maxSnoozes: .constant(3), snoozeInterval: .constant(5))
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("Unlimited") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        SnoozeCard(
            maxSnoozes: .constant(3),
            snoozeInterval: .constant(5),
            unlimitedSnooze: .constant(true),
            allowUnlimited: true
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("Edit Mode") {
    ZStack {
        Color(hex: "0f1a2e").ignoresSafeArea()
        SnoozeCard(maxSnoozes: .constant(2), snoozeInterval: .constant(5), mode: .edit)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}
