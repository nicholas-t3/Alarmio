//
//  VoiceCatalog.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/17/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation

/// One row in the voice selection UI — a thin wrapper over `VoicePersona`
/// that surfaces its display name + descriptor for list/carousel rendering.
struct HeroVoice: Identifiable, Sendable, Equatable {
    let persona: VoicePersona

    var id: VoicePersona { persona }
    var name: String { persona.displayName }
    var descriptor: String { persona.descriptor }
}

/// Single source of truth for the in-app voice catalog. Every voice selection
/// surface (onboarding carousel, create alarm picker, edit sheet picker) reads
/// from `VoiceCatalog.all` so adding or removing a voice is a one-file change
/// (the `VoicePersona` enum itself).
enum VoiceCatalog {
    static var all: [HeroVoice] {
        VoicePersona.allCases.map(HeroVoice.init(persona:))
    }
}
