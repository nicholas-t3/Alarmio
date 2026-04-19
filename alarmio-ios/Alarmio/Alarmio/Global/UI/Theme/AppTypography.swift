//
//  AppTypography.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

enum AppTypography {

    // MARK: - Logo

    static let logo = Font.system(size: 58, weight: .black, design: .rounded)
    static let logoSubhead = Font.system(size: 42, weight: .black, design: .rounded)

    // MARK: - Display

    static let displayLarge = Font.system(size: 48, weight: .light)
    static let displayLargeTracking: CGFloat = 2

    static let displayMedium = Font.system(size: 36, weight: .light)
    static let displayMediumTracking: CGFloat = 1.5

    // MARK: - Headings

    static let headlineLarge = Font.system(size: 34, weight: .bold, design: .rounded)
    static let headlineLargeTracking: CGFloat = -0.5

    static let headlineMedium = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let headlineMediumTracking: CGFloat = -0.3

    // MARK: - Body

    static let bodyLarge = Font.system(size: 18, weight: .regular)
    static let bodyMedium = Font.system(size: 17, weight: .regular)
    static let bodySmall = Font.system(size: 15, weight: .regular)

    /// Used for the cycling "Setting a calm tone…" status text on the
    /// generating phase (create flow + onboarding). Slightly larger than
    /// bodyMedium so it reads as the focal point while the sky animates
    /// behind it.
    static let generatingStatus = Font.system(size: 20, weight: .regular)

    // MARK: - Labels

    static let labelLarge = Font.system(size: 18, weight: .medium)
    static let labelMedium = Font.system(size: 15, weight: .medium)
    static let labelSmall = Font.system(size: 13, weight: .medium)

    // MARK: - Button

    static let button = Font.system(size: 17, weight: .semibold)
    static let buttonTracking: CGFloat = 0.3

    // MARK: - Caption

    static let caption = Font.system(size: 12, weight: .semibold)
    static let captionTracking: CGFloat = 1.5
}

// MARK: - View Extension

extension View {
    func displayLarge() -> some View {
        self
            .font(AppTypography.displayLarge)
            .tracking(AppTypography.displayLargeTracking)
            .foregroundStyle(.white)
    }

    func displayMedium() -> some View {
        self
            .font(AppTypography.displayMedium)
            .tracking(AppTypography.displayMediumTracking)
            .foregroundStyle(.white)
    }

    func headlineLarge() -> some View {
        self
            .font(AppTypography.headlineLarge)
            .tracking(AppTypography.headlineLargeTracking)
            .foregroundStyle(.white)
    }

    func headlineMedium() -> some View {
        self
            .font(AppTypography.headlineMedium)
            .tracking(AppTypography.headlineMediumTracking)
            .foregroundStyle(.white)
    }

    func bodyLarge() -> some View {
        self
            .font(AppTypography.bodyLarge)
            .foregroundStyle(.white.opacity(0.4))
    }

    func bodyMedium() -> some View {
        self
            .font(AppTypography.bodyMedium)
            .foregroundStyle(.white.opacity(0.4))
    }

    func labelLarge() -> some View {
        self
            .font(AppTypography.labelLarge)
            .foregroundStyle(.white)
    }

    func captionStyle() -> some View {
        self
            .font(AppTypography.caption)
            .tracking(AppTypography.captionTracking)
            .foregroundStyle(.white.opacity(0.5))
    }
}

#Preview {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()

        VStack(alignment: .leading, spacing: 20) {
            Text("Display Large").displayLarge()
            Text("Display Medium").displayMedium()
            Text("Headline Large").headlineLarge()
            Text("Headline Medium").headlineMedium()
            Text("Body Large").bodyLarge()
            Text("Body Medium").bodyMedium()
            Text("Label Large").labelLarge()
            Text("CAPTION").captionStyle()
        }
        .padding(24)
    }
}
