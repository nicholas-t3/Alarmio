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
    @State private var circleRowWidth: CGFloat = 0

    // MARK: - Constants

    private static let weekdays: Set<Int> = [1, 2, 3, 4, 5]
    private static let weekends: Set<Int> = [0, 6]

    private let days: [(index: Int, letter: String)] = {
        // Locale-aware ordering: firstWeekday is 1=Sun, 2=Mon, etc.
        // Our internal indices use 0=Sun…6=Sat and stay stable regardless of display order.
        let letters = ["S", "M", "T", "W", "T", "F", "S"]
        let startIndex = Calendar.current.firstWeekday - 1
        return (0..<7).map { offset in
            let index = (startIndex + offset) % 7
            return (index, letters[index])
        }
    }()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {

            // Day-of-week circles
            dayCircles
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: CircleRowWidthKey.self, value: proxy.size.width)
                    }
                )
                .onPreferenceChange(CircleRowWidthKey.self) { circleRowWidth = $0 }

            // Weekdays / Weekends shortcut buttons — width matched to circle row
            shortcutButtons
                .frame(width: circleRowWidth > 0 ? circleRowWidth : nil)
        }
    }

    // MARK: - Subviews

    private var dayCircles: some View {
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
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.9))
                        .frame(width: 36, height: 36)
                        .background(isSelected ? .white : .white.opacity(0.08))
                        .clipShape(Circle())
                }
                .animation(.easeOut(duration: 0.2), value: isSelected)
            }
        }
    }

    private var shortcutButtons: some View {
        HStack(spacing: 8) {
            shortcutButton(title: "Weekdays", days: Self.weekdays)
            shortcutButton(title: "Weekends", days: Self.weekends)
        }
    }

    private func shortcutButton(title: String, days: Set<Int>) -> some View {
        let isActive = selectedDays == days

        return Button {
            HapticManager.shared.selection()
            _ = withAnimation(.easeOut(duration: 0.2)) {
                selectedDays = isActive ? [] : days
            }
        } label: {
            Text(title)
                .font(AppTypography.labelMedium)
                .foregroundStyle(isActive ? .black : .white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(isActive ? .white : .white.opacity(0.08))
                .clipShape(Capsule())
        }
        .animation(.easeOut(duration: 0.2), value: isActive)
    }
}

// MARK: - Preference Key

private struct CircleRowWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Previews

private struct DayPickerPreviewWrapper: View {
    @State private var selection: Set<Int>

    init(_ initial: Set<Int> = []) {
        _selection = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            Color(hex: "050505").ignoresSafeArea()
            DayPicker(selectedDays: $selection)
                .padding(.horizontal, 24)
        }
    }
}

#Preview("None Selected") {
    DayPickerPreviewWrapper()
}

#Preview("Weekdays Selected") {
    DayPickerPreviewWrapper([1, 2, 3, 4, 5])
}

#Preview("Weekends Selected") {
    DayPickerPreviewWrapper([0, 6])
}

#Preview("Mixed Selection") {
    DayPickerPreviewWrapper([1, 3, 5])
}
