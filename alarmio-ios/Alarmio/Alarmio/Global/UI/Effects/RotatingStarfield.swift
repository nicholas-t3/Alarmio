//
//  RotatingStarfield.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct RotatingNightSky: View {

    var body: some View {
        ZStack {

            // Sky gradient
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "020810"), location: 0),
                    .init(color: Color(hex: "060e1c"), location: 0.35),
                    .init(color: Color(hex: "0a1628"), location: 0.55),
                    .init(color: Color(hex: "111d35"), location: 0.78),
                    .init(color: Color(hex: "182440"), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Rotating star canvas
            RotatingStarCanvas()

            // Horizon glow
            GeometryReader { geometry in
                RadialGradient(
                    colors: [
                        Color(hex: "2a1f3d").opacity(0.3),
                        Color(hex: "1a1530").opacity(0.15),
                        .clear
                    ],
                    center: .init(x: 0.5, y: 1.0),
                    startRadius: 0,
                    endRadius: geometry.size.height * 0.5
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Rotating Star Canvas

private struct RotatingStarCanvas: View {

    // MARK: - State
    @State private var stars: [FieldStar] = []
    @State private var shootingStars: [ShootingStar] = []
    @State private var startTime: Date = .now
    @State private var needsGeneration = true

    // MARK: - Constants

    /// Full rotation period in seconds (10 minutes).
    private let rotationPeriod: Double = 600
    private let starCount = 1800

    // MARK: - Body
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let elapsed = timeline.date.timeIntervalSince(startTime)

            // Rotation angle for this frame
            let angle = elapsed / rotationPeriod * 2 * .pi
            let cosA = cos(angle)
            let sinA = sin(angle)

            Canvas { context, size in
                // Generate stars on first frame when we know the size
                if needsGeneration {
                    DispatchQueue.main.async {
                        generateStars(size: size)
                        needsGeneration = false
                    }
                    return
                }

                let fadeIn = min(elapsed / 2.0, 1.0)
                let w = size.width
                let h = size.height
                let cx = w / 2
                let cy = h / 2

                // Rotating star field
                for star in stars {
                    // star.dx/dy are pixel offsets from screen center.
                    // Rotate in pixel space — pixels are square, no distortion.
                    let rx = cx + star.dx * cosA - star.dy * sinA
                    let ry = cy + star.dx * sinA + star.dy * cosA

                    // Cull off-screen
                    guard rx > -5 && rx < w + 5 && ry > -5 && ry < h + 5 else { continue }

                    // Twinkle
                    let slowWave = sin(now * star.speed + star.phase)
                    var brightness = star.baseOpacity + (slowWave + 1) / 2 * star.twinkleRange

                    // Flare burst
                    let flareWave = sin(now * star.flareSpeed + star.flarePhase)
                    if flareWave > 0.92 {
                        let flareIntensity = (flareWave - 0.92) / 0.08
                        brightness = min(1.0, brightness + flareIntensity * star.flareStrength)

                        // Flare cross
                        let flareLen = star.radius * (3.0 + flareIntensity * 4.0)
                        context.opacity = fadeIn * flareIntensity * star.flareStrength * 0.4

                        var hLine = Path()
                        hLine.move(to: CGPoint(x: rx - flareLen, y: ry))
                        hLine.addLine(to: CGPoint(x: rx + flareLen, y: ry))
                        context.stroke(hLine, with: .color(.white), lineWidth: 0.3)

                        var vLine = Path()
                        vLine.move(to: CGPoint(x: rx, y: ry - flareLen))
                        vLine.addLine(to: CGPoint(x: rx, y: ry + flareLen))
                        context.stroke(vLine, with: .color(.white), lineWidth: 0.3)
                    }

                    let r = star.radius
                    let rect = CGRect(x: rx - r, y: ry - r, width: r * 2, height: r * 2)
                    context.opacity = fadeIn * brightness
                    context.fill(Circle().path(in: rect), with: .color(star.color))
                }

                // Shooting stars (screen-space, no rotation)
                for star in shootingStars {
                    let sElapsed = elapsed - star.startTime
                    guard sElapsed > 0 && sElapsed < star.duration else { continue }

                    let progress = sElapsed / star.duration

                    // Head
                    let headX = star.startX + (star.endX - star.startX) * progress
                    let headY = star.startY + (star.endY - star.startY) * progress

                    // Tail
                    let tailProgress = max(0, progress - star.tailLength)
                    let tailX = star.startX + (star.endX - star.startX) * tailProgress
                    let tailY = star.startY + (star.endY - star.startY) * tailProgress

                    let headPt = CGPoint(x: headX * w, y: headY * h)
                    let tailPt = CGPoint(x: tailX * w, y: tailY * h)

                    // Fade envelope
                    let fadeInS = min(progress / 0.1, 1.0)
                    let fadeOut = max(0, 1.0 - (progress - 0.7) / 0.3)
                    let opacity = min(fadeInS, fadeOut) * star.brightness

                    // Streak
                    var streak = Path()
                    streak.move(to: tailPt)
                    streak.addLine(to: headPt)

                    context.opacity = opacity * 0.7
                    context.stroke(
                        streak,
                        with: .linearGradient(
                            Gradient(colors: [.clear, .white]),
                            startPoint: tailPt,
                            endPoint: headPt
                        ),
                        lineWidth: 1.0
                    )

                    // Bright head dot
                    let headRect = CGRect(x: headPt.x - 1, y: headPt.y - 1, width: 2, height: 2)
                    context.opacity = opacity
                    context.fill(Circle().path(in: headRect), with: .color(.white))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startTime = .now
            scheduleShootingStars()
        }
    }

    // MARK: - Private Methods

    private func generateStars(size: CGSize) {
        let colors: [Color] = [.white, Color(hex: "E8DFF5"), Color(hex: "FFF4E0"), Color(hex: "D4E5FF")]

        // The screen diagonal / 2 is the minimum radius to cover every corner
        // from center at any rotation. Add 10% margin.
        let halfDiag = sqrt(size.width * size.width + size.height * size.height) / 2
        let maxRadius = halfDiag * 1.1

        stars = (0..<starCount).map { _ in
            let isBright = Double.random(in: 0...1) > 0.82

            // Uniform circular distribution in pixel space.
            // sqrt(random) prevents center clustering.
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let dist = maxRadius * sqrt(CGFloat.random(in: 0...1))
            let dx = cos(angle) * dist
            let dy = sin(angle) * dist

            return FieldStar(
                dx: dx,
                dy: dy,
                radius: isBright ? CGFloat.random(in: 0.5...0.9) : CGFloat.random(in: 0.2...0.45),
                baseOpacity: Double.random(in: 0.2...0.55),
                twinkleRange: Double.random(in: 0.05...0.3),
                speed: Double.random(in: 0.3...1.5),
                phase: Double.random(in: 0...(.pi * 2)),
                flareSpeed: Double.random(in: 0.15...0.6),
                flarePhase: Double.random(in: 0...(.pi * 2)),
                flareStrength: isBright ? Double.random(in: 0.5...1.0) : Double.random(in: 0.0...0.3),
                color: isBright ? colors.randomElement()! : .white
            )
        }
    }

    private func scheduleShootingStars() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Double.random(in: 5...8)))

            while true {
                let startX = CGFloat.random(in: 0.05...0.7)
                let startY = CGFloat.random(in: 0.02...0.35)
                let angle = Double.random(in: 0.3...0.7)
                let length = CGFloat.random(in: 0.25...0.50)

                let ss = ShootingStar(
                    startX: startX,
                    startY: startY,
                    endX: startX + length,
                    endY: startY + length * CGFloat(angle),
                    startTime: Date.now.timeIntervalSince(startTime),
                    duration: Double.random(in: 0.8...1.4),
                    tailLength: Double.random(in: 0.25...0.4),
                    brightness: Double.random(in: 0.35...0.6)
                )
                shootingStars.append(ss)

                // Clean up old ones
                let currentElapsed = Date.now.timeIntervalSince(startTime)
                shootingStars.removeAll { currentElapsed - $0.startTime > $0.duration + 1 }

                try? await Task.sleep(for: .seconds(Double.random(in: 8...20)))
            }
        }
    }
}

// MARK: - Models

/// Star positions stored as pixel offsets from screen center.
/// Rotating in pixel space (square coordinates) produces clean circular motion
/// with no aspect-ratio distortion.
private struct FieldStar {
    let dx: CGFloat
    let dy: CGFloat
    let radius: CGFloat
    let baseOpacity: Double
    let twinkleRange: Double
    let speed: Double
    let phase: Double
    let flareSpeed: Double
    let flarePhase: Double
    let flareStrength: Double
    let color: Color
}

private struct ShootingStar {
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let startTime: Double
    let duration: Double
    let tailLength: Double
    let brightness: Double
}

// MARK: - Previews

#Preview("Rotating Night Sky") {
    RotatingNightSky()
}

#Preview("With Logo") {
    ZStack {
        RotatingNightSky()

        Text("alarmio")
            .font(.system(size: 52, weight: .black, design: .rounded))
            .foregroundStyle(.white)
    }
}
