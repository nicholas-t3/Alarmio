//
//  SelectionCircle.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct SelectionCircle: View {

    let isSelected: Bool

    var body: some View {
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
}

#Preview {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()

        HStack(spacing: 32) {
            SelectionCircle(isSelected: false)
            SelectionCircle(isSelected: true)
        }
    }
}
