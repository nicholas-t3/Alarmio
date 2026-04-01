//
//  MeshGradientBackground.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct MeshGradientBackground: View {

    // MARK: - State

    @State private var time: Float = 0.0
    @State private var timer: Timer?

    // MARK: - Constants

    let speed: Float
    let opacity: Double
    let colors: [Color]

    init(
        speed: Float = 0.03,
        opacity: Double = 0.6,
        colors: [Color] = [
            .yellow, .purple, .indigo,
            .orange, .red, .blue,
            .indigo, .green, .mint
        ]
    ) {
        self.speed = speed
        self.opacity = opacity
        self.colors = colors
    }

    // MARK: - Body

    var body: some View {
        MeshGradient(width: 3, height: 3, points: [
            .init(0, 0), .init(0.5, 0), .init(1, 0),

            [sinInRange(-0.8...(-0.2), offset: 0.439, timeScale: 0.342, t: time),
             sinInRange(0.3...0.7, offset: 3.42, timeScale: 0.984, t: time)],
            [sinInRange(0.1...0.8, offset: 0.239, timeScale: 0.084, t: time),
             sinInRange(0.2...0.8, offset: 5.21, timeScale: 0.242, t: time)],
            [sinInRange(1.0...1.5, offset: 0.939, timeScale: 0.084, t: time),
             sinInRange(0.4...0.8, offset: 0.25, timeScale: 0.642, t: time)],

            [sinInRange(-0.8...0.0, offset: 1.439, timeScale: 0.442, t: time),
             sinInRange(1.4...1.9, offset: 3.42, timeScale: 0.984, t: time)],
            [sinInRange(0.3...0.6, offset: 0.339, timeScale: 0.784, t: time),
             sinInRange(1.0...1.2, offset: 1.22, timeScale: 0.772, t: time)],
            [sinInRange(1.0...1.5, offset: 0.939, timeScale: 0.056, t: time),
             sinInRange(1.3...1.7, offset: 0.47, timeScale: 0.342, t: time)]
        ], colors: colors)
        .scaleEffect(1.3)
        .opacity(opacity)
        .ignoresSafeArea()
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
                DispatchQueue.main.async {
                    time += speed
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    // MARK: - Private Methods

    private func sinInRange(_ range: ClosedRange<Float>, offset: Float, timeScale: Float, t: Float) -> Float {
        let amplitude = (range.upperBound - range.lowerBound) / 2
        let midPoint = (range.upperBound + range.lowerBound) / 2
        return midPoint + amplitude * sin(timeScale * t + offset)
    }
}

#Preview {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        MeshGradientBackground()
    }
}

#Preview("Brighter") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        MeshGradientBackground(opacity: 0.9)
    }
}
