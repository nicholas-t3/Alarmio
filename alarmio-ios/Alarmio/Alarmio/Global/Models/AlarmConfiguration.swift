//
//  AlarmConfiguration.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation

// MARK: - Enums matching PRD Section 3

enum AlarmTone: String, CaseIterable, Codable, Sendable {
    case calm
    case encourage
    case push
    case strict
    case fun
    case other
}

enum WhyContext: String, CaseIterable, Codable, Sendable {
    case work
    case school
    case gym
    case family
    case personalGoal = "personal_goal"
    case important
    case other
}

enum AlarmIntensity: String, CaseIterable, Codable, Sendable {
    case gentle
    case balanced
    case intense
}

enum AlarmDifficulty: String, CaseIterable, Codable, Sendable {
    case easy
    case sometimesHard = "sometimes_hard"
    case veryHard = "very_hard"
}

enum VoicePersona: String, CaseIterable, Codable, Sendable {
    case calmGuide = "calm_guide"
    case energeticCoach = "energetic_coach"
    case hardSergeant = "hard_sergeant"
    case evilSpaceLord = "evil_space_lord"
    case playful
}

enum ContentFlag: String, CaseIterable, Codable, Sendable {
    case currentTime = "current_time"
    case timeUntilLeaving = "time_until_leaving"
    case motivation
    case affirmation
    case humor
    case push
}

// MARK: - Alarm Configuration

struct AlarmConfiguration: Codable, Sendable, Identifiable, Equatable {
    var id: UUID = UUID()
    var isEnabled: Bool = true
    var wakeTime: Date?
    var repeatDays: [Int]?
    var leaveTime: Date?
    var tone: AlarmTone?
    var intensity: AlarmIntensity?
    var voicePersona: VoicePersona?
    var contentFlags: [ContentFlag] = []
    var snoozeInterval: Int = 5
    var customPrompt: String?
    var difficulty: AlarmDifficulty?
    var whyContext: WhyContext?

    /// Filename in Library/Sounds/ for this alarm's custom audio. Nil = use default.
    var soundFileName: String?

    /// Whether this is a demo alarm for UI testing purposes.
    var isDemo: Bool = false
}
