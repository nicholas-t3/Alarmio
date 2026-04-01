//
//  AppButtons.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

enum AppButtons {

    // MARK: - Dimensions

    static let height: CGFloat = 56
    static let cornerRadius: CGFloat = 16
    static let horizontalPadding: CGFloat = 24

    // MARK: - Colors

    static let primaryBackground: Color = .white
    static let primaryForeground: Color = .black
    static let disabledBackground: Color = .white.opacity(0.08)
    static let disabledForeground: Color = .white.opacity(0.3)
}

struct PrimaryButtonStyle: ButtonStyle {

    let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.labelLarge)
            .foregroundStyle(isEnabled ? AppButtons.primaryForeground : AppButtons.disabledForeground)
            .frame(maxWidth: .infinity)
            .frame(height: AppButtons.height)
            .background(isEnabled ? AppButtons.primaryBackground : AppButtons.disabledBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppButtons.cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func primaryButton(isEnabled: Bool = true) -> some View {
        self.buttonStyle(PrimaryButtonStyle(isEnabled: isEnabled))
    }
}

#Preview {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()

        VStack(spacing: 16) {
            Button("Get started") {}
                .primaryButton()

            Button("Continue") {}
                .primaryButton(isEnabled: false)
        }
        .padding(.horizontal, AppButtons.horizontalPadding)
    }
}
