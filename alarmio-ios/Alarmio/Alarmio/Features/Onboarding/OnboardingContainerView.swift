//
//  OnboardingContainerView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case intro = 0
    case tone
    // Future steps: why, intensity, difficulty, voice, content, leaveTime, wakeTime, snooze
}

struct OnboardingContainerView: View {

    // MARK: - State

    @State private var currentStep: OnboardingStep = .intro
    @State private var stepVisible = false
    @State private var selectedTone: String? = nil
    @State private var maskTime: Float = 0.0
    @State private var maskTimer: Timer?
    @State private var gradientActive = false
    @State private var borderAngle: Angle = .zero

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {

                // Base background
                Color(hex: "050505")
                    .ignoresSafeArea()

                // Ambient mesh gradient
                MeshGradientBackground(speed: 0.02, opacity: gradientActive ? 0.5 : 0)
                    .animation(.easeIn(duration: 1.5), value: gradientActive)

                // Rotating border glow
                RoundedRectangle(cornerRadius: 48, style: .continuous)
                    .stroke(
                        AngularGradient(
                            colors: [
                                .red, .orange, .yellow, .green,
                                .mint, .blue, .indigo, .purple, .red
                            ],
                            center: .center,
                            angle: borderAngle
                        ),
                        lineWidth: gradientActive ? 2 : 0
                    )
                    .blur(radius: 8)
                    .padding(4)
                    .ignoresSafeArea()
                    .animation(.easeIn(duration: 2.0), value: gradientActive)

                // Content masked with breathing shape
                ZStack {

                    // Dark content background
                    Color(hex: "050505")

                    // Current step content
                    stepContent
                }
                .mask {
                    let fullSize = CGSize(
                        width: geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing,
                        height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
                    )
                    BreathingRectangle(
                        size: fullSize,
                        cornerRadius: 48,
                        t: CGFloat(maskTime)
                    )
                    .scaleEffect(gradientActive ? 1.0 : 1.2)
                    .blur(radius: gradientActive ? 24 : 8)
                    .animation(.easeInOut(duration: 1.0), value: gradientActive)
                }
                .ignoresSafeArea()
            }
        }
        .task {
            // Start mask animation timer
            maskTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
                DispatchQueue.main.async {
                    maskTime += gradientActive ? 0.02 : 0
                    borderAngle += .degrees(0.3)
                }
            }

            // Fade in gradient
            try? await Task.sleep(for: .milliseconds(300))
            gradientActive = true

            // Reveal first step
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation {
                stepVisible = true
            }
        }
        .onDisappear {
            maskTimer?.invalidate()
            maskTimer = nil
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .intro:
            OnboardingIntroView(onContinue: { advanceToStep(.tone) })
                .premiumBlur(isVisible: stepVisible)

        case .tone:
            OnboardingToneView(
                selectedTone: $selectedTone,
                onContinue: { /* next step */ }
            )
            .premiumBlur(isVisible: stepVisible)
        }
    }

    // MARK: - Private Methods

    private func advanceToStep(_ step: OnboardingStep) {
        HapticManager.shared.softTap()

        withAnimation(.easeOut(duration: 0.3)) {
            stepVisible = false
        }

        Task {
            try? await Task.sleep(for: .milliseconds(350))
            currentStep = step

            withAnimation(.easeOut(duration: 0.4)) {
                stepVisible = true
            }
        }
    }
}

#Preview {
    OnboardingContainerView()
}
