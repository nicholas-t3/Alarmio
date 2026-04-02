//
//  VoiceVisualizer.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

// MARK: - Public Palette

struct VisualizerPalette: Equatable {
    let core: Color
    let bright: Color
    let mid: Color
    let dim: Color

    static let blue = VisualizerPalette(
        core: Color(hex: "4A9EFF"),
        bright: Color(hex: "D4EDFF"),
        mid: Color(hex: "1B6FDF"),
        dim: Color(hex: "0D3870")
    )

    static let red = VisualizerPalette(
        core: Color(hex: "FF4A6A"),
        bright: Color(hex: "FFD4DE"),
        mid: Color(hex: "DF1B4A"),
        dim: Color(hex: "700D25")
    )

    static let green = VisualizerPalette(
        core: Color(hex: "4AFF8E"),
        bright: Color(hex: "D4FFE0"),
        mid: Color(hex: "1BDF60"),
        dim: Color(hex: "0D7035")
    )

    static let purple = VisualizerPalette(
        core: Color(hex: "9B59FF"),
        bright: Color(hex: "DDD4FF"),
        mid: Color(hex: "7B3FDF"),
        dim: Color(hex: "3D0D70")
    )

    static let gold = VisualizerPalette(
        core: Color(hex: "FFB84A"),
        bright: Color(hex: "FFECD4"),
        mid: Color(hex: "DF9A1B"),
        dim: Color(hex: "70500D")
    )
}

// MARK: - Voice Visualizer

struct VoiceVisualizer: View {

    // MARK: - Input
    var palette: VisualizerPalette
    var isPlaying: Bool

    // MARK: - State
    @State private var backLines: [LineStrip] = []
    @State private var midBeams: [LiveBeam] = []
    @State private var frontStreaks: [LineStrip] = []
    @State private var startTime: Date = .now
    @State private var energy: Double = 0.0
    @State private var targetEnergy: Double = 0.0
    @State private var previousPalette: VisualizerPalette?
    @State private var paletteProgress: Double = 1.0
    @State private var activeMode: Bool = false

    // MARK: - Constants
    private let maxMidBeams: Int = 30

