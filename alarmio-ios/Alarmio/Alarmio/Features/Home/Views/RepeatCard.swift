//
//  RepeatCard.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/10/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

// MARK: - Card Mode

enum CardMode {
    case standard
    case edit
}

struct RepeatCard: View {

    // MARK: - Bindings

    @Binding var selectedDays: Set<Int>

    // MARK: - Constants

    let mode: CardMode

    private static let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // MARK: - Init

    init(selectedDays: Binding<Set<Int>>, mode: CardMode = .standard) {
        self._selectedDays = selectedDays
        self.mode = mode
    }

    // MARK: - Computed Properties

    private var summary: String {
        if selectedDays.isEmpty {
            return "One-time alarm"
        } else if selectedDays == Set([1, 2, 3, 4, 5]) {
            return "Weekdays"
        } else if selectedDays == Set([0, 6]) {
            return "Weekends"
        } else if selectedDays.count == 7 {
            return "Every day"
        } else {
            return Array(selectedDays).sorted()
                .compactMap { $0 < Self.dayLabels.count ? Self.dayLabels[$0] : nil }
                .joined(separator: ", ")
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 14) {

            // Label
            Text("REPEAT")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Day picker
            DayPicker(selectedDays: $selectedDays)

            // Summary
            Text(summary)
                .font(AppTypography.bodySmall)
                .foregroundStyle(.white.opacity(0.4))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedDays)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: mode))
    }
}

// MARK: - Glass Modifier

private struct CardGlassModifier: ViewModifier {
    let mode: CardMode

    func body(content: Content) -> some View {
        switch mode {
        case .standard:
            content
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
        case .edit:
            content
                .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Previews

#Preview("Standard") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        RepeatCard(selectedDays: .constant([1, 2, 3, 4, 5]))
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("Edit Mode") {
    ZStack {
        Color(hex: "0f1a2e").ignoresSafeArea()
        RepeatCard(selectedDays: .constant([1, 3, 5]), mode: .edit)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}
