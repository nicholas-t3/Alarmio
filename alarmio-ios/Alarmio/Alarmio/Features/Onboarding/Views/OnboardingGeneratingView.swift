//
//  OnboardingGeneratingView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct OnboardingGeneratingView: View {

    // MARK: - State
    @State private var contentVisible = false
    @State private var ringRotation: Angle = .zero
    @State private var glowPulse = false
    @State private var statusText = "Creating your alarm"
    @State private var isComplete = false

    // MARK: - Constants
    let onComplete: () -> Void

    // MARK: - Body
    var body: some View {
        ZStack {

            // Center element — dead center of screen, no layout influence from text
            ZStack {

                // Outer pulsing halo
                Circle()
                    .fill(Color(hex: "4A9EFF").opacity(glowPulse ? 0.15 : 0.04))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)

                // Mid halo
                Circle()
                    .fill(Color(hex: "7EBDFF").opacity(glowPulse ? 0.1 : 0.02))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)

                // Inner glow core
                Circle()
                    .fill(Color(hex: "4A9EFF").opacity(glowPulse ? 0.25 : 0.08))
                    .frame(width: 50, height: 50)
                    .blur(radius: 12)

                // Waveform icon
                Image(systemName: "waveform")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .symbolEffect(.bounce.byLayer.up, options: .repeating.speed(0.3), value: glowPulse)
                    .offset(y: 4)
            }
            .premiumBlur(isVisible: contentVisible, duration: 0.5)

            // Bottom status text — pinned to bottom, doesn't affect center layout
//            VStack {
//                Spacer()
//
//                Text(statusText)
//                    .font(AppTypography.bodyMedium)
//                    .foregroundStyle(.white)
//                    .shadow(color: .black.opacity(0.8), radius: 6, x: 0, y: 0)
//                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 0)
//                    .contentTransition(.numericText())
//                    .animation(.easeInOut(duration: 0.4), value: statusText)
//                    .premiumBlur(isVisible: contentVisible, duration: 0.5)
//                    .padding(.bottom, AppSpacing.screenBottom + 60)
//            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            contentVisible = true
            glowPulse = true

            // Start spinner — smooth continuous rotation
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                ringRotation = .degrees(360)
            }

            // Cycle status messages
            startStatusCycle()

            // Fake network call — 10 seconds
            // TODO: Replace with real Composer API call
            try? await Task.sleep(for: .seconds(10))

            isComplete = true
            HapticManager.shared.success()

            // Brief pause to show "Done!" then transition
            try? await Task.sleep(for: .milliseconds(600))
            onComplete()
        }
    }

    // MARK: - Private Methods

    private func startStatusCycle() {
        Task { @MainActor in
            let messages = [
                "Creating your alarm",
                "Finding your voice",
                "Writing your wake-up",
                "Adding some personality",
                "Making it sound good",
                "Almost there",
            ]
            var index = 0

            while !isComplete {
                try? await Task.sleep(for: .seconds(2.5))
                guard !isComplete else { break }
                index = (index + 1) % messages.count
                statusText = messages[index]
            }
        }
    }
}

// MARK: - Generating Background (Warp Speed)

struct GeneratingBackground: View {

