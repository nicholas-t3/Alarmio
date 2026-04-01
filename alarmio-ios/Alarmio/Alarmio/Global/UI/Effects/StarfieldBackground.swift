//
//  StarfieldBackground.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct NightSkyBackground: View {

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

            // Stars + constellations
            StarCanvas()

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

// MARK: - Star Canvas

private struct StarCanvas: View {

    @State private var stars: [FieldStar] = []
    @State private var promotedGroups: [PromotedStarGroup] = []
    @State private var constellationPool: [ConstellationTemplate] = []
    @State private var activeConstellations: [ActiveConstellation] = []
    @State private var shootingStars: [ShootingStar] = []
    @State private var startTime: Date = .now
    @State private var rotation: Angle = .zero

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let elapsed = timeline.date.timeIntervalSince(startTime)

            Canvas { context, size in
                let fadeIn = min(elapsed / 2.0, 1.0)

                // Background star field
                for star in stars {
                    let x = star.x * size.width
                    let y = star.y * size.height

                    // Twinkle: mostly steady, occasional sharp flare
                    let slowWave = sin(now * star.speed + star.phase)
                    var brightness = star.baseOpacity + (slowWave + 1) / 2 * star.twinkleRange

                    // Flare burst — sharp spike when a fast sine crosses threshold
                    let flareWave = sin(now * star.flareSpeed + star.flarePhase)
                    if flareWave > 0.92 {
                        let flareIntensity = (flareWave - 0.92) / 0.08
                        brightness = min(1.0, brightness + flareIntensity * star.flareStrength)

                        // Draw flare cross
                        let flareLen = star.radius * (3.0 + flareIntensity * 4.0)
                        context.opacity = fadeIn * flareIntensity * star.flareStrength * 0.4

                        var hLine = Path()
                        hLine.move(to: CGPoint(x: x - flareLen, y: y))
                        hLine.addLine(to: CGPoint(x: x + flareLen, y: y))
                        context.stroke(hLine, with: .color(.white), lineWidth: 0.3)

                        var vLine = Path()
                        vLine.move(to: CGPoint(x: x, y: y - flareLen))
                        vLine.addLine(to: CGPoint(x: x, y: y + flareLen))
                        context.stroke(vLine, with: .color(.white), lineWidth: 0.3)
                    }

                    let r = star.radius
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    context.opacity = fadeIn * brightness
                    context.fill(Circle().path(in: rect), with: .color(star.color))
                }

                // Promoted constellation stars (FIFO, max 15 groups)
                for group in promotedGroups {
                    for star in group.stars {
                        let twinkle = sin(now * star.speed + star.phase)
                        let brightness = 0.5 + (twinkle + 1) / 2 * 0.5

                        let x = (group.offsetX + star.x) * size.width
                        let y = (group.offsetY + star.y) * size.height
                        let r = star.radius
                        let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                        context.opacity = group.opacity * brightness * 0.85
                        context.fill(Circle().path(in: rect), with: .color(star.color))
                    }
                }

                // Active constellations
                for ac in activeConstellations {
                    let cElapsed = elapsed - ac.appearTime
                    let template = ac.template

                    let cycleDuration = ac.lifetime
                    let drawPhase = 2.5
                    let fadeOutStart = cycleDuration - 1.5
                    guard cElapsed > 0 else { continue }

                    // Stars always render once faded in
                    let starFadeIn = min(cElapsed / 1.0, 1.0)

                    // Lines fade out after their lifetime
                    var lineOpacityMaster: Double
                    if cElapsed > fadeOutStart + 1.5 {
                        lineOpacityMaster = 0
                    } else if cElapsed < drawPhase {
                        lineOpacityMaster = min(cElapsed / 1.0, 1.0)
                    } else if cElapsed > fadeOutStart {
                        lineOpacityMaster = max(0, 1.0 - (cElapsed - fadeOutStart) / 1.5)
                    } else {
                        lineOpacityMaster = 1.0
                    }

                    // Constellation stars — always visible once faded in
                    for star in template.stars {
                        let sx = (ac.offsetX + star.x) * size.width
                        let sy = (ac.offsetY + star.y) * size.height

                        let twinkle = sin(now * star.speed + star.phase)
                        let starBright = 0.5 + (twinkle + 1) / 2 * 0.5

                        let r = star.radius
                        let rect = CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)
                        context.opacity = starFadeIn * starBright * 0.85
                        context.fill(Circle().path(in: rect), with: .color(star.color))
                    }

                    // Lines — draw in sequentially, fade out independently
                    let edgeCount = Double(template.edges.count)
                    for (i, edge) in template.edges.enumerated() {
                        let edgeStart = (Double(i) / edgeCount) * drawPhase
                        let edgeDur = drawPhase / edgeCount
                        let progress = max(0, min(1, (cElapsed - edgeStart) / edgeDur))
                        guard progress > 0 else { continue }

                        let from = template.stars[edge.0]
                        let to = template.stars[edge.1]

                        let p1 = CGPoint(
                            x: (ac.offsetX + from.x) * size.width,
                            y: (ac.offsetY + from.y) * size.height
                        )
                        let p2Full = CGPoint(
                            x: (ac.offsetX + to.x) * size.width,
                            y: (ac.offsetY + to.y) * size.height
                        )
                        let p2 = CGPoint(
                            x: p1.x + (p2Full.x - p1.x) * progress,
                            y: p1.y + (p2Full.y - p1.y) * progress
                        )

                        var path = Path()
                        path.move(to: p1)
                        path.addLine(to: p2)

                        context.opacity = lineOpacityMaster * 0.18 * progress
                        context.stroke(path, with: .color(.white), lineWidth: 0.5)
                    }
                }

