//
//  AlarmConfiguration+Display.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/13/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation

// MARK: - VoicePersona Display

extension VoicePersona {

    /// Short display name shown in summary rows and selection lists.
    var displayName: String {
        switch self {
        case .calmGuide: return "Calm Guide"
        case .energeticCoach: return "Coach"
        case .hardSergeant: return "Sergeant"
        case .evilSpaceLord: return "Space Lord"
        case .playful: return "Playful"
        case .bro: return "The Bro"
        case .digitalAssistant: return "Digital"
        }
    }

    /// Two-word vibe descriptor — e.g. "Soothing · Gentle".
    /// Used everywhere a one-line subtitle is needed.
    var descriptor: String {
        switch self {
        case .calmGuide: return "Soothing · Gentle"
        case .energeticCoach: return "Upbeat · Motivating"
        case .hardSergeant: return "Firm · Direct"
        case .evilSpaceLord: return "Dramatic · Commanding"
        case .playful: return "Bright · Lighthearted"
        case .bro: return "Casual · Vibes"
        case .digitalAssistant: return "Robotic · Helpful"
        }
    }

    /// SF Symbol icon used in row and pill UIs.
    var icon: String {
        switch self {
        case .calmGuide: return "leaf.fill"
        case .energeticCoach: return "flame.fill"
        case .hardSergeant: return "bolt.fill"
        case .evilSpaceLord: return "sparkles"
        case .playful: return "face.smiling.fill"
        case .bro: return "hand.wave.fill"
        case .digitalAssistant: return "cpu"
        }
    }
}

// MARK: - AlarmTone Display

extension AlarmTone {

    var displayName: String {
        switch self {
        case .calm: return "Calm"
        case .encourage: return "Encourage"
        case .push: return "Push"
        case .strict: return "Strict"
        case .fun: return "Fun"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .calm: return "leaf.fill"
        case .encourage: return "hand.thumbsup.fill"
        case .push: return "bolt.fill"
        case .strict: return "exclamationmark.triangle.fill"
        case .fun: return "face.smiling.fill"
        case .other: return "sparkles"
        }
    }
}

// MARK: - AlarmIntensity Display

extension AlarmIntensity {

    var displayName: String {
        switch self {
        case .gentle: return "Gentle"
        case .balanced: return "Balanced"
        case .intense: return "Intense"
        }
    }

    var icon: String {
        switch self {
        case .gentle: return "leaf"
        case .balanced: return "circle.grid.2x2"
        case .intense: return "bolt.fill"
        }
    }
}

// MARK: - WhyContext Display

extension WhyContext {

    var displayName: String {
        switch self {
        case .work: return "Work"
        case .school: return "School"
        case .gym: return "Gym"
        case .family: return "Family"
        case .personalGoal: return "Goal"
        case .important: return "Important"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .school: return "book.fill"
        case .gym: return "dumbbell.fill"
        case .family: return "house.fill"
        case .personalGoal: return "star.fill"
        case .important: return "exclamationmark.circle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}
