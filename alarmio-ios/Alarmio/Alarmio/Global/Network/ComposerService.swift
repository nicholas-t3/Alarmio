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
        if DevFlags.skipGeneration {
            return try await generateAndDownloadAudioSkipped(for: alarm)
        }

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

    /// Generates just the script text for a Pro custom-prompt preview.
    /// No TTS, no storage — runs only the OpenAI step on the server.
    /// The returned text is what the user reviews before accepting; when
    /// accepted it's stored on `AlarmConfiguration.approvedScriptText` and
    /// passed back to `compose-alarm` verbatim at audio-generation time.
    func previewAlarmText(
        draft: AlarmConfiguration,
        prompt: String,
        includes: Set<CustomPromptInclude>
    ) async throws -> String {
        if DevFlags.skipGeneration {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return stubPreviewText(prompt: prompt, includes: includes)
        }

        let request = PreviewAlarmRequest.from(
            alarm: draft,
            timezone: TimeZone.current,
            prompt: prompt,
            includes: includes
        )

        print("[Composer] >>> invoking preview-alarm-text (alarmId=\(request.alarm_id), includes=\(request.includes))")

        let response: PreviewAlarmResponse = try await apiClient.invokeFunction(
            "preview-alarm-text",
            body: request
        )

        print("[Composer] <<< preview script length=\(response.script_text.count)")
        return response.script_text
    }

    private func stubPreviewText(prompt: String, includes: Set<CustomPromptInclude>) -> String {
        let includeList = includes.map(\.label).sorted().joined(separator: ", ")
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let promptLine = trimmed.isEmpty ? "(no prompt)" : trimmed
        return """
        Good morning. This is a stubbed preview while the backend is offline.
        Prompt: \(promptLine)
        Includes: \(includeList.isEmpty ? "(none)" : includeList)
        Time to rise — today is going to be a good one.
        """
    }

    // MARK: - Dev skip path

    /// Dev-only shortcut: skips the Composer API entirely. Copies bundled
    /// `alarm1/2/3.mp3` into the per-alarm indexed filenames (index 0..2
    /// map to alarm1/2/3, index ≥3 falls back to alarm1) so the rest of
    /// the scheduling / playback path resolves exactly as it would for a
    /// Composer-generated alarm. Waits 3s to preserve the "generating"
    /// UX delay.
    private func generateAndDownloadAudioSkipped(for alarm: AlarmConfiguration) async throws -> String {
        print("[Composer] >>> DEV SKIP: reusing bundled alarm1/2/3 for alarmId=\(alarm.id.uuidString)")

        try await Task.sleep(nanoseconds: 3_000_000_000)

        // Count of indices to materialize: initial (0) + one per snooze.
        // Unlimited mode mirrors the real Composer contract: 2 files
        // (initial + loop).
        let indexCount: Int = alarm.unlimitedSnooze ? 2 : alarm.maxSnoozes + 1

        let nonce = AudioFileManager.newAudioNonce()

        for index in 0..<indexCount {
            let sourceName = bundledFallbackName(for: index)
            guard let sourceURL = Bundle.main.url(forResource: sourceName, withExtension: "mp3") else {
                throw APIError.unknown(NSError(
                    domain: "ComposerService.DevSkip",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "\(sourceName).mp3 not found in main bundle"]
                ))
            }
            let bytes = try Data(contentsOf: sourceURL)
            _ = try audioFileManager.saveSound(
                data: bytes,
                for: alarm.id,
                index: index,
                nonce: nonce
            )
            print("[Composer]     DEV SKIP file[\(index)] copied from \(sourceName).mp3 bytes=\(bytes.count)")
        }

        let resultName = audioFileManager.indexedFileName(for: alarm.id, index: 0, nonce: nonce)
        print("[Composer] === DEV SKIP saved initial as \(resultName)")
        return resultName
    }

    /// Maps an audio index to one of the three bundled test clips.
    /// 0→alarm1, 1→alarm2, 2→alarm3, 3+→alarm1.
    private func bundledFallbackName(for index: Int) -> String {
        switch index {
        case 0: return "alarm1"
        case 1: return "alarm2"
        case 2: return "alarm3"
        default: return "alarm1"
        }
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
    let custom_prompt_includes: [String]
    /// When non-nil the server TTSs this verbatim for index 0 and skips OpenAI.
    let approved_script: String?
    /// When false the server returns only 2 files (initial + loop) regardless of max_snoozes.
    let creative_snoozes: Bool
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
            custom_prompt_includes: alarm.customPromptIncludes.map(\.rawValue).sorted(),
            approved_script: alarm.approvedScriptText,
            creative_snoozes: alarm.creativeSnoozes,
            max_snoozes: alarm.maxSnoozes,
            snooze_interval_minutes: alarm.snoozeInterval,
            unlimited_snooze: alarm.unlimitedSnooze,
            uses_24_hour: uses24Hour
        )
    }

    /// Checks whether the user's device is set to 24-hour time.
    fileprivate static func deviceUses24HourTime() -> Bool {
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

// MARK: - Preview (text-only) Types

struct PreviewAlarmRequest: Codable, Sendable {
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
    let custom_prompt: String
    let includes: [String]
    let uses_24_hour: Bool

    static func from(
        alarm: AlarmConfiguration,
        timezone: TimeZone,
        prompt: String,
        includes: Set<CustomPromptInclude>
    ) -> PreviewAlarmRequest {
        let uses24Hour = ComposeRequest.deviceUses24HourTime()

        let formatterTime = DateFormatter()
        formatterTime.timeZone = timezone
        formatterTime.dateFormat = uses24Hour ? "HH:mm" : "h:mm a"

        let formatterDate = DateFormatter()
        formatterDate.dateFormat = "yyyy-MM-dd"
        formatterDate.timeZone = timezone

        let wakeDate = alarm.wakeTime ?? Date()

        return PreviewAlarmRequest(
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
            custom_prompt: prompt,
            includes: includes.map(\.rawValue).sorted(),
            uses_24_hour: uses24Hour
        )
    }
}

struct PreviewAlarmResponse: Codable, Sendable {
    let script_text: String
}
