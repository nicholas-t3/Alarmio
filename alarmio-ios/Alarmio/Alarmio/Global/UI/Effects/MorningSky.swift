//
//  MorningSky.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

enum ShootingStarFrequency: Sendable {
    case sparse      // Default — 8–20s between shots
    case frequent    // 3–8s between shots
    case intense     // 1–4s between shots

    var delayRange: ClosedRange<Double> {
        switch self {
        case .sparse: return 8...20
        case .frequent: return 3...8
        case .intense: return 1...4
        }
    }

    var initialDelay: ClosedRange<Double> {
        switch self {
        case .sparse: return 5...8
        case .frequent: return 2...4
        case .intense: return 0.5...1.5
        }
    }
}

struct MorningSky: View {

    // MARK: - State
    var starOpacity: Double = 1.0
    var showConstellations: Bool = true
    var shootingStarFrequency: ShootingStarFrequency = .sparse

    /// 0 = default pre-dawn glow, 1 = full sunrise (brighter, warmer, stars washed out)
    var sunriseProgress: Double = 0
    /// 0 = normal rotation, 1 = full speed spin + trails (independent of sunrise)
    var starSpinProgress: Double = 0

    // MARK: - Body
    var body: some View {
        let glow = sunriseProgress

        ZStack {

            // Sky gradient — night at top, pre-dawn warmth at bottom
            // As sunrise progresses, the warm tones push higher
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "020810"), location: 0),
                    .init(color: Color(hex: "060e1c"), location: 0.25 - glow * 0.05),
                    .init(color: Color(hex: "0a1628"), location: 0.45 - glow * 0.08),
                    .init(color: Color(hex: "111d35"), location: 0.60 - glow * 0.10),
                    .init(color: Color(hex: "1a1a3e"), location: 0.72 - glow * 0.10),
                    .init(color: Color(hex: "2d1b3d"), location: 0.82 - glow * 0.08),
                    .init(color: Color(hex: "4a1942"), location: 0.90 - glow * 0.06),
                    .init(color: Color(hex: "6b2040"), location: 0.96 - glow * 0.04),
                    .init(color: Color(hex: "8b3a2a"), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Rotating star canvas — spin and trails driven by starSpinProgress
            MorningStarCanvas(
                showConstellations: showConstellations,
                shootingStarFrequency: starSpinProgress > 0.05 ? .intense : shootingStarFrequency,
                rotationSpeedMultiplier: 1.0 + starSpinProgress * 14.0,
                trailProgress: starSpinProgress
            )
                .opacity(starOpacity * (1.0 + starSpinProgress * 0.5))
                .mask(starFadeMask)

            // Sunrise glow layers — intensity scales with sunriseProgress
            GeometryReader { geometry in
                let h = geometry.size.height

                // Core glow — deep orange/amber from the horizon
                RadialGradient(
                    stops: [
                        .init(color: Color(hex: "CC6A20").opacity(0.55 + glow * 0.20), location: 0),
                        .init(color: Color(hex: "B0503A").opacity(0.40 + glow * 0.15), location: 0.25),
                        .init(color: Color(hex: "7A3050").opacity(0.25 + glow * 0.12), location: 0.50),
                        .init(color: .clear, location: 1.0)
                    ],
                    center: .init(x: 0.5, y: 1.05 - glow * 0.12),
                    startRadius: 0,
                    endRadius: h * (0.55 + glow * 0.20)
                )
                .ignoresSafeArea()

                // Warm peach haze
                RadialGradient(
                    stops: [
                        .init(color: Color(hex: "E8976B").opacity(0.20 + glow * 0.15), location: 0),
                        .init(color: Color(hex: "D4755A").opacity(0.12 + glow * 0.10), location: 0.35),
                        .init(color: .clear, location: 1.0)
                    ],
                    center: .init(x: 0.5, y: 1.15 - glow * 0.15),
                    startRadius: 0,
                    endRadius: h * (0.70 + glow * 0.15)
                )
                .ignoresSafeArea()

                // Amber wash — subtle fill from bottom
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: max(0.45, 0.80 - glow * 0.20)),
                        .init(color: Color(hex: "D4854A").opacity(0.15 + glow * 0.15), location: max(0.55, 0.92 - glow * 0.15)),
                        .init(color: Color(hex: "E8A060").opacity(0.25 + glow * 0.20), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Golden light wash
                if glow > 0.2 {
                    RadialGradient(
                        stops: [
                            .init(color: Color(hex: "FFD4A0").opacity(glow * 0.12), location: 0),
                            .init(color: Color(hex: "FFAA60").opacity(glow * 0.06), location: 0.4),
                            .init(color: .clear, location: 1.0)
                        ],
                        center: .init(x: 0.5, y: 0.90 - glow * 0.12),
                        startRadius: 0,
                        endRadius: h * (0.45 + glow * 0.15)
                    )
                    .ignoresSafeArea()
                }

                // Sunburst rays — light shafts radiating upward from horizon
                if glow > 0.03 {
                    SunburstRays(progress: glow)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: sunriseProgress)
    }

    // MARK: - Subviews

    /// Fades stars out toward the bottom so the sunrise washes them away naturally
    private var starFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: 0.55),
                .init(color: .white.opacity(0.5), location: 0.75),
                .init(color: .white.opacity(0.15), location: 0.90),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Sunburst Rays

private struct SunburstRays: View {