    // MARK: - Body
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startTime)

            Canvas { context, size in
                drawBackground(context: &context, size: size)
                drawBackLayer(context: &context, size: size, elapsed: elapsed, energy: energy)
                drawMidLayer(context: &context, size: size, elapsed: elapsed)
                drawFrontLayer(context: &context, size: size, elapsed: elapsed, energy: energy)
                drawDepthFog(context: &context, size: size)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startTime = .now
            activeMode = isPlaying
            previousPalette = palette
            generateBackLines()
            generateFrontStreaks()
            startSimulation()
        }
        .onChange(of: isPlaying) {
            print("[VoiceVisualizer] isPlaying changed to: \(isPlaying)")
            activeMode = isPlaying

            if isPlaying {
                // Immediately light up — don't wait for the simulation loop
                targetEnergy = 1.0
                energy = 0.8
                for _ in 0..<5 {
                    if midBeams.count >= maxMidBeams {
                        midBeams.removeFirst()
                    }
                    midBeams.append(makeMidBeam(energy: 0.9))
                }
            }
        }
        .onChange(of: palette) { oldValue, newValue in
            previousPalette = oldValue
            paletteProgress = 0.0
            animatePaletteTransition()
        }
    }

    // MARK: - Setup

    private func generateBackLines() {
        backLines = (0..<50).map { _ in
            LineStrip(
                baseX: Double.random(in: 0...1),
                width: Double.random(in: 0.002...0.012),
                brightness: Double.random(in: 0.08...0.35),
                speed: Double.random(in: 0.3...0.8),
                phase: Double.random(in: 0...(.pi * 2)),
                depth: Double.random(in: 0...0.3),
                swayAmount: Double.random(in: 0.005...0.025),
                swaySpeed: Double.random(in: 0.2...0.7)
            )
        }
    }

    private func generateFrontStreaks() {
        frontStreaks = (0..<6).map { _ in
            LineStrip(
                baseX: Double.random(in: -0.1...1.1),
                width: Double.random(in: 0.02...0.07),
                brightness: Double.random(in: 0.15...0.45),
                speed: Double.random(in: 0.1...0.4),
                phase: Double.random(in: 0...(.pi * 2)),
                depth: Double.random(in: 0.8...1.0),
                swayAmount: Double.random(in: 0.015...0.06),
                swaySpeed: Double.random(in: 0.08...0.25)
            )
        }
    }

    // MARK: - Simulation

    private func startSimulation() {
        Task { @MainActor in
            while true {
                if activeMode {
                    // Active: simulate voice phrases with random bursts
                    let phraseLength = Int.random(in: 4...10)

                    for syllable in 0..<phraseLength {
                        guard activeMode else { break }

                        let phraseProg = Double(syllable) / Double(phraseLength)
                        let intensity: Double
                        if phraseProg < 0.2 {
                            intensity = 0.3 + phraseProg * 3.0
                        } else if phraseProg > 0.75 {
                            let tail = (phraseProg - 0.75) / 0.25
                            intensity = 0.9 - tail * 0.5
                        } else {
                            intensity = Double.random(in: 0.6...1.0)
                        }

                        targetEnergy = intensity

                        let count = Int.random(in: 2...4)
                        for _ in 0..<count {
                            if midBeams.count >= maxMidBeams {
                                midBeams.removeFirst()
                            }
                            midBeams.append(makeMidBeam(energy: intensity))
                        }

                        let gap = Int.random(in: 80...250)
                        try? await Task.sleep(for: .milliseconds(gap))
                    }

                    // Brief pause between phrases
                    targetEnergy = Double.random(in: 0.2...0.4)
                    let pause = Int.random(in: 150...400)
                    try? await Task.sleep(for: .milliseconds(pause))
                } else {
                    // Resting: low energy, occasional dim shimmer beam
                    targetEnergy = Double.random(in: 0.0...0.08)

                    if Double.random(in: 0...1) > 0.5 {
                        if midBeams.count >= maxMidBeams {
                            midBeams.removeFirst()
                        }
                        midBeams.append(makeMidBeam(energy: 0.1))
                    }

                    try? await Task.sleep(for: .milliseconds(Int.random(in: 600...1500)))
                }

                // Smooth energy + prune
                energy += (targetEnergy - energy) * 0.15
                let now = Date.now.timeIntervalSince(startTime)
                midBeams.removeAll { now - $0.spawnTime > $0.lifetime }
            }
        }

        // Separate smoothing loop so energy stays fluid between spawns
        Task { @MainActor in
            while true {
                energy += (targetEnergy - energy) * 0.12
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    private func makeMidBeam(energy: Double) -> LiveBeam {
        let now = Date.now.timeIntervalSince(startTime)
        return LiveBeam(
            xPosition: Double.random(in: 0.05...0.95),
            width: Double.random(in: 0.006...0.025) * (0.5 + energy * 0.5),
            brightness: Double.random(in: 0.4...1.0) * max(energy, 0.15),
            spawnTime: now,
            lifetime: Double.random(in: 0.8...2.5),
            fadeInDuration: Double.random(in: 0.1...0.3),
            swayAmount: Double.random(in: 0.003...0.015),
            swaySpeed: Double.random(in: 0.5...1.5),
            swayPhase: Double.random(in: 0...(.pi * 2))
        )
    }

    // MARK: - Palette Transition

    private func animatePaletteTransition() {
        Task { @MainActor in
            let steps = 40
            for i in 1...steps {
                try? await Task.sleep(for: .milliseconds(15))
                let t = Double(i) / Double(steps)
                paletteProgress = t * t * (3.0 - 2.0 * t)
            }
            paletteProgress = 1.0
            previousPalette = palette
        }
    }

    private func currentColor(_ keyPath: KeyPath<VisualizerPalette, Color>) -> Color {
        guard let prev = previousPalette, paletteProgress < 1.0 else {
            return palette[keyPath: keyPath]
        }
        let from = prev[keyPath: keyPath]
        let to = palette[keyPath: keyPath]
        let fc = UIColor(from).rgbaComponents
        let tc = UIColor(to).rgbaComponents
        let p = paletteProgress
        let r = fc.r + (tc.r - fc.r) * p
        let g = fc.g + (tc.g - fc.g) * p
        let b = fc.b + (tc.b - fc.b) * p
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    // MARK: - Drawing

    private func drawBackground(context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Rectangle().path(in: rect), with: .color(Color(hex: "020206")))
    }

    private func drawBackLayer(
        context: inout GraphicsContext,
        size: CGSize,
        elapsed: Double,
        energy: Double
    ) {
        let dim = currentColor(\.dim)
        let mid = currentColor(\.mid)

        var ac = context
        ac.blendMode = .plusLighter

        let energyBoost = 0.5 + energy * 0.5

        for line in backLines {
            let pulse = sin(elapsed * line.speed + line.phase) * 0.3 + 0.7
            let alpha = line.brightness * pulse * energyBoost

            let sway = sin(elapsed * line.swaySpeed + line.phase) * line.swayAmount
            let swayX = line.baseX + sway

            let cx = perspectiveX(normalizedX: swayX, depth: line.depth, screenWidth: size.width)
            let w = line.width * size.width

            drawVerticalLine(context: &ac, cx: cx, width: max(w * 5, 6), size: size, color: dim, opacity: alpha * 0.3)
            drawVerticalLine(context: &ac, cx: cx, width: max(w, 1), size: size, color: mid, opacity: alpha * 0.7)
        }
    }

    private func drawMidLayer(
        context: inout GraphicsContext,
        size: CGSize,
        elapsed: Double
    ) {
        let core = currentColor(\.core)
        let bright = currentColor(\.bright)

        var ac = context
        ac.blendMode = .plusLighter

        for beam in midBeams {
            let age = elapsed - beam.spawnTime
            guard age >= 0 && age < beam.lifetime else { continue }

            let lifeProgress = age / beam.lifetime
            let envelope = sin(lifeProgress * .pi)
            let fadeIn = min(age / beam.fadeInDuration, 1.0)
            let alpha = fadeIn * envelope * beam.brightness
            guard alpha > 0.01 else { continue }

            let sway = sin(elapsed * beam.swaySpeed + beam.swayPhase) * beam.swayAmount
            let cx = (beam.xPosition + sway) * size.width
            let w = beam.width * size.width

            drawVerticalLine(context: &ac, cx: cx, width: max(w * 10, 20), size: size, color: core, opacity: alpha * 0.15)
            drawVerticalLine(context: &ac, cx: cx, width: max(w * 4, 10), size: size, color: core, opacity: alpha * 0.35)
            drawVerticalLine(context: &ac, cx: cx, width: max(w * 1.5, 3), size: size, color: bright, opacity: alpha * 0.85)
            drawVerticalLine(context: &ac, cx: cx, width: max(w * 0.4, 1.2), size: size, color: .white, opacity: min(alpha * 1.2, 1.0))
        }
    }

    private func drawFrontLayer(
        context: inout GraphicsContext,
        size: CGSize,
        elapsed: Double,
        energy: Double
    ) {
        let core = currentColor(\.core)
        let bright = currentColor(\.bright)

        var ac = context
        ac.blendMode = .plusLighter

        let energyBoost = 0.4 + energy * 0.6

        for streak in frontStreaks {
            let sway = sin(elapsed * streak.swaySpeed + streak.phase) * streak.swayAmount
            let pulse = sin(elapsed * streak.speed + streak.phase) * 0.5 + 0.5
            let alpha = streak.brightness * (0.3 + pulse * 0.7) * energyBoost

            let cx = (streak.baseX + sway) * size.width
            let w = streak.width * size.width

            drawVerticalLine(context: &ac, cx: cx, width: w * 6, size: size, color: core, opacity: alpha * 0.08)
            drawVerticalLine(context: &ac, cx: cx, width: w * 2.5, size: size, color: bright, opacity: alpha * 0.15)
            drawVerticalLine(context: &ac, cx: cx, width: max(w * 0.5, 2), size: size, color: .white, opacity: alpha * 0.3)
        }
    }

    private func drawVerticalLine(
        context: inout GraphicsContext,
        cx: Double,
        width: Double,
        size: CGSize,
        color: Color,
        opacity: Double
    ) {
        let halfW = width / 2
        let rect = CGRect(x: cx - halfW, y: 0, width: width, height: size.height)

        let grad = LinearGradient(
            colors: [
                .clear,
                color.opacity(0.15),
                color.opacity(0.5),
                color,
                color,
                color.opacity(0.5),
                color.opacity(0.15),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        context.opacity = opacity
        context.fill(Rectangle().path(in: rect), with: .style(grad))
    }

    private func perspectiveX(normalizedX: Double, depth: Double, screenWidth: Double) -> Double {
        let centerX = screenWidth * 0.5
        let offset = normalizedX * screenWidth - centerX
        let perspectiveStrength = 0.15 * (1.0 - depth)
        return centerX + offset * (1.0 + perspectiveStrength)
    }

    private func drawDepthFog(context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)

        let topFade = LinearGradient(
            colors: [Color(hex: "020206"), Color(hex: "020206").opacity(0.6), .clear],
            startPoint: .top,
            endPoint: UnitPoint(x: 0.5, y: 0.2)
        )
        context.opacity = 1.0
        context.fill(Rectangle().path(in: rect), with: .style(topFade))

        let bottomFade = LinearGradient(
            colors: [.clear, Color(hex: "020206").opacity(0.7), Color(hex: "020206")],
            startPoint: UnitPoint(x: 0.5, y: 0.6),
            endPoint: UnitPoint(x: 0.5, y: 0.85)
        )
        context.fill(Rectangle().path(in: rect), with: .style(bottomFade))

        let vignette = RadialGradient(
            colors: [.clear, Color(hex: "020206").opacity(0.5)],
            center: .center,
            startRadius: size.width * 0.3,
            endRadius: size.width * 0.85
        )
        context.fill(Rectangle().path(in: rect), with: .style(vignette))
    }
}

// MARK: - Models

private struct LineStrip {
    let baseX: Double
    let width: Double
    let brightness: Double
    let speed: Double
    let phase: Double
    let depth: Double
    let swayAmount: Double
    let swaySpeed: Double
}

private struct LiveBeam {
    let xPosition: Double
    let width: Double
    let brightness: Double
    let spawnTime: Double
    let lifetime: Double
    let fadeInDuration: Double
    let swayAmount: Double
    let swaySpeed: Double
    let swayPhase: Double
}

// MARK: - UIColor Helper

private extension UIColor {
    var rgbaComponents: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}

// MARK: - Previews

#Preview("Idle") {
    VoiceVisualizer(palette: .blue, isPlaying: false)
}

#Preview("Playing") {
    VoiceVisualizer(palette: .red, isPlaying: true)
}