    @State private var startTime: Date = .now
    @State private var stars: [WarpStar] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startTime)

            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let cx = size.width * 0.5
                let cy = size.height * 0.5

                // Deep black
                context.fill(Rectangle().path(in: rect), with: .color(Color(hex: "010108")))

                // Speed ramps smoothly over 3s then holds
                let rampDuration = 3.0
                let minSpeed = 0.05
                let maxSpeed = 1.25
                let t = min(elapsed, rampDuration)
                let tNorm = t / rampDuration

                // Integral for smooth accumulation
                let rampDist = minSpeed * t + (maxSpeed - minSpeed) * (t * t * t) / (3.0 * rampDuration * rampDuration)
                let overtime = max(0, elapsed - rampDuration)
                let totalDist = rampDist + maxSpeed * overtime

                // Visual params at current speed
                let speedCurve = min(tNorm * tNorm + (overtime > 0 ? (1.0 - tNorm * tNorm) : 0), 1.0)
                let streakLength = 0.002 + speedCurve * 0.1

                // Center glow
                let glowIntensity = 0.05 + speedCurve * 0.2
                let centerGlow = RadialGradient(
                    colors: [
                        Color(hex: "4A9EFF").opacity(glowIntensity),
                        Color(hex: "1B3F6F").opacity(glowIntensity * 0.4),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size.height * 0.4
                )
                context.fill(Rectangle().path(in: rect), with: .style(centerGlow))

                // Stars
                var ac = context
                ac.blendMode = .plusLighter

                for star in stars {
                    let totalLife = star.lifetime
                    let age = (totalDist + star.phase).truncatingRemainder(dividingBy: totalLife)
                    let progress = age / totalLife

                    let dist = progress * progress
                    let currentX = cx + star.dirX * dist * size.width * 0.8
                    let currentY = cy + star.dirY * dist * size.height * 0.8

                    let tailDist = max(0, dist - streakLength)
                    let tailX = cx + star.dirX * tailDist * size.width * 0.8
                    let tailY = cy + star.dirY * tailDist * size.height * 0.8

                    let brightness = dist * star.brightness
                    let alpha = brightness * (0.3 + speedCurve * 0.7)
                    guard alpha > 0.01 else { continue }

                    var path = Path()
                    path.move(to: CGPoint(x: tailX, y: tailY))
                    path.addLine(to: CGPoint(x: currentX, y: currentY))

                    let lineWidth = star.thickness * (0.5 + dist * 1.5)
                    ac.opacity = alpha
                    ac.stroke(path, with: .color(star.color), lineWidth: lineWidth)

                    if dist > 0.1 {
                        let dotSize = lineWidth * 2
                        let dotRect = CGRect(
                            x: currentX - dotSize / 2,
                            y: currentY - dotSize / 2,
                            width: dotSize,
                            height: dotSize
                        )
                        ac.opacity = alpha * 0.6
                        ac.fill(Circle().path(in: dotRect), with: .color(.white))
                    }
                }

                // Vignette
                let vignette = RadialGradient(
                    colors: [.clear, Color(hex: "010108").opacity(0.5)],
                    center: .center,
                    startRadius: size.width * 0.3,
                    endRadius: size.width * 0.8
                )
                context.opacity = 1.0
                context.fill(Rectangle().path(in: rect), with: .style(vignette))
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startTime = .now
            generateStars()
        }
    }

    private func generateStars() {
        let colors: [Color] = [
            .white,
            Color(hex: "D4EDFF"),
            Color(hex: "4A9EFF"),
            Color(hex: "7EBDFF"),
            Color(hex: "FFF4E0"),
        ]

        stars = (0..<200).map { _ in
            let angle = Double.random(in: 0...(.pi * 2))
            return WarpStar(
                dirX: cos(angle),
                dirY: sin(angle),
                phase: Double.random(in: 0...3),
                lifetime: Double.random(in: 1.5...3.5),
                brightness: Double.random(in: 0.3...1.0),
                thickness: CGFloat.random(in: 0.5...2.0),
                color: colors.randomElement()!
            )
        }
    }
}

// MARK: - Models

private struct WarpStar {
    let dirX: Double
    let dirY: Double
    let phase: Double
    let lifetime: Double
    let brightness: Double
    let thickness: CGFloat
    let color: Color
}

// MARK: - Previews

#Preview("In Container — from Snooze") {
    OnboardingContainerView.preview(step: .snooze)
}

#Preview("In Container — Generating") {
    OnboardingContainerView.preview(step: .generating)
}

#Preview("Background Only") {
    GeneratingBackground()
}
