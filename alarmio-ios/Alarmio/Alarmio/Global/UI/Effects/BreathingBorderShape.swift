//
//  BreathingBorderShape.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct BreathingRectangle: Shape {

    var size: CGSize
    var padding: Double
    var cornerRadius: CGFloat
    var t: CGFloat

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    init(size: CGSize, padding: Double = 8.0, cornerRadius: CGFloat = 48, t: CGFloat = 0) {
        self.size = size
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.t = t
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = size.width
        let height = size.height
        let radius = cornerRadius

        let initialPoints = [
            CGPoint(x: padding + radius, y: padding),
            CGPoint(x: width * 0.25 + padding, y: padding),
            CGPoint(x: width * 0.75 + padding, y: padding),
            CGPoint(x: width - padding - radius, y: padding),
            CGPoint(x: width - padding, y: padding + radius),
            CGPoint(x: width - padding, y: height * 0.25 - padding),
            CGPoint(x: width - padding, y: height * 0.75 - padding),
            CGPoint(x: width - padding, y: height - padding - radius),
            CGPoint(x: width - padding - radius, y: height - padding),
            CGPoint(x: width * 0.75 - padding, y: height - padding),
            CGPoint(x: width * 0.25 - padding, y: height - padding),
            CGPoint(x: padding + radius, y: height - padding),
            CGPoint(x: padding, y: height - padding - radius),
            CGPoint(x: padding, y: height * 0.75 - padding),
            CGPoint(x: padding, y: height * 0.25 - padding),
            CGPoint(x: padding, y: padding + radius)
        ]

        let points = initialPoints.enumerated().map { index, point in
            let phase = CGFloat(index) * 0.7
            return CGPoint(
                x: point.x + 10 * sin(t + phase),
                y: point.y + 10 * sin(t + phase + 1.5)
            )
        }

        path.move(to: CGPoint(x: padding, y: padding + radius))

        // Top edge
        for point in points[0...2] {
            path.addLine(to: point)
        }

        // Right edge
        for point in points[4...7] {
            path.addLine(to: point)
        }

        // Bottom edge
        for point in points[8...10] {
            path.addLine(to: point)
        }

        // Left edge
        for point in points[11...14] {
            path.addLine(to: point)
        }

        path.closeSubpath()
        return path
    }
}

#Preview {
    GeometryReader { geometry in
        ZStack {
            Color(hex: "050505").ignoresSafeArea()

            MeshGradientBackground(opacity: 0.8)

            Color(hex: "050505")
                .mask {
                    BreathingRectangle(
                        size: geometry.size,
                        cornerRadius: 48,
                        t: 0
                    )
                    .blur(radius: 28)
                }
        }
    }
}
