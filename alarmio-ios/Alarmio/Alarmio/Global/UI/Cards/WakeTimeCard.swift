//
//  WakeTimeCard.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/10/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct WakeTimeCard: View {

    // MARK: - Bindings

    @Binding var wakeTime: Date

    // MARK: - Constants

    let mode: CardMode

    // MARK: - Init

    init(wakeTime: Binding<Date>, mode: CardMode = .standard) {
        self._wakeTime = wakeTime
        self.mode = mode
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 4) {

            // Label
            Text("WAKE TIME")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Time picker
            DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: mode))
    }
}

// MARK: - Previews

#Preview("Standard") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        WakeTimeCard(wakeTime: .constant(Date()))
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("Edit Mode") {
    ZStack {
        Color(hex: "0f1a2e").ignoresSafeArea()
        WakeTimeCard(wakeTime: .constant(Date()), mode: .edit)
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}