    var progress: Double

    @State private var rays: [SunburstRay] = []
    @State private var startTime: Date = .now

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startTime)

            Canvas { context, size in
                drawRays(context: &context, size: size, elapsed: elapsed)
            }
        }
        .onAppear {
            startTime = .now
            generateRays()
        }
    }

    // MARK: - Private Methods

    private func drawRays(context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        let cx = size.width * 0.5
        let originY = size.height + 20
        let p = progress

        var ac = context
        ac.blendMode = .plusLighter

        for ray in rays {
            drawAngledBeam(context: &ac, ray: ray, cx: cx, originY: originY, size: size, elapsed: elapsed, p: p)
        }
    }

    private func drawAngledBeam(context: inout GraphicsContext, ray: SunburstRay, cx: CGFloat, originY: CGFloat, size: CGSize, elapsed: Double, p: Double) {
        let wave = sin(elapsed * ray.speed + ray.phase)
        let pulse = (wave * 0.5 + 0.5)
        let alpha = p * ray.brightness * (0.3 + pulse * 0.7)
        guard alpha > 0.01 else { return }

        let sway = sin(elapsed * ray.swaySpeed + ray.phase) * ray.swayAmount
        let angle = ray.angle + sway
        let length = size.height * ray.lengthScale * (0.3 + p * 0.15)

        let cosA = cos(angle)
        let sinA = sin(angle)
        let endX = cx + cosA * length
        let endY = originY + sinA * length

        // Wide dim glow
        drawBeamLine(context: &context, x1: cx, y1: originY, x2: endX, y2: endY, width: ray.width * size.width * 6, color: ray.dimColor, opacity: alpha * 0.15)

        // Mid glow
        drawBeamLine(context: &context, x1: cx, y1: originY, x2: endX, y2: endY, width: ray.width * size.width * 2.5, color: ray.coreColor, opacity: alpha * 0.3)

        // Bright core
        drawBeamLine(context: &context, x1: cx, y1: originY, x2: endX, y2: endY, width: max(ray.width * size.width * 0.6, 1.5), color: ray.brightColor, opacity: alpha * 0.6)
    }

    private func drawBeamLine(context: inout GraphicsContext, x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat, width: CGFloat, color: Color, opacity: Double) {
        var path = Path()
        path.move(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x2, y: y2))

        context.opacity = opacity
        context.stroke(path, with: .linearGradient(
            Gradient(colors: [color, color.opacity(0.3), .clear]),
            startPoint: CGPoint(x: x1, y: y1),
            endPoint: CGPoint(x: x2, y: y2)
        ), lineWidth: width)
    }

    private func generateRays() {
        let rayCount = 12
        rays = (0..<rayCount).map { i in
            let base = Double(i) / Double(rayCount - 1)
            // Fan upward from bottom center: -150° to -30°
            let spreadAngle = -Double.pi * (5.0 / 6.0) + base * Double.pi * (4.0 / 6.0)
            let jitter = Double.random(in: -0.05...0.05)

            return SunburstRay(
                angle: spreadAngle + jitter,
                width: CGFloat.random(in: 0.003...0.015),
                lengthScale: Double.random(in: 0.5...0.9),
                brightness: Double.random(in: 0.15...0.5),
                speed: Double.random(in: 0.3...1.0),
                phase: Double.random(in: 0...(.pi * 2)),
                swayAmount: Double.random(in: 0.01...0.04),
                swaySpeed: Double.random(in: 0.15...0.5),
                coreColor: [Color(hex: "FFCC80"), Color(hex: "FFB860"), Color(hex: "FFA050")].randomElement()!,
                brightColor: [Color(hex: "FFE0B0"), Color(hex: "FFD4A0"), Color(hex: "FFFAF0")].randomElement()!,
                dimColor: [Color(hex: "CC6A20"), Color(hex: "B0503A"), Color(hex: "DF9A1B")].randomElement()!
            )
        }
    }
}

