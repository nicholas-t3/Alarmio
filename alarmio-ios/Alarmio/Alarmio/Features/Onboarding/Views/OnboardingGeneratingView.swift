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
    @State private var statusText = ""
    @State private var statusTextVisible = false
    @State private var isComplete = false

    // MARK: - Constants
    let onComplete: () -> Void
    let onSunriseProgress: (Double) -> Void
    let onStarSpinProgress: (Double) -> Void

    // MARK: - Body
    var body: some View {

        // Status text — centered on screen
        Text(statusText)
            .font(AppTypography.bodyMedium)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 0)
            .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 0)
            .premiumBlur(isVisible: statusTextVisible, duration: 0.4, disableScale: true, disableOffset: true)
            .task {
                // Build personalized messages from configuration
                let messages = buildPersonalizedMessages()

                // Per-message timing: ~2s visible + 0.4s blur out + 0.4s blur in
                let messageHold: Double = 2.0
                let blurDuration: Double = 0.4
                let perMessageTotal = messageHold + (blurDuration * 2)
                let totalDuration = perMessageTotal * Double(messages.count)

                // Star spin ramps up fast independently
                animateStarSpin()

                // Sunrise glow ramps smoothly over the full duration
                animateSunrise(duration: totalDuration)

                // Cycle personalized messages with premium blur transitions
                for message in messages {
                    guard !isComplete else { break }

                    statusText = message
                    statusTextVisible = true

                    // Hold visible
                    try? await Task.sleep(for: .seconds(messageHold))
                    guard !isComplete else { break }

                    // Blur out before swapping to next
                    statusTextVisible = false
                    try? await Task.sleep(for: .seconds(blurDuration))
                }

                isComplete = true
                HapticManager.shared.success()

                try? await Task.sleep(for: .milliseconds(200))
                onComplete()
            }
    }

    // MARK: - Private Methods

    private func animateStarSpin() {
        Task { @MainActor in
            // Ramp to full spin in 2 seconds
            let steps = 30
            let duration = 2.0
            let interval = duration / Double(steps)

            for i in 1...steps {
                guard !isComplete else { break }
                try? await Task.sleep(for: .seconds(interval))
                let p = Double(i) / Double(steps)
                // Ease-out — fast start
                let eased = 1.0 - (1.0 - p) * (1.0 - p)
                onStarSpinProgress(eased)
            }
        }
    }

    private func animateSunrise(duration: Double) {
        Task { @MainActor in
            let steps = 60
            let interval = duration / Double(steps)

            for i in 1...steps {
                guard !isComplete else { break }
                try? await Task.sleep(for: .seconds(interval))
                let progress = Double(i) / Double(steps)
                // Smooth ease-in-out — steady build, no jarring jumps
                let eased = progress * progress * (3.0 - 2.0 * progress)
                onSunriseProgress(eased)
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
        case .bro: return "Grabbing the bro"
        case .digitalAssistant: return "Booting the assistant"
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
        MorningSky(starOpacity: 0.3, sunriseProgress: 0.6, starSpinProgress: 1.0)
        Text("Calling the drill sergeant")
            .font(AppTypography.bodyMedium)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 0)
    }
}

#Preview("Sunrise — Full Glow") {
    ZStack {
        MorningSky(starOpacity: 0.15, sunriseProgress: 0.7, starSpinProgress: 1.0)
        Text("Almost ready")
            .font(AppTypography.bodyMedium)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 0)
    }
}
