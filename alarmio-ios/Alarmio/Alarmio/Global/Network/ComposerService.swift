//
//  ComposerService.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/9/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation

/// Calls the `compose-alarm` Supabase Edge Function and downloads the
/// resulting audio files into `Library/Sounds/` so AlarmKit can use them.
///
/// One Composer call generates a coherent set of N audio files for an
/// alarm: the initial fire (index 0) plus one per snooze. Unlimited
/// snooze mode generates exactly 2 files (initial + a loop file).
@MainActor
final class ComposerService {

    // MARK: - Dependencies

    private let apiClient = APIClient.shared
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
    /// Throws `APIError` on network failure, function error, or storage
    /// download failure.
    func generateAndDownloadAudio(for alarm: AlarmConfiguration) async throws -> String {
        let request = ComposeRequest.from(alarm: alarm, timezone: TimeZone.current)

        print("[Composer] >>> invoking compose-alarm (alarmId=\(request.alarm_id), persona=\(request.voice_persona), tone=\(request.tone ?? "nil"), intensity=\(request.intensity ?? "nil"), why=\(request.why_context ?? "nil"))")

        let response: ComposeResponse = try await apiClient.invokeFunction(
            "compose-alarm",
            body: request
        )

        print("[Composer] <<< composition_id=\(response.composition_id), files=\(response.files.count)")
        for file in response.files {
            let scriptPreview = String(file.script_text.prefix(60))
            print("[Composer]     file[\(file.index)] path=\(file.storage_path) script=\"\(scriptPreview)...\"")
        }

        // Don't purge old files — caller may abandon the regeneration without
        // committing. The existing file on disk must keep working until the
        // new soundFileName is actually persisted to the alarm config.
        // Purge happens in the edit-save commit path instead.

        let nonce = AudioFileManager.newAudioNonce()

        for file in response.files {
            let bytes = try await apiClient.downloadFromStorage(
                bucket: "alarm-audio",
                path: file.storage_path
            )

            let hashPrefix = bytes.prefix(32).map { String(format: "%02x", $0) }.joined()
            print("[Composer]     downloaded file[\(file.index)] bytes=\(bytes.count) firstBytesHex=\(hashPrefix)")

            _ = try audioFileManager.saveSound(
                data: bytes,
                for: alarm.id,
                index: file.index,
                nonce: nonce
            )
        }

        let resultName = audioFileManager.indexedFileName(for: alarm.id, index: 0, nonce: nonce)
        print("[Composer] === saved initial as \(resultName)")
        return resultName
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
    let uses_24_hour: Bool

    static func from(alarm: AlarmConfiguration, timezone: TimeZone) -> ComposeRequest {
        let uses24Hour = Self.deviceUses24HourTime()

        let formatterTime = DateFormatter()
        formatterTime.timeZone = timezone
        // Send the time in the user's preferred format so the AI reads
        // it naturally — "3:23 PM" vs "15:23"
        if uses24Hour {
            formatterTime.dateFormat = "HH:mm"
        } else {
            formatterTime.dateFormat = "h:mm a"
        }

        let formatterDate = DateFormatter()
        formatterDate.dateFormat = "yyyy-MM-dd"
        formatterDate.timeZone = timezone

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
            unlimited_snooze: alarm.unlimitedSnooze,
            uses_24_hour: uses24Hour
        )
    }

    /// Checks whether the user's device is set to 24-hour time.
    private static func deviceUses24HourTime() -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("j")
        let format = formatter.dateFormat ?? ""
        return !format.contains("a")
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
