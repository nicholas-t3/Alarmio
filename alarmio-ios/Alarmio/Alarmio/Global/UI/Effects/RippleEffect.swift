//
//  RippleEffect.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct RippleEffect<T: Equatable>: ViewModifier {

    var origin: CGPoint
    var trigger: T
    var amplitude: Double
    var frequency: Double
    var decay: Double
    var speed: Double
    var duration: TimeInterval

    init(
        at origin: CGPoint,
        trigger: T,
        amplitude: Double = 12,
        frequency: Double = 15,
        decay: Double = 8,
        speed: Double = 2000,
        duration: TimeInterval = 3
    ) {
        self.origin = origin
        self.trigger = trigger
        self.amplitude = amplitude
        self.frequency = frequency
        self.decay = decay
        self.speed = speed
        self.duration = duration
    }

    func body(content: Content) -> some View {
        let origin = origin
        let duration = duration
        let amplitude = amplitude
        let frequency = frequency
        let decay = decay
        let speed = speed

        content.keyframeAnimator(
            initialValue: 0.0,
            trigger: trigger
        ) { view, elapsedTime in
            view.visualEffect { content, _ in
                content.layerEffect(
                    ShaderLibrary.Ripple(
                        .float2(origin),
                        .float(elapsedTime),
                        .float(amplitude),
                        .float(frequency),
                        .float(decay),
                        .float(speed)
                    ),
                    maxSampleOffset: CGSize(width: amplitude, height: amplitude),
                    isEnabled: 0 < elapsedTime && elapsedTime < duration
                )
            }
        } keyframes: { _ in
            MoveKeyframe(0)
            LinearKeyframe(duration, duration: duration)
        }
    }
}

extension View {
    func ripple<T: Equatable>(at origin: CGPoint, trigger: T) -> some View {
        modifier(RippleEffect(at: origin, trigger: trigger))
    }

    func ripple<T: Equatable>(
        at origin: CGPoint,
        trigger: T,
        amplitude: Double,
        frequency: Double = 15,
        decay: Double = 8,
        speed: Double = 2000
    ) -> some View {
        modifier(RippleEffect(
            at: origin,
            trigger: trigger,
            amplitude: amplitude,
            frequency: frequency,
            decay: decay,
            speed: speed
        ))
    }
}

#Preview {
    struct RippleDemo: View {

        @State private var counter = 0
        @State private var origin: CGPoint = .init(x: 200, y: 400)

        var body: some View {
            ZStack {
                Color(hex: "050505").ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("ALARMIO")
                        .displayLarge()

                    Text("Tap anywhere to ripple")
                        .bodyMedium()
                }
            }
            .ripple(at: origin, trigger: counter)
            .onTapGesture { location in
                origin = location
                counter += 1
            }
        }
    }

    return RippleDemo()
}
