//
//  NameRowCard.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/15/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

/// Single-line row showing an alarm's name. "Name" label on the left,
/// current value (or "None") on the right. Matches `compactVoiceCard` /
/// edit `summaryRow` dimensions so it stacks cleanly alongside them.
struct NameRowCard: View {

    // MARK: - Style

    enum Style {
        /// Clear glass — used in the create confirmation stack alongside
        /// the alarm preview and compact voice cards.
        case clear
        /// Tinted glass — used in the edit sheet summary alongside the
        /// Schedule / Snooze / Voice summary rows.
        case tinted
    }

    // MARK: - Constants

    let name: String?
    let style: Style
    let action: () -> Void

    // MARK: - Init

    init(name: String?, style: Style = .clear, action: @escaping () -> Void) {
        self.name = name
        self.style = style
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {

                // Left label
                Text("Alarm Name")
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.5))

                Spacer(minLength: 8)

                // Right value
                Text(displayValue)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.numericText())

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(glassBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: name)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var glassBackground: some View {
        switch style {
        case .clear:
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.clear)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
        case .tinted:
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.clear)
                .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Private Methods

    private var displayValue: String {
        guard let name, !name.isEmpty else { return "None" }
        return name
    }
}

// MARK: - Previews

#Preview("Clear — None") {
    ZStack {
        MorningSky(starOpacity: 0.8, showConstellations: false)

        NameRowCard(name: nil, style: .clear) {}
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("Clear — Named") {
    ZStack {
        MorningSky(starOpacity: 0.8, showConstellations: false)

        NameRowCard(name: "Morning run", style: .clear) {}
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("Tinted — Named") {
    ZStack {
        Color(hex: "0f1a2e").ignoresSafeArea()

        NameRowCard(name: "Weekday focus", style: .tinted) {}
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}