                // Shooting stars
                for star in shootingStars {
                    let sElapsed = elapsed - star.startTime
                    guard sElapsed > 0 && sElapsed < star.duration else { continue }

                    let progress = sElapsed / star.duration

                    // Head position
                    let headX = star.startX + (star.endX - star.startX) * progress
                    let headY = star.startY + (star.endY - star.startY) * progress

                    // Tail — trails behind the head
                    let tailLength = star.tailLength
                    let tailProgress = max(0, progress - tailLength)
                    let tailX = star.startX + (star.endX - star.startX) * tailProgress
                    let tailY = star.startY + (star.endY - star.startY) * tailProgress

                    let headPt = CGPoint(x: headX * size.width, y: headY * size.height)
                    let tailPt = CGPoint(x: tailX * size.width, y: tailY * size.height)

                    // Fade in at start, fade out at end
                    let fadeIn = min(progress / 0.1, 1.0)
                    let fadeOut = max(0, 1.0 - (progress - 0.7) / 0.3)
                    let opacity = min(fadeIn, fadeOut) * star.brightness

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
        .rotationEffect(rotation, anchor: .init(x: 0.6, y: 0.3))
        .ignoresSafeArea()
        .onAppear {
            startTime = .now
            generateStars()
            buildConstellationPool()
            scheduleConstellations()
            scheduleShootingStars()

            withAnimation(.linear(duration: 600).repeatForever(autoreverses: false)) {
                rotation = .degrees(360)
            }
        }
    }

    // MARK: - Private Methods

