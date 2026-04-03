//
//  DayPicker.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/3/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct DayPicker: View {

    // MARK: - State

    @Binding var selectedDays: Set<Int>

    // MARK: - Constants

    private let days: [(index: Int, letter: String)] = [
        (0, "S"), (1, "M"), (2, "T"), (3, "W"), (4, "T"), (5, "F"), (6, "S")
    ]

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.index) { day in
                let isSelected = selectedDays.contains(day.index)

                Button {
                    HapticManager.shared.selection()
                    if selectedDays.contains(day.index) {
                        selectedDays.remove(day.index)
                    } else {
                        selectedDays.insert(day.index)
                    }
                } label: {
                    Text(day.letter)
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .background(isSelected ? .white : .white.opacity(0.08))
                        .clipShape(Circle())
                }
                .animation(.easeOut(duration: 0.2), value: isSelected)
            }
        }
    }
}

// MARK: - Previews

#Preview("None Selected") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        DayPicker(selectedDays: .constant([]))
    }
}

#Preview("Weekdays") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        DayPicker(selectedDays: .constant([1, 2, 3, 4, 5]))
    }
}
