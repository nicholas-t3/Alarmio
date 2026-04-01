//
//  StarburstTest.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct StarburstView: View {

    // MARK: - State

    @State private var rays: [StarburstRay] = []
    @State private var isActive = false
    @State private var rotationAngle: Double = 0

    // MARK: - Constants

    let rayCount: Int
    let baseColor: Color
    let accentColor: Color
    let speed: Double

    init(
        rayCount: Int = 24,
        baseColor: Color = .white,
        accentColor: Color = .white.opacity(0.3),
        speed: Double = 0.15
    ) {
        self.rayCount = rayCount
        self.baseColor = baseColor
        self.accentColor = accentColor
        self.speed = speed
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let maxRadius = max(geometry.size.width, geometry.size.height)

            Canvas { context, size in
                for ray in rays {
                    let angle = ray.angle + Angle.degrees(rotationAngle)
                    let length = maxRadius * ray.length

                    let startPoint = CGPoint(
                        x: center.x + cos(angle.radians) * ray.innerRadius,
                        y: center.y + sin(angle.radians) * ray.innerRadius
                    )
                    let endPoint = CGPoint(
                        x: center.x + cos(angle.radians) * length,
                        y: center.y + sin(angle.radians) * length
                    )

                    var path = Path()
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)

                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [
                                baseColor.opacity(ray.opacity),
                                accentColor.opacity(ray.opacity * 0.3)
                            ]),
                            startPoint: startPoint,
                            endPoint: endPoint
                        ),
                        lineWidth: ray.width
                    )
                }
            }
            .blur(radius: 1.5)
            .opacity(isActive ? 1 : 0)
            .animation(.easeIn(duration: 1.0), value: isActive)
        }
        .onAppear {
            generateRays()
            isActive = true

            withAnimation(.linear(duration: 60 / speed).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }

    // MARK: - Private Methods

    private func generateRays() {
        rays = (0..<rayCount).map { i in
            let baseAngle = (360.0 / Double(rayCount)) * Double(i)
            let jitter = Double.random(in: -4...4)

            return StarburstRay(
                angle: .degrees(baseAngle + jitter),
                length: CGFloat.random(in: 0.4...1.0),
                width: CGFloat.random(in: 0.5...2.5),
                opacity: Double.random(in: 0.08...0.35),
                innerRadius: CGFloat.random(in: 20...60)
            )
        }
    }
}

struct StarburstRay {
    let angle: Angle
    let length: CGFloat
    let width: CGFloat
    let opacity: Double
    let innerRadius: CGFloat
}

#Preview("Starburst") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()

        StarburstView()

        Text("ALARMIO")
            .displayLarge()
    }
}

#Preview("Starburst — Warm") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()

        StarburstView(
            rayCount: 36,
            baseColor: Color(hex: "FF6B35"),
            accentColor: Color(hex: "FFB347").opacity(0.4),
            speed: 0.1
        )

        Text("Wake up\nyour way")
            .displayLarge()
            .multilineTextAlignment(.center)
    }
}

#Preview("Starburst — Rainbow") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()

        ZStack {
            StarburstView(rayCount: 20, baseColor: .red.opacity(0.6), speed: 0.12)
            StarburstView(rayCount: 18, baseColor: .blue.opacity(0.4), speed: 0.08)
            StarburstView(rayCount: 16, baseColor: .green.opacity(0.3), speed: 0.18)
        }

        Text("Wake up\nyour way")
            .displayLarge()
            .multilineTextAlignment(.center)
    }
}