private struct SunburstRay {
    let angle: Double
    let width: CGFloat
    let lengthScale: Double
    let brightness: Double
    let speed: Double
    let phase: Double
    let swayAmount: Double
    let swaySpeed: Double
    let coreColor: Color
    let brightColor: Color
    let dimColor: Color
}

// MARK: - Morning Star Canvas

private struct MorningStarCanvas: View {

    // MARK: - Constants
    var showConstellations: Bool = true
    var shootingStarFrequency: ShootingStarFrequency = .sparse
    var rotationSpeedMultiplier: Double = 1.0
    /// 0 = dots only, 1 = full long-exposure trails
    var trailProgress: Double = 0

    // MARK: - State
    @State private var stars: [MorningFieldStar] = []
    @State private var shootingStars: [MorningShootingStar] = []
    @State private var activeConstellations: [MorningActiveConstellation] = []
    @State private var startTime: Date = .now
    @State private var needsGeneration = true
    @State private var screenSize: CGSize = .zero
    @State private var accumulatedAngle: Double = 0
    @State private var lastFrameTime: Date? = nil

    // MARK: - Constants
    private let baseRotationPeriod: Double = 600
    private let starCount = 1800
    private let clusterRadius: CGFloat = 120
    private let constellationStarRange = 4...7

    // MARK: - Body
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let elapsed = timeline.date.timeIntervalSince(startTime)

            // Accumulate angle smoothly — speed changes don't cause jumps
            let currentTime = timeline.date
            let frameAngle: Double = {
                let dt: Double
                if let last = lastFrameTime {
                    dt = min(currentTime.timeIntervalSince(last), 0.1)
                } else {
                    dt = 0
                }
                let vel = (2 * .pi / baseRotationPeriod) * rotationSpeedMultiplier
                return accumulatedAngle + vel * dt
            }()
            let cosA = cos(frameAngle)
            let sinA = sin(frameAngle)

            // Trail: compute a previous angle to draw arcs from
            let trailAngleSpan = trailProgress * 0.06
            let trailSteps = trailProgress > 0.01 ? 6 : 0

