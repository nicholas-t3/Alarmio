//
//  ComposerService.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/9/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation
import Supabase

/// Calls the `compose-alarm` Supabase Edge Function and downloads the
/// resulting audio files into `Library/Sounds/` so AlarmKit can use them.
///
/// One Composer call generates a coherent set of N audio files for an
/// alarm: the initial fire (index 0) plus one per snooze. Unlimited
/// snooze mode generates exactly 2 files (initial + a loop file).
@MainActor
final class ComposerService {

    // MARK: - Dependencies

    private let supabase = SupabaseClient.shared
    private let audioFileManager: AudioFileManager

    // MARK: - Init

    init(audioFileManager: AudioFileManager) {
        self.audioFileManager = audioFileManager
    }

    // MARK: - Public

    /// Generates audio for the given alarm, downloads every file into
    /// Library/Sounds/, and returns the filename of the initial fire
    /// (index 0) so the caller can set `AlarmConfiguration.soundFileName`.
    ///
    /// Throws on network failure, function error, or storage download
    /// failure. The caller should surface the error to the user and
    /// allow them to retry.
    func generateAndDownloadAudio(for alarm: AlarmConfiguration) async throws -> String {
        let request = ComposeRequest.from(alarm: alarm, timezone: TimeZone.current)

        // The SDK automatically attaches the user's JWT (Authorization header)
        // and the anon key (Apikey header) to function invocations. No manual
        // header management needed — just invoke.
        let response: ComposeResponse = try await supabase.client.functions.invoke(
            "compose-alarm",
            options: FunctionInvokeOptions(body: request)
        )

        // Download each file sequentially. For 2–4 small MP3s this is
        // fast enough and keeps us on the main actor throughout, avoiding
        // Swift 6 isolation gymnastics with TaskGroup + MainActor services.
        // If any download fails the whole generation fails — partial state
        // is worse than no state.
        for file in response.files {
            let bytes = try await supabase.client.storage
                .from("alarm-audio")
                .download(path: file.storage_path)
            _ = try audioFileManager.saveSound(
                data: bytes,
                for: alarm.id,
                index: file.index
            )
        }

        return audioFileManager.indexedFileName(for: alarm.id, index: 0)
    }
}

// MARK: - Request / Response Types

struct ComposeRequest: Codable, Sendable {
    let alarm_id: String
    let wake_time_local: String
    let wake_date_local: String
    let timezone: String
    let leave_time_local: String?
    let tone: String?
    let intensity: String?
    let voice_persona: String
    let why_context: String?
    let content_flags: [String]
    let custom_prompt: String?
    let max_snoozes: Int
    let snooze_interval_minutes: Int
    let unlimited_snooze: Bool

    static func from(alarm: AlarmConfiguration, timezone: TimeZone) -> ComposeRequest {
        let formatterTime = DateFormatter()
        formatterTime.dateFormat = "HH:mm"
        formatterTime.timeZone = timezone

        let formatterDate = DateFormatter()
        formatterDate.dateFormat = "yyyy-MM-dd"
        formatterDate.timeZone = timezone

        // Default to today if wakeTime is nil — request validation server-side
        // would catch this anyway, but iOS shouldn't send garbage.
        let wakeDate = alarm.wakeTime ?? Date()

        return ComposeRequest(
            alarm_id: alarm.id.uuidString,
            wake_time_local: formatterTime.string(from: wakeDate),
            wake_date_local: formatterDate.string(from: wakeDate),
            timezone: timezone.identifier,
            leave_time_local: alarm.leaveTime.map { formatterTime.string(from: $0) },
            tone: alarm.tone?.rawValue,
            intensity: alarm.intensity?.rawValue,
            voice_persona: alarm.voicePersona?.rawValue ?? "calm_guide",
            why_context: alarm.whyContext?.rawValue,
            content_flags: alarm.contentFlags.map(\.rawValue),
            custom_prompt: alarm.customPrompt,
            max_snoozes: alarm.maxSnoozes,
            snooze_interval_minutes: alarm.snoozeInterval,
            unlimited_snooze: alarm.unlimitedSnooze
        )
    }
}

struct ComposeResponse: Codable, Sendable {
    let composition_id: String
    let alarm_id: String
    let is_unlimited_snooze: Bool
    let files: [ComposeFile]
}

struct ComposeFile: Codable, Sendable {
    let index: Int
    let is_loop_file: Bool
    let storage_path: String
    let script_text: String
    let duration_ms: Int?
}
