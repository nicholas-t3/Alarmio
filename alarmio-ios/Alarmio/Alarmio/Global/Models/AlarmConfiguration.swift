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
    case bro
    case digitalAssistant = "digital_assistant"
}

/// Whether this alarm uses the standard Composer flow (`.basic`) or the
/// Pro flow with user-approved scripts (`.pro`). The backend branches on
/// this to decide whether to run OpenAI at all for index 0 and how to
/// handle snoozes.
enum AlarmType: String, CaseIterable, Codable, Sendable {
    case basic
    case pro
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
    /// User-provided display name. Optional — nil renders as "None" in the
    /// edit sheet and is omitted from the home card. Max 40 chars by UI.
    var name: String?
    var wakeTime: Date?
    var repeatDays: [Int]?
    var leaveTime: Date?
    var tone: AlarmTone?
    var intensity: AlarmIntensity?
    var voicePersona: VoicePersona?
    var contentFlags: [ContentFlag] = []
    var snoozeInterval: Int = 5
    var maxSnoozes: Int = 3
    /// Unlimited snooze — when true, `maxSnoozes` is ignored and every
    /// snooze plays the single loop audio file (`_1`) forever. Default
    /// false preserves Codable back-compat for previously persisted alarms.
    var unlimitedSnooze: Bool = false
    // currentSnoozeCount stays optional — it's runtime state mutated by
    // SnoozeAlarmIntent, and keeping it optional preserves Codable
    // back-compat with any alarms persisted without this field.
    var currentSnoozeCount: Int? = 0
    var customPrompt: String?
    var difficulty: AlarmDifficulty?
    var whyContext: WhyContext?

    /// Whether this alarm uses the basic flow or the Pro flow. Default
    /// `.basic` preserves Codable back-compat for existing alarms.
    var alarmType: AlarmType = .basic

    /// Include flags for Pro custom-prompt generation. Defaulted empty so
    /// persisted alarms without this field decode cleanly.
    var customPromptIncludes: Set<CustomPromptInclude> = []

    /// Exact scripts the user accepted on the Pro preview screen. When
    /// non-nil, Composer uses these verbatim (index 0 = main, 1..N = snoozes)
    /// and skips OpenAI entirely. nil for basic alarms.
    var approvedScripts: [String]?

    /// When false, snoozes reuse a single loop audio file instead of
    /// generating fresh per-snooze variants. Default true preserves the
    /// current behavior for existing alarms.
    var creativeSnoozes: Bool = true

    /// Filename in Library/Sounds/ for this alarm's custom audio. Nil = use default.
    var soundFileName: String?

    /// Whether this is a demo alarm for UI testing purposes.
    var isDemo: Bool = false
}
