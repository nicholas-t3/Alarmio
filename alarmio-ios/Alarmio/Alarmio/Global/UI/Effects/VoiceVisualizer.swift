//
//  VoiceVisualizer.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct VoiceVisualizer: View {

    // MARK: - State
    @State private var backLines: [LineStrip] = []
    @State private var midBeams: [LiveBeam] = []
    @State private var frontStreaks: [LineStrip] = []
    @State private var startTime: Date = .now
    @State private var currentColorIndex: Int = 0
    @State private var previousColorIndex: Int = 0
    @State private var colorProgress: Double = 1.0
    @State private var energy: Double = 0.0
    @State private var targetEnergy: Double = 0.0

    // MARK: - Constants
    private let voicePalettes: [VoicePalette] = [
        VoicePalette(
            core: Color(hex: "4A9EFF"),
            bright: Color(hex: "D4EDFF"),
            mid: Color(hex: "1B6FDF"),
            dim: Color(hex: "0D3870"),
            ambient: Color(hex: "061830")
        ),
        VoicePalette(
            core: Color(hex: "FF4A6A"),
            bright: Color(hex: "FFD4DE"),
            mid: Color(hex: "DF1B4A"),
            dim: Color(hex: "700D25"),
            ambient: Color(hex: "300610")
        ),
        VoicePalette(
            core: Color(hex: "4AFF8E"),
            bright: Color(hex: "D4FFE0"),
            mid: Color(hex: "1BDF60"),
            dim: Color(hex: "0D7035"),
            ambient: Color(hex: "063014")
        ),
    ]
    private let maxMidBeams: Int = 16
    private let colorCycleDuration: Double = 6.0

    // MARK: - Body
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startTime)

            Canvas { context, size in
                // Smoothly chase the target energy each frame
                let smoothed = energy + (targetEnergy - energy) * 0.12

                drawBackground(context: &context, size: size)
                drawBackLayer(context: &context, size: size, elapsed: elapsed, energy: smoothed)
                drawMidLayer(context: &context, size: size, elapsed: elapsed, energy: smoothed)
                drawFrontLayer(context: &context, size: size, elapsed: elapsed, energy: smoothed)
                drawDepthFog(context: &context, size: size)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startTime = .now
            generateBackLines()
            generateFrontStreaks()
            startVoiceSimulation()
            startColorCycle()
            startEnergySmoothing()
        }
    }

    // MARK: - Setup

    private func generateBackLines() {
        backLines = (0..<50).map { _ in
            LineStrip(
                xPosition: Double.random(in: 0...1),
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
                xPosition: Double.random(in: -0.1...1.1),
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

    // MARK: - Voice Simulation

    private func startEnergySmoothing() {
        Task { @MainActor in
            while true {
                // Smooth energy toward target ~20x/sec
                energy += (targetEnergy - energy) * 0.12
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func startVoiceSimulation() {
        Task { @MainActor in
            while true {
                // Simulate realistic voice: phrases with natural cadence
                let phraseLength = Int.random(in: 4...10)

                // Speaking phrase
                for syllable in 0..<phraseLength {
                    let syllableIntensity: Double
                    let phraseProg = Double(syllable) / Double(phraseLength)

                    // Natural phrase arc: ramp up, sustain, tail off
                    if phraseProg < 0.2 {
                        syllableIntensity = 0.3 + phraseProg * 3.0
                    } else if phraseProg > 0.75 {
                        let tailProg = (phraseProg - 0.75) / 0.25
                        syllableIntensity = 0.9 - tailProg * 0.5
                    } else {
                        syllableIntensity = Double.random(in: 0.6...1.0)
                    }

                    targetEnergy = syllableIntensity

                    // Spawn 1-2 beams per syllable
                    let count = Int.random(in: 1...2)
                    for _ in 0..<count {
                        if midBeams.count >= maxMidBeams {
                            midBeams.removeFirst()
                        }
                        midBeams.append(makeMidBeam(energy: syllableIntensity))
                    }

                    // Syllable timing — varies like real speech
                    let gap = Int.random(in: 120...350)
                    try? await Task.sleep(for: .milliseconds(gap))
                }

                // Breath / pause between phrases
                targetEnergy = Double.random(in: 0.0...0.15)
                let pause = Int.random(in: 400...1000)
                try? await Task.sleep(for: .milliseconds(pause))

                // Prune expired beams
                let now = Date.now.timeIntervalSince(startTime)
                midBeams.removeAll { now - $0.spawnTime > $0.lifetime }
            }
        }
    }

    private func makeMidBeam(energy: Double) -> LiveBeam {
        let now = Date.now.timeIntervalSince(startTime)
        return LiveBeam(
            xPosition: Double.random(in: 0.05...0.95),
            width: Double.random(in: 0.006...0.025) * (0.5 + energy * 0.5),
            brightness: Double.random(in: 0.5...1.0) * max(energy, 0.3),
            spawnTime: now,
            lifetime: Double.random(in: 0.8...2.5),
            fadeInDuration: Double.random(in: 0.1...0.3),
            swayAmount: Double.random(in: 0.003...0.015),
            swaySpeed: Double.random(in: 0.5...1.5),
            swayPhase: Double.random(in: 0...(.pi * 2))
        )
    }

    // MARK: - Color Cycle

    private func startColorCycle() {
        Task { @MainActor in
            while true {
                try? await Task.sleep(for: .seconds(colorCycleDuration))

                previousColorIndex = currentColorIndex
                currentColorIndex = (currentColorIndex + 1) % voicePalettes.count
                colorProgress = 0.0

                let steps = 50
                for i in 1...steps {
                    try? await Task.sleep(for: .milliseconds(50))
                    let t = Double(i) / Double(steps)
                    colorProgress = t * t * (3.0 - 2.0 * t)
                }
                colorProgress = 1.0
            }
        }
    }

    private func lerpColor(_ keyPath: KeyPath<VoicePalette, Color>) -> Color {
        let from = voicePalettes[previousColorIndex][keyPath: keyPath]
        let to = voicePalettes[currentColorIndex][keyPath: keyPath]
        let fc = UIColor(from).rgbaComponents
        let tc = UIColor(to).rgbaComponents
        let p = colorProgress
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
        let dim = lerpColor(\.dim)
        let mid = lerpColor(\.mid)

        var ac = context
        ac.blendMode = .plusLighter

        // Back lines breathe with voice energy
        let energyBoost = 0.5 + energy * 0.5

        for line in backLines {
            // Gentle brightness oscillation + energy swell
            let pulse = sin(elapsed * line.speed + line.phase) * 0.3 + 0.7
            let alpha = line.brightness * pulse * energyBoost

            // Horizontal sway — each line drifts side to side
            let sway = sin(elapsed * line.swaySpeed + line.phase) * line.swayAmount
            let swayX = (line.baseX + sway)

            let cx = perspectiveX(
                normalizedX: swayX,
                depth: line.depth,
                screenWidth: size.width
            )
            let w = line.width * size.width

            // Glow
            drawVerticalLine(
                context: &ac,
                cx: cx, width: max(w * 5, 6),
                size: size,
                color: dim,
                opacity: alpha * 0.3
            )

            // Core
            drawVerticalLine(
                context: &ac,
                cx: cx, width: max(w, 1),
                size: size,
                color: mid,
                opacity: alpha * 0.7
            )
        }
    }

    private func drawMidLayer(
        context: inout GraphicsContext,
        size: CGSize,
        elapsed: Double,
        energy: Double
    ) {
        let core = lerpColor(\.core)
        let bright = lerpColor(\.bright)

        var ac = context
        ac.blendMode = .plusLighter

        for beam in midBeams {
            let age = elapsed - beam.spawnTime
            guard age >= 0 && age < beam.lifetime else { continue }

            // Smooth fade envelope — sine-shaped attack and release
            let lifeProgress = age / beam.lifetime
            let envelope = sin(lifeProgress * .pi)
            let fadeIn = min(age / beam.fadeInDuration, 1.0)
            let alpha = fadeIn * envelope * beam.brightness
            guard alpha > 0.01 else { continue }

            // Horizontal sway — beam dances while alive
            let sway = sin(elapsed * beam.swaySpeed + beam.swayPhase) * beam.swayAmount
            let cx = (beam.xPosition + sway) * size.width
            let w = beam.width * size.width

            // Wide bloom
            drawVerticalLine(
                context: &ac,
                cx: cx, width: max(w * 10, 20),
                size: size,
                color: core,
                opacity: alpha * 0.15
            )

            // Glow
            drawVerticalLine(
                context: &ac,
                cx: cx, width: max(w * 4, 10),
                size: size,
                color: core,
                opacity: alpha * 0.35
            )

            // Bright core
            drawVerticalLine(
                context: &ac,
                cx: cx, width: max(w * 1.5, 3),
                size: size,
                color: bright,
                opacity: alpha * 0.85
            )

            // White hot center
            drawVerticalLine(
                context: &ac,
                cx: cx, width: max(w * 0.4, 1.2),
                size: size,
                color: .white,
                opacity: min(alpha * 1.2, 1.0)
            )
        }
    }

    private func drawFrontLayer(
        context: inout GraphicsContext,
        size: CGSize,
        elapsed: Double,
        energy: Double
    ) {
        let core = lerpColor(\.core)
        let bright = lerpColor(\.bright)

        var ac = context
        ac.blendMode = .plusLighter

        let energyBoost = 0.4 + energy * 0.6

        for streak in frontStreaks {
            // Slow sway — larger amplitude for foreground parallax
            let sway = sin(elapsed * streak.swaySpeed + streak.phase) * streak.swayAmount
            let pulse = sin(elapsed * streak.speed + streak.phase) * 0.5 + 0.5
            let alpha = streak.brightness * (0.3 + pulse * 0.7) * energyBoost

            let cx = (streak.baseX + sway) * size.width
            let w = streak.width * size.width

            // Huge soft glow
            drawVerticalLine(
                context: &ac,
                cx: cx, width: w * 6,
                size: size,
                color: core,
                opacity: alpha * 0.08
            )

            // Diffuse body
            drawVerticalLine(
                context: &ac,
                cx: cx, width: w * 2.5,
                size: size,
                color: bright,
                opacity: alpha * 0.15
            )

            // Bright center
            drawVerticalLine(
                context: &ac,
                cx: cx, width: max(w * 0.5, 2),
                size: size,
                color: .white,
                opacity: alpha * 0.3
            )
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
        let rect = CGRect(
            x: cx - halfW,
            y: 0,
            width: width,
            height: size.height
        )

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

    private func perspectiveX(
        normalizedX: Double,
        depth: Double,
        screenWidth: Double
    ) -> Double {
        let centerX = screenWidth * 0.5
        let rawX = normalizedX * screenWidth
        let offset = rawX - centerX
        let perspectiveStrength = 0.15 * (1.0 - depth)
        return centerX + offset * (1.0 + perspectiveStrength)
    }

    private func drawDepthFog(context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)

        // Top/bottom fade to black
        let topFade = LinearGradient(
            colors: [Color(hex: "020206"), Color(hex: "020206").opacity(0.6), .clear],
            startPoint: .top,
            endPoint: UnitPoint(x: 0.5, y: 0.2)
        )
        context.opacity = 1.0
        context.fill(Rectangle().path(in: rect), with: .style(topFade))

        let bottomFade = LinearGradient(
            colors: [.clear, Color(hex: "020206").opacity(0.6), Color(hex: "020206")],
            startPoint: UnitPoint(x: 0.5, y: 0.8),
            endPoint: .bottom
        )
        context.fill(Rectangle().path(in: rect), with: .style(bottomFade))

        // Vignette
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
    let xPosition: Double
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

private struct VoicePalette {
    let core: Color
    let bright: Color
    let mid: Color
    let dim: Color
    let ambient: Color
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

#Preview("Voice Visualizer") {
    VoiceVisualizer()
}

#Preview("With Content Overlay") {
    ZStack {
        VoiceVisualizer()

        VStack(spacing: 12) {
            Text("Emma's Voice")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white)
            Text("Preview")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}