    private func generateStars() {
        let colors: [Color] = [.white, Color(hex: "E8DFF5"), Color(hex: "FFF4E0"), Color(hex: "D4E5FF")]

        stars = (0..<1400).map { _ in
            let isBright = Double.random(in: 0...1) > 0.82

            return FieldStar(
                x: CGFloat.random(in: -0.2...1.2),
                y: CGFloat.random(in: -0.2...1.2),
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

    private func buildConstellationPool() {
        let warm = Color(hex: "FFF4E0")
        let cool = Color(hex: "D4E5FF")
        let lav = Color(hex: "E8DFF5")

        func s(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ c: Color = .white) -> ConstellationStar {
            ConstellationStar(
                x: x, y: y, radius: r,
                speed: Double.random(in: 0.8...1.8),
                phase: Double.random(in: 0...(.pi * 2)),
                color: c
            )
        }

        constellationPool = [
            // Orion
            ConstellationTemplate(
                stars: [
                    s(0.00, 0.00, 0.9, cool),
                    s(0.10, 0.00, 0.7),
                    s(0.03, 0.06, 0.6),
                    s(0.05, 0.065, 0.65),
                    s(0.07, 0.07, 0.6),
                    s(-0.01, 0.12, 0.8, warm),
                    s(0.11, 0.12, 1.0, cool),
                ],
                edges: [(0, 1), (0, 2), (1, 4), (2, 3), (3, 4), (2, 5), (4, 6)]
            ),
            // Cassiopeia — W shape
            ConstellationTemplate(
                stars: [
                    s(0.00, 0.02, 0.8, warm),
                    s(0.05, 0.00, 0.7),
                    s(0.10, 0.03, 0.75, lav),
                    s(0.14, 0.00, 0.65),
                    s(0.18, 0.02, 0.7, cool),
                ],
                edges: [(0, 1), (1, 2), (2, 3), (3, 4)]
            ),
            // Ursa Minor — Little Dipper
            ConstellationTemplate(
                stars: [
                    s(0.00, 0.00, 1.0, warm),
                    s(-0.02, 0.05, 0.6),
                    s(0.01, 0.09, 0.55),
                    s(0.05, 0.11, 0.65, lav),
                    s(0.09, 0.10, 0.6),
                    s(0.10, 0.07, 0.55, cool),
                    s(0.07, 0.06, 0.6),
                ],
                edges: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 3)]
            ),
            // Leo
            ConstellationTemplate(
                stars: [
                    s(0.00, 0.04, 0.9, warm),
                    s(0.03, 0.01, 0.6),
                    s(0.07, 0.00, 0.65, lav),
                    s(0.10, 0.02, 0.6),
                    s(0.08, 0.06, 0.55),
                    s(0.04, 0.08, 0.6, cool),
                ],
                edges: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 0)]
            ),
            // Lyra — small triangle + tail
            ConstellationTemplate(
                stars: [
                    s(0.00, 0.00, 1.0, cool),
                    s(0.03, 0.04, 0.6),
                    s(-0.03, 0.04, 0.6),
                    s(0.02, 0.08, 0.55, lav),
                    s(-0.02, 0.08, 0.55),
                ],
                edges: [(0, 1), (0, 2), (1, 3), (2, 4), (3, 4)]
            ),
            // Crux — Southern Cross
            ConstellationTemplate(
                stars: [
                    s(0.03, 0.00, 0.85, cool),
                    s(0.03, 0.08, 0.8, warm),
                    s(0.00, 0.04, 0.7),
                    s(0.06, 0.04, 0.7, lav),
                ],
                edges: [(0, 1), (2, 3)]
            ),
        ]
    }

    private func scheduleConstellations() {
        // Schedule initial wave + recurring
        Task { @MainActor in
            var nextTime: Double = 2.0
            var poolIndex = 0
            let minDistance: CGFloat = 0.25

            while true {
                let template = constellationPool[poolIndex % constellationPool.count]

                // Find a position that doesn't overlap with active constellations
                var ox: CGFloat = 0
                var oy: CGFloat = 0
                var attempts = 0

                repeat {
                    ox = CGFloat.random(in: 0.05...0.75)
                    oy = CGFloat.random(in: 0.02...0.45)
                    attempts += 1
                } while attempts < 20 && activeConstellations.contains(where: { ac in
                    let dx = ac.offsetX - ox
                    let dy = ac.offsetY - oy
                    return sqrt(dx * dx + dy * dy) < minDistance
                })

                let lifetime = Double.random(in: 10...16)
                let actualElapsed = Date.now.timeIntervalSince(startTime)

                let ac = ActiveConstellation(
                    template: template,
                    offsetX: ox,
                    offsetY: oy,
                    appearTime: actualElapsed,
                    lifetime: lifetime
                )
                activeConstellations.append(ac)

                poolIndex += 1
                let waitUntilNext = Double.random(in: 4...7)

                try? await Task.sleep(for: .seconds(waitUntilNext))

                let currentElapsed = Date.now.timeIntervalSince(startTime)

                // Promote constellations that are past their lifetime (lines gone) but still active
                let readyToPromote = activeConstellations.filter {
                    let age = currentElapsed - $0.appearTime
                    return age > $0.lifetime + 1 && !$0.promoted
                }
                for ac in readyToPromote {
                    // Mark as promoted so we don't double-add
                    if let idx = activeConstellations.firstIndex(where: { $0.appearTime == ac.appearTime && !$0.promoted }) {
                        activeConstellations[idx].promoted = true
                    }

                    let group = PromotedStarGroup(
                        stars: ac.template.stars,
                        offsetX: ac.offsetX,
                        offsetY: ac.offsetY
                    )
                    promotedGroups.append(group)

                    // If over 15, fade out and remove the oldest
                    if promotedGroups.count > 15 {
                        let fadeIndex = 0
                        Task { @MainActor in
                            // Fade out over 2 seconds
                            let steps = 20
                            for i in 1...steps {
                                try? await Task.sleep(for: .milliseconds(100))
                                if fadeIndex < promotedGroups.count {
                                    promotedGroups[fadeIndex].opacity = 1.0 - (Double(i) / Double(steps))
                                }
                            }
                            if !promotedGroups.isEmpty {
                                promotedGroups.removeFirst()
                            }
                        }
                    }
                }

                // Remove active constellations well after promotion
                activeConstellations.removeAll { currentElapsed - $0.appearTime > $0.lifetime + 3 }
            }
        }
    }

    private func scheduleShootingStars() {
        Task { @MainActor in
            // First one after 5-8 seconds
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

                // Next one in 8-20 seconds — rare enough to feel special
                try? await Task.sleep(for: .seconds(Double.random(in: 8...20)))
            }
        }
    }
}

// MARK: - Models

private struct FieldStar {
    let x: CGFloat
    let y: CGFloat
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

private struct ConstellationStar {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let speed: Double
    let phase: Double
    let color: Color
}

private struct ConstellationTemplate {
    let stars: [ConstellationStar]
    let edges: [(Int, Int)]
}

private struct ActiveConstellation {
    let template: ConstellationTemplate
    let offsetX: CGFloat
    let offsetY: CGFloat
    let appearTime: Double
    let lifetime: Double
    var promoted = false
}

private struct PromotedStarGroup {
    let stars: [ConstellationStar]
    let offsetX: CGFloat
    let offsetY: CGFloat
    var opacity: Double = 1.0
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

#Preview("Night Sky") {
    NightSkyBackground()
}

#Preview("With Logo") {
    ZStack {
        NightSkyBackground()

        Text("alarmio")
            .font(.system(size: 52, weight: .black, design: .rounded))
            .foregroundStyle(.white)
    }
}
