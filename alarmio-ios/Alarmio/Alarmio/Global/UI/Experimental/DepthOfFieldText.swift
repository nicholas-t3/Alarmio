//
//  DepthOfFieldText.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

// MARK: - Focus Phase
enum FocusPhase {
    case approaching  // Close to viewer, blurry, large
    case inFocus      // Perfect distance, clear
    case receding     // Far from viewer, blurry, small
}

// MARK: - Focusable Text
struct FocusableText: View {

    // MARK: - Constants
    let text: String
    let fontSize: CGFloat
    let phase: FocusPhase

    private var scale: CGFloat {
        switch phase {
        case .approaching: return 1.4
        case .inFocus: return 1.0
        case .receding: return 0.6
        }
    }

    private var blur: CGFloat {
        switch phase {
        case .approaching: return 12
        case .inFocus: return 0
        case .receding: return 8
        }
    }

    private var opacity: Double {
        switch phase {
        case .approaching: return 0.7
        case .inFocus: return 1.0
        case .receding: return 0.0
        }
    }

    private var yOffset: CGFloat {
        switch phase {
        case .approaching: return -20
        case .inFocus: return 0
        case .receding: return 20
        }
    }

    // MARK: - Body
    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .light))
            .tracking(2)
            .foregroundStyle(.white)
            .scaleEffect(scale)
            .blur(radius: blur)
            .opacity(opacity)
            .offset(y: yOffset)
    }
}

// MARK: - Depth of Field Text (Cycling single word)
struct DepthOfFieldText: View {

    // MARK: - Constants
    let texts: [String]
    let fontSize: CGFloat
    let cycleDuration: Double

    init(
        texts: [String],
        fontSize: CGFloat = 64,
        cycleDuration: Double = 3.0
    ) {
        self.texts = texts
        self.fontSize = fontSize
        self.cycleDuration = cycleDuration
    }

    // MARK: - State
    @State private var currentIndex: Int = 0
    @State private var phase: FocusPhase = .approaching

    // MARK: - Body
    var body: some View {
        ZStack {
            ForEach(Array(texts.enumerated()), id: \.offset) { index, text in
                if index == currentIndex {
                    FocusableText(
                        text: text,
                        fontSize: fontSize,
                        phase: phase
                    )
                    .transition(.identity)
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - Private Methods
    private func startAnimation() {
        withAnimation(.easeOut(duration: cycleDuration * 0.35)) {
            phase = .inFocus
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + cycleDuration * 0.5) {
            withAnimation(.easeIn(duration: cycleDuration * 0.35)) {
                phase = .receding
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + cycleDuration * 0.9) {
            currentIndex = (currentIndex + 1) % texts.count
            phase = .approaching

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startAnimation()
            }
        }
    }
}

// MARK: - Stacked Depth Text (Multiple lines, staggered entry)
struct StackedDepthText: View {

    // MARK: - Constants
    let lines: [String]
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let staggerDelay: Double
    let initialDelay: Double

    init(
        lines: [String],
        fontSize: CGFloat = 56,
        lineSpacing: CGFloat = 8,
        staggerDelay: Double = 0.15,
        initialDelay: Double = 0
    ) {
        self.lines = lines
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.staggerDelay = staggerDelay
        self.initialDelay = initialDelay
    }

    // MARK: - State
    @State private var phases: [FocusPhase] = []
    @State private var hasStarted: Bool = false
    @State private var opacity: Double = 0

    // MARK: - Body
    var body: some View {
        VStack(spacing: lineSpacing) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                FocusableText(
                    text: line,
                    fontSize: fontSize,
                    phase: phases.indices.contains(index) ? phases[index] : .approaching
                )
            }
        }
        .opacity(opacity)
        .onAppear {
            phases = Array(repeating: .approaching, count: lines.count)
            if !hasStarted {
                hasStarted = true
                startSequence()
            }
        }
    }

    // MARK: - Private Methods
    private func startSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) {
            animateIn()
        }
    }

    private func animateIn() {
        for index in lines.indices {
            let delay = Double(index) * staggerDelay

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.6)) {
                    phases[index] = .inFocus
                }
            }
        }
    }
}

// MARK: - Rack Focus Text (Single pass, all lines end in focus)
struct RackFocusText: View {

    // MARK: - Constants
    let lines: [String]
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let focusDuration: Double
    let initialDelay: Double

    init(
        lines: [String],
        fontSize: CGFloat = 52,
        lineSpacing: CGFloat = 4,
        focusDuration: Double = 1.0,
        initialDelay: Double = 0.3
    ) {
        self.lines = lines
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.focusDuration = focusDuration
        self.initialDelay = initialDelay
    }

    // MARK: - State
    @State private var focusedIndex: Int = -1
    @State private var allFocused: Bool = false
    @State private var opacity: Double = 0
    @State private var hasStarted: Bool = false

    // MARK: - Body
    var body: some View {
        VStack(spacing: lineSpacing) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                RackFocusLine(
                    text: line,
                    fontSize: fontSize,
                    isFocused: allFocused || focusedIndex == index,
                    isAboveFocus: !allFocused && index < focusedIndex,
                    isBelowFocus: !allFocused && (index > focusedIndex || focusedIndex == -1)
                )
            }
        }
        .opacity(opacity)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            await startSequence()
        }
    }

    // MARK: - Private Methods
    @MainActor
    private func startSequence() async {
        withAnimation(.easeOut(duration: 2.0)) {
            opacity = 1
        }

        try? await Task.sleep(for: .milliseconds(Int(initialDelay * 1000)))
        await startRackFocus()
    }

    @MainActor
    private func startRackFocus() async {
        for index in lines.indices {
            withAnimation(.easeInOut(duration: 0.8)) {
                focusedIndex = index
            }

            if index < lines.count - 1 {
                try? await Task.sleep(for: .milliseconds(Int(focusDuration * 1000)))
            }
        }

        try? await Task.sleep(for: .milliseconds(Int(focusDuration * 1000) + 300))

        withAnimation(.easeInOut(duration: 0.5)) {
            allFocused = true
        }
    }
}

// MARK: - Rack Focus Line
struct RackFocusLine: View {

    // MARK: - Constants
    let text: String
    let fontSize: CGFloat
    let isFocused: Bool
    let isAboveFocus: Bool
    let isBelowFocus: Bool

    private var scale: CGFloat {
        if isFocused { return 1.0 }
        if isAboveFocus { return 0.85 }
        return 1.15
    }

    private var blur: CGFloat {
        if isFocused { return 0 }
        if isAboveFocus { return 6 }
        return 10
    }

    private var opacity: Double {
        if isFocused { return 1.0 }
        if isAboveFocus { return 0.5 }
        return 0.6
    }

    // MARK: - Body
    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .light))
            .tracking(-1)
            .foregroundStyle(.white)
            .fixedSize()
            .scaleEffect(scale)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

// MARK: - Previews
#Preview("Cycling Words") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()

        DepthOfFieldText(
            texts: ["WAKE", "UP", "NOW"],
            fontSize: 64,
            cycleDuration: 2.5
        )
    }
}

#Preview("Stacked Entry") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()

        StackedDepthText(
            lines: ["WAKE", "UP", "YOUR", "WAY"],
            fontSize: 56,
            staggerDelay: 0.2
        )
    }
}

#Preview("Rack Focus") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()

        RackFocusText(
            lines: ["WAKE", "UP", "YOUR", "WAY"],
            fontSize: 52
        )
    }
}
