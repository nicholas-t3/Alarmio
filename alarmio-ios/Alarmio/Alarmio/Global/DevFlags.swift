//
//  DevFlags.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/15/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation

/// Compile-time developer toggles for local testing. Flip flags here —
/// never check behavior off a user setting.
enum DevFlags {

    /// When true, `ComposerService.generateAndDownloadAudio` skips the
    /// Supabase Edge Function + ElevenLabs call entirely and instead
    /// reuses the bundled `alarm1.mp3`/`alarm2.mp3`/`alarm3.mp3` test
    /// files, copying them into the per-alarm indexed filenames the rest
    /// of the system expects. Saves ~40k ElevenLabs credits per test.
    ///
    /// Indices 0..2 map to alarm1/alarm2/alarm3; index ≥3 falls back to
    /// alarm1. All filename/nonce plumbing matches the production path
    /// so `AudioFileManager.soundFileName(for:)` resolves normally.
    ///
    /// **Scope:** audio only. Text generation (`generateCustomAlarmText`,
    /// `rewriteAlarmTimes`) ignores this flag and always hits OpenAI —
    /// text is cheap, and the preview the user approves has to be real.
    static let skipGeneration: Bool = false

    /// When true, `performRegeneration()` on the edit sheet throws
    /// immediately with a fake error so the regen failure UI
    /// ("Please try again" red flash + toast) can be tested without
    /// having to coax ElevenLabs into a real 409.
    ///
    /// Scoped to the edit sheet — leaves audio/text generation paths
    /// in other flows alone.
    static let forceEditRegenerationError: Bool = false
}
