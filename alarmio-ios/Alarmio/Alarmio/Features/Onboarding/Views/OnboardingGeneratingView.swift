//
//  OnboardingGeneratingView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct OnboardingGeneratingView: View {

    // MARK: - Environment
    @Environment(OnboardingManager.self) private var manager

    // MARK: - State
    @State private var contentVisible = false
    @State private var statusText = ""
    @State private var isComplete = false

    // MARK: - Constants
    let onComplete: () -> Void
    let onSunriseProgress: (Double) -> Void

    // MARK: - Body
    var body: some View {

        // Status text — centered on screen
        Text(statusText)
            .font(AppTypography.bodyMedium)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 0)
            .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 0)
            .contentTransition(.numericText())
            .animation(.easeInOut(duration: 0.6), value: statusText)
            .premiumBlur(isVisible: contentVisible, duration: 0.5)
            .task {
                try? await Task.sleep(for: .milliseconds(100))
                contentVisible = true

                // Build personalized messages from configuration
                let messages = buildPersonalizedMessages()

                // Each message holds for 3s — total duration scales with message count
                let messageHold: Double = 3.0
                let totalDuration = messageHold * Double(messages.count)

                // Kick off sunrise immediately — fast ramp to 0.5 in 2s, then ease to 1.0
                onSunriseProgress(0.15)
                animateSunrise(duration: totalDuration)

                // Cycle personalized messages
                for (index, message) in messages.enumerated() {
                    guard !isComplete else { break }
                    statusText = message

                    if index < messages.count - 1 {
                        try? await Task.sleep(for: .seconds(messageHold))
                    } else {
                        // Last message — hold until done
                        try? await Task.sleep(for: .seconds(messageHold))
                    }
                }

                isComplete = true
                HapticManager.shared.success()

                try? await Task.sleep(for: .milliseconds(600))
                onComplete()
            }
    }

    // MARK: - Private Methods

    private func animateSunrise(duration: Double) {
        Task { @MainActor in
            // Fast ramp: 0 → 0.5 in 1.5s, then slow cruise to 1.0
            let fastPhase = 1.5
            let fastSteps = 20
            let fastInterval = fastPhase / Double(fastSteps)

            for i in 1...fastSteps {
                guard !isComplete else { break }
                try? await Task.sleep(for: .seconds(fastInterval))
                let p = Double(i) / Double(fastSteps)
                onSunriseProgress(0.15 + p * 0.35)
            }

            // Slow cruise from 0.5 → 1.0 over remaining time
            let slowPhase = duration - fastPhase
            let slowSteps = 40
            let slowInterval = slowPhase / Double(slowSteps)

            for i in 1...slowSteps {
                guard !isComplete else { break }
                try? await Task.sleep(for: .seconds(slowInterval))
                let p = Double(i) / Double(slowSteps)
                onSunriseProgress(0.5 + p * 0.5)
            }
        }
    }

    private func buildPersonalizedMessages() -> [String] {
        let config = manager.configuration
        var messages: [String] = []

        // Tone-based message
        if let tone = config.tone {
            messages.append(toneMessage(tone))
        }

        // Why-based message
        if let why = config.whyContext {
            messages.append(whyMessage(why))
        }

        // Intensity message
        if let intensity = config.intensity {
            messages.append(intensityMessage(intensity))
        }

        // Voice-based message
        if let voice = config.voicePersona {
            messages.append(voiceMessage(voice))
        }

        // Closing messages
        messages.append("Writing your wake-up call")
        messages.append("Almost ready")

        return messages
    }

    private func toneMessage(_ tone: AlarmTone) -> String {
        switch tone {
        case .calm: return "Setting a calm tone"
        case .encourage: return "Adding some encouragement"
        case .push: return "Turning up the push"
        case .strict: return "Making it strict"
        case .fun: return "Making it funny"
        case .other: return "Adding your personal touch"
        }
    }

    private func whyMessage(_ why: WhyContext) -> String {
        switch why {
        case .work: return "Getting you ready for work"
        case .school: return "Prepping for the school day"
        case .gym: return "Fueling your morning workout"
        case .family: return "Making time for family"
        case .personalGoal: return "Aligning with your goals"
        case .important: return "Locking in on what matters"
        case .other: return "Personalizing your morning"
        }
    }

    private func intensityMessage(_ intensity: AlarmIntensity) -> String {
        switch intensity {
        case .gentle: return "Keeping it gentle"
        case .balanced: return "Finding the right balance"
        case .intense: return "Cranking up the intensity"
        }
    }

    private func voiceMessage(_ voice: VoicePersona) -> String {
        switch voice {
        case .calmGuide: return "Calling the calm guide"
        case .energeticCoach: return "Warming up the coach"
        case .hardSergeant: return "Calling the drill sergeant"
        case .evilSpaceLord: return "Summoning the space lord"
        case .playful: return "Bringing the fun"
        }
    }
}

// MARK: - Previews

#Preview("In Container — from Snooze") {
    OnboardingContainerView.preview(step: .snooze)
}

#Preview("In Container — Generating") {
    OnboardingContainerView.preview(step: .generating)
}

#Preview("Sunrise — Mid Glow") {
    ZStack {
        MorningSky(starOpacity: 0.3, sunriseProgress: 0.6)
        Text("Calling the drill sergeant")
            .font(AppTypography.bodyMedium)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 0)
    }
}

#Preview("Sunrise — Full Glow") {
    ZStack {
        MorningSky(starOpacity: 0.15, sunriseProgress: 1.0)
        Text("Almost ready")
            .font(AppTypography.bodyMedium)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 0)
    }
}