            Canvas { context, size in
                if needsGeneration {
                    DispatchQueue.main.async {
                        screenSize = size
                        generateStars(size: size)
                        needsGeneration = false
                        if showConstellations {
                            scheduleConstellations()
                        }
                    }
                    return
                }

                let fadeIn = min(elapsed / 2.0, 1.0)
                let w = size.width
                let h = size.height
                let cx = w / 2
                let cy = h / 2

                // Rotating star field with long-exposure trails
                for star in stars {
                    let rx = cx + star.dx * cosA - star.dy * sinA
                    let ry = cy + star.dx * sinA + star.dy * cosA

                    guard rx > -20 && rx < w + 20 && ry > -20 && ry < h + 20 else { continue }

                    let slowWave = sin(now * star.speed + star.phase)
                    var brightness = star.baseOpacity + (slowWave + 1) / 2 * star.twinkleRange

                    for ac in activeConstellations where ac.starIndices.contains(star.id) {
                        let cElapsed = elapsed - ac.appearTime
                        let boostIn = min(cElapsed / 1.0, 1.0)
                        let boostOut = cElapsed > ac.lifetime - 1.5
                            ? max(0, 1.0 - (cElapsed - (ac.lifetime - 1.5)) / 1.5)
                            : 1.0
                        let boost = boostIn * boostOut
                        brightness = min(1.0, brightness + 0.35 * boost)
                    }

                    // Long-exposure trail — arc behind the star's rotation path
                    if trailSteps > 0 && brightness > 0.15 {
                        var trail = Path()
                        trail.move(to: CGPoint(x: rx, y: ry))

                        for step in 1...trailSteps {
                            let t = Double(step) / Double(trailSteps)
                            let pastAngle = frameAngle - trailAngleSpan * t
                            let pastCos = cos(pastAngle)
                            let pastSin = sin(pastAngle)
                            let px = cx + star.dx * pastCos - star.dy * pastSin
                            let py = cy + star.dx * pastSin + star.dy * pastCos
                            trail.addLine(to: CGPoint(x: px, y: py))
                        }

                        let trailAlpha = fadeIn * brightness * trailProgress * 0.5
                        context.opacity = trailAlpha
                        context.stroke(
                            trail,
                            with: .linearGradient(
                                Gradient(colors: [star.color.opacity(0.6), .clear]),
                                startPoint: CGPoint(x: rx, y: ry),
                                endPoint: trail.currentPoint ?? CGPoint(x: rx, y: ry)
                            ),
                            lineWidth: star.radius * (1.0 + trailProgress * 1.5)
                        )
                    }

                    let flareWave = sin(now * star.flareSpeed + star.flarePhase)
                    if flareWave > 0.92 {
                        let flareIntensity = (flareWave - 0.92) / 0.08
                        brightness = min(1.0, brightness + flareIntensity * star.flareStrength)

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

                // Constellation lines
                for ac in activeConstellations {
                    let cElapsed = elapsed - ac.appearTime
                    guard cElapsed > 0 && cElapsed < ac.lifetime + 2 else { continue }

                    let drawPhase = 2.5
                    let fadeOutStart = ac.lifetime - 1.5

                    let lineOpacity: Double
                    if cElapsed > fadeOutStart + 1.5 {
                        lineOpacity = 0
                    } else if cElapsed < drawPhase {
                        lineOpacity = min(cElapsed / 1.0, 1.0)
                    } else if cElapsed > fadeOutStart {
                        lineOpacity = max(0, 1.0 - (cElapsed - fadeOutStart) / 1.5)
                    } else {
                        lineOpacity = 1.0
                    }

                    let edgeCount = Double(ac.edges.count)
                    for (i, edge) in ac.edges.enumerated() {
                        let edgeStart = (Double(i) / edgeCount) * drawPhase
                        let edgeDur = drawPhase / edgeCount
                        let progress = max(0, min(1, (cElapsed - edgeStart) / edgeDur))
                        guard progress > 0 else { continue }

                        let fromStar = stars[edge.0]
                        let toStar = stars[edge.1]

                        let p1 = CGPoint(
                            x: cx + fromStar.dx * cosA - fromStar.dy * sinA,
                            y: cy + fromStar.dx * sinA + fromStar.dy * cosA
                        )
                        let p2Full = CGPoint(
                            x: cx + toStar.dx * cosA - toStar.dy * sinA,
                            y: cy + toStar.dx * sinA + toStar.dy * cosA
                        )
                        let p2 = CGPoint(
                            x: p1.x + (p2Full.x - p1.x) * progress,
                            y: p1.y + (p2Full.y - p1.y) * progress
                        )

                        var path = Path()
                        path.move(to: p1)
                        path.addLine(to: p2)

                        context.opacity = lineOpacity * 0.18 * progress
                        context.stroke(path, with: .color(.white), lineWidth: 0.5)
                    }
                }

                // Shooting stars
                for star in shootingStars {
                    let sElapsed = elapsed - star.startTime
                    guard sElapsed > 0 && sElapsed < star.duration else { continue }

                    let progress = sElapsed / star.duration

                    let headX = star.startX + (star.endX - star.startX) * progress
                    let headY = star.startY + (star.endY - star.startY) * progress

                    let tailProgress = max(0, progress - star.tailLength)
                    let tailX = star.startX + (star.endX - star.startX) * tailProgress
                    let tailY = star.startY + (star.endY - star.startY) * tailProgress

                    let headPt = CGPoint(x: headX * w, y: headY * h)
                    let tailPt = CGPoint(x: tailX * w, y: tailY * h)

                    let fadeInS = min(progress / 0.1, 1.0)
                    let fadeOut = max(0, 1.0 - (progress - 0.7) / 0.3)
                    let opacity = min(fadeInS, fadeOut) * star.brightness

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

                    let headRect = CGRect(x: headPt.x - 1, y: headPt.y - 1, width: 2, height: 2)
                    context.opacity = opacity
                    context.fill(Circle().path(in: headRect), with: .color(.white))
                }
            }
            .onChange(of: timeline.date) {
                let ct = timeline.date
                if let last = lastFrameTime {
                    let dt = min(ct.timeIntervalSince(last), 0.1)
                    let vel = (2 * .pi / baseRotationPeriod) * rotationSpeedMultiplier
                    accumulatedAngle += vel * dt
                }
                lastFrameTime = ct
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startTime = .now
            lastFrameTime = .now
            scheduleShootingStars()
        }
    }

    // MARK: - Private Methods

    private func generateStars(size: CGSize) {
        let colors: [Color] = [.white, Color(hex: "E8DFF5"), Color(hex: "FFF4E0"), Color(hex: "D4E5FF")]

        let halfDiag = sqrt(size.width * size.width + size.height * size.height) / 2
        let maxRadius = halfDiag * 1.1

        stars = (0..<starCount).map { index in
            let isBright = Double.random(in: 0...1) > 0.82

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let dist = maxRadius * sqrt(CGFloat.random(in: 0...1))
            let dx = cos(angle) * dist
            let dy = sin(angle) * dist

            return MorningFieldStar(
                id: index,
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
                color: isBright ? colors.randomElement()! : .white,
                isBright: isBright
            )
        }
    }

    private func findConstellation(cosA: Double, sinA: Double) -> MorningActiveConstellation? {
        let w = screenSize.width
        let h = screenSize.height
        let cx = w / 2
        let cy = h / 2
        let margin: CGFloat = 60

        let usedStars = activeConstellations.reduce(into: Set<Int>()) { $0.formUnion($1.starIndices) }

        var visibleBright: [(index: Int, sx: CGFloat, sy: CGFloat)] = []
        for star in stars where star.isBright && !usedStars.contains(star.id) {
            let sx = cx + star.dx * cosA - star.dy * sinA
            let sy = cy + star.dx * sinA + star.dy * cosA
            if sx > margin && sx < w - margin && sy > margin && sy < h - margin {
                visibleBright.append((star.id, sx, sy))
            }
        }

        guard visibleBright.count >= constellationStarRange.lowerBound else { return nil }

        let centerX = w / 2
        let centerY = h / 2
        let maxDist = sqrt(centerX * centerX + centerY * centerY)

        let weights: [Double] = visibleBright.map { star in
            let ddx = star.sx - centerX
            let ddy = star.sy - centerY
            let dist = sqrt(ddx * ddx + ddy * ddy) / maxDist
            return dist * dist * dist + 0.05
        }
        let totalWeight = weights.reduce(0, +)

        var bestCluster: [(index: Int, sx: CGFloat, sy: CGFloat)] = []

        for _ in 0..<10 {
            var roll = Double.random(in: 0..<totalWeight)
            var seedIndex = 0
            for (i, w) in weights.enumerated() {
                roll -= w
                if roll <= 0 { seedIndex = i; break }
            }
            let seed = visibleBright[seedIndex]

            var cluster = visibleBright.filter { candidate in
                let ddx = candidate.sx - seed.sx
                let ddy = candidate.sy - seed.sy
                return sqrt(ddx * ddx + ddy * ddy) < clusterRadius
            }

            if cluster.count < constellationStarRange.lowerBound { continue }
            if cluster.count > constellationStarRange.upperBound {
                cluster.shuffle()
                cluster = Array(cluster.prefix(constellationStarRange.upperBound))
            }

            if cluster.count > bestCluster.count {
                bestCluster = cluster
            }
        }

        guard bestCluster.count >= constellationStarRange.lowerBound else { return nil }

        let edges = buildMST(cluster: bestCluster)
        let starIndices = Set(bestCluster.map(\.index))
        let elapsed = Date.now.timeIntervalSince(startTime)

        return MorningActiveConstellation(
            starIndices: starIndices,
            edges: edges,
            appearTime: elapsed,
            lifetime: Double.random(in: 12...18)
        )
    }

    private func buildMST(cluster: [(index: Int, sx: CGFloat, sy: CGFloat)]) -> [(Int, Int)] {
        let n = cluster.count
        guard n >= 2 else { return [] }

        var inTree = [Bool](repeating: false, count: n)
        var edges: [(Int, Int)] = []
        inTree[0] = true
        var treeCount = 1

        while treeCount < n {
            var bestDist: CGFloat = .greatestFiniteMagnitude
            var bestFrom = 0
            var bestTo = 0

            for i in 0..<n where inTree[i] {
                for j in 0..<n where !inTree[j] {
                    let ddx = cluster[i].sx - cluster[j].sx
                    let ddy = cluster[i].sy - cluster[j].sy
                    let dist = ddx * ddx + ddy * ddy
                    if dist < bestDist {
                        bestDist = dist
                        bestFrom = i
                        bestTo = j
                    }
                }
            }

            inTree[bestTo] = true
            treeCount += 1
            edges.append((cluster[bestFrom].index, cluster[bestTo].index))
        }

        if n >= 5 && Double.random(in: 0...1) > 0.4 {
            let extras = Int.random(in: 1...min(2, n - 1))
            for _ in 0..<extras {
                let i = Int.random(in: 0..<n)
                var j = Int.random(in: 0..<n)
                while j == i { j = Int.random(in: 0..<n) }

                let pair = (cluster[i].index, cluster[j].index)
                let reversePair = (cluster[j].index, cluster[i].index)
                if !edges.contains(where: { $0 == pair || $0 == reversePair }) {
                    let ddx = cluster[i].sx - cluster[j].sx
                    let ddy = cluster[i].sy - cluster[j].sy
                    let dist = sqrt(ddx * ddx + ddy * ddy)
                    if dist < clusterRadius * 0.8 {
                        edges.append(pair)
                    }
                }
            }
        }

        return edges
    }

    private func scheduleConstellations() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))

            while true {
                let currentElapsed = Date.now.timeIntervalSince(startTime)
                activeConstellations.removeAll { currentElapsed - $0.appearTime > $0.lifetime + 2 }

                if activeConstellations.count < 2 {
                    let cosA = cos(accumulatedAngle)
                    let sinA = sin(accumulatedAngle)

                    if let constellation = findConstellation(cosA: cosA, sinA: sinA) {
                        activeConstellations.append(constellation)
                    }
                }

                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }

    private func scheduleShootingStars() {
        Task { @MainActor in
            let freq = shootingStarFrequency
            try? await Task.sleep(for: .seconds(Double.random(in: freq.initialDelay)))

            while true {
                let startX = CGFloat.random(in: 0.05...0.7)
                let startY = CGFloat.random(in: 0.02...0.35)
                let angle = Double.random(in: 0.3...0.7)
                let length = CGFloat.random(in: 0.25...0.50)

                let ss = MorningShootingStar(
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

                let currentElapsed = Date.now.timeIntervalSince(startTime)
                shootingStars.removeAll { currentElapsed - $0.startTime > $0.duration + 1 }

                try? await Task.sleep(for: .seconds(Double.random(in: freq.delayRange)))
            }
        }
    }
}

// MARK: - Models

private struct MorningFieldStar {
    let id: Int
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
    let isBright: Bool
}

private struct MorningActiveConstellation {
    let starIndices: Set<Int>
    let edges: [(Int, Int)]
    let appearTime: Double
    let lifetime: Double
}

private struct MorningShootingStar {
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

#Preview("Morning Sky") {
    MorningSky()
}

#Preview("Morning Sky — with text") {
    ZStack {
        MorningSky()

        Text("alarmio")
            .font(.system(size: 52, weight: .black, design: .rounded))
            .foregroundStyle(.white)
    }
}

#Preview("Morning Sky — Loading") {
    ZStack {
        MorningSky(
            starOpacity: 0.3,
            showConstellations: false,
            sunriseProgress: 0.5,
            starSpinProgress: 1.0
        )

//        Text("Generating")
//            .font(.system(size: 28, weight: .light, design: .rounded))
//            .foregroundStyle(.white)
//            .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 0)
    }
}

#Preview("Side by Side") {
    HStack(spacing: 0) {
        RotatingNightSky()
        MorningSky()
    }
}
