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
    static let horizontalPadding: CGFloat = 24
}

struct PrimaryButtonStyle: ButtonStyle {

    let isEnabled: Bool
    @State private var rotation: Angle = .zero

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .font(AppTypography.button)
            .tracking(AppTypography.buttonTracking)
            .foregroundStyle(isEnabled ? .black : .white.opacity(0.3))
            .frame(maxWidth: .infinity)
            .frame(height: AppButtons.height)
            .background(
                Capsule()
                    .fill(isEnabled ? Color.white : Color.white.opacity(0.08))
            )
            .overlay {
                // Rotating glow stroke — only when enabled
                Capsule()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                .white.opacity(0.9),
                                .white.opacity(0.1),
                                .white.opacity(0.4),
                                .white.opacity(0.05),
                                .white.opacity(0.9)
                            ],
                            center: .center,
                            angle: rotation
                        ),
                        lineWidth: 1.5
                    )
                    .blur(radius: 3)
                    .opacity(isEnabled ? 1 : 0)
            }
            .clipShape(Capsule())
            .shadow(color: .white.opacity(isEnabled ? 0.15 : 0), radius: 20, y: 0)
            .animation(.easeOut(duration: 0.4), value: isEnabled)
            .scaleEffect(pressed ? 0.96 : 1.0)
            .brightness(pressed ? -0.05 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = .degrees(360)
                }
            }
    }
}

extension View {
    func primaryButton(isEnabled: Bool = true) -> some View {
        self.buttonStyle(PrimaryButtonStyle(isEnabled: isEnabled))
    }
}

#Preview {
    ZStack {
        NightSkyBackground()

        VStack(spacing: 24) {
            Button("Get Started") {}
                .primaryButton()

            Button("Continue") {}
                .primaryButton(isEnabled: false)
        }
        .padding(.horizontal, AppButtons.horizontalPadding)
    }
}
