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

    /// Generates Pro custom-alarm scripts (text only — no TTS, no storage).
    ///
    /// Two modes, one endpoint:
    ///   - `baseScript == nil` → returns `1 + snoozeCount` scripts. `scripts[0]`
    ///     is the main wake-up message shown in the preview; `scripts[1...]`
    ///     are snoozes that escalate from it.
    ///   - `baseScript != nil` → returns exactly `snoozeCount` snooze scripts
    ///     that escalate from the approved main message. Used when snooze
    ///     count changes without the user wanting to re-pick the main text.
    func generateCustomAlarmText(
        draft: AlarmConfiguration,
        prompt: String,
        includes: Set<CustomPromptInclude>,
        snoozeCount: Int,
        baseScript: String? = nil
    ) async throws -> [String] {
        if DevFlags.skipGeneration {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return stubCustomAlarmScripts(
                prompt: prompt,
                includes: includes,
                snoozeCount: snoozeCount,
                baseScript: baseScript
            )
        }

        let request = GenerateCustomAlarmTextRequest.from(
            alarm: draft,
            timezone: TimeZone.current,
            prompt: prompt,
            includes: includes,
            snoozeCount: snoozeCount,
            baseScript: baseScript
        )

        print("[Composer] >>> invoking generate-custom-alarm-text (snoozes=\(snoozeCount), base=\(baseScript == nil ? "no" : "yes"), includes=\(request.includes))")

        let response: GenerateCustomAlarmTextResponse = try await apiClient.invokeFunction(
            "generate-custom-alarm-text",
            body: request
        )

        print("[Composer] <<< generated \(response.scripts.count) scripts")
        return response.scripts
    }

    /// Surgically rewrites time references in existing pro scripts without
    /// changing anything else. Returns a new array of the same length as
    /// `scripts` with the old wake/leave time values swapped for new ones.
    /// Voice, jokes, and structure are preserved word-for-word.
    ///
    /// At least one of (oldWake + newWake) or (oldLeave + newLeave) must be
    /// provided. Pass nil for the pair that didn't change.
    func rewriteAlarmTimes(
        draft: AlarmConfiguration,
        scripts: [String],
        oldWake: Date?,
        newWake: Date?,
        oldLeave: Date?,
        newLeave: Date?
    ) async throws -> [String] {
        if DevFlags.skipGeneration {
            try await Task.sleep(nanoseconds: 800_000_000)
            return scripts.map { stubRewriteScript($0, oldWake: oldWake, newWake: newWake) }
        }

        let request = RewriteAlarmTimesRequest.from(
            alarm: draft,
            timezone: TimeZone.current,
            scripts: scripts,
            oldWake: oldWake,
            newWake: newWake,
            oldLeave: oldLeave,
            newLeave: newLeave
        )

        print("[Composer] >>> invoking generate-custom-alarm-text (mode=rewrite, scripts=\(scripts.count), wakeDrift=\(request.old_wake_time_local != nil), leaveDrift=\(request.old_leave_time_local != nil))")

        let response: GenerateCustomAlarmTextResponse = try await apiClient.invokeFunction(
            "generate-custom-alarm-text",
            body: request
        )

        print("[Composer] <<< rewrote \(response.scripts.count) scripts")
        return response.scripts
    }

    private func stubRewriteScript(_ script: String, oldWake: Date?, newWake: Date?) -> String {
        guard let oldWake, let newWake else { return script }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return script.replacingOccurrences(of: f.string(from: oldWake), with: f.string(from: newWake))
    }

    private func stubCustomAlarmScripts(
        prompt: String,
        includes: Set<CustomPromptInclude>,
        snoozeCount: Int,
        baseScript: String?
    ) -> [String] {
        let includeList = includes.map(\.label).sorted().joined(separator: ", ")
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let promptLine = trimmed.isEmpty ? "(no prompt)" : trimmed

        if baseScript != nil {
            return (0..<snoozeCount).map { i in
                "Stub snooze \(i + 1). Still time to get up — includes: \(includeList.isEmpty ? "none" : includeList)."
            }
        }

        let main = """
        Good morning. This is a stubbed preview while the backend is offline.
        Prompt: \(promptLine)
        Includes: \(includeList.isEmpty ? "(none)" : includeList)
        Time to rise — today is going to be a good one.
        """
        let snoozes = (0..<snoozeCount).map { i in
            "Stub snooze \(i + 1). You hit snooze — time to get moving."
        }
        return [main] + snoozes
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
    let alarm_type: String
    let custom_prompt: String?
    let custom_prompt_includes: [String]
    /// When non-nil the server TTSs these verbatim (index 0 = main, 1..N =
    /// snoozes) and skips OpenAI entirely. Length must match what the
    /// caller expects the composition to contain.
    let approved_scripts: [String]?
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
            alarm_type: alarm.alarmType.rawValue,
            custom_prompt: alarm.customPrompt,
            custom_prompt_includes: alarm.customPromptIncludes.map(\.rawValue).sorted(),
            approved_scripts: alarm.approvedScripts,
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

// MARK: - Generate Custom Alarm Text Types

struct GenerateCustomAlarmTextRequest: Codable, Sendable {
    let voice_persona: String
    let tone: String?
    let intensity: String?
    let why_context: String?
    let custom_prompt: String
    let includes: [String]
    let wake_time_local: String?
    let leave_time_local: String?
    let timezone: String
    let snooze_count: Int
    let snooze_interval_minutes: Int?
    let base_script: String?
    let uses_24_hour: Bool

    static func from(
        alarm: AlarmConfiguration,
        timezone: TimeZone,
        prompt: String,
        includes: Set<CustomPromptInclude>,
        snoozeCount: Int,
        baseScript: String?
    ) -> GenerateCustomAlarmTextRequest {
        // Use 24h format on the wire — it's unambiguous for the server and
        // avoids locale-specific AM/PM formatting differences. The backend
        // echoes the exact string back in scripts if the user asks for it.
        let formatterTime = DateFormatter()
        formatterTime.timeZone = timezone
        formatterTime.dateFormat = "HH:mm"
        formatterTime.locale = Locale(identifier: "en_US_POSIX")

        let uses24Hour = ComposeRequest.deviceUses24HourTime()

        let wakeLocal = alarm.wakeTime.map { formatterTime.string(from: $0) }
        let leaveLocal = alarm.leaveTime.map { formatterTime.string(from: $0) }

        return GenerateCustomAlarmTextRequest(
            voice_persona: alarm.voicePersona?.rawValue ?? "calm_guide",
            tone: alarm.tone?.rawValue,
            intensity: alarm.intensity?.rawValue,
            why_context: alarm.whyContext?.rawValue,
            custom_prompt: prompt,
            includes: includes.map(\.rawValue).sorted(),
            wake_time_local: wakeLocal,
            leave_time_local: leaveLocal,
            timezone: timezone.identifier,
            snooze_count: snoozeCount,
            snooze_interval_minutes: alarm.snoozeInterval,
            base_script: baseScript,
            uses_24_hour: uses24Hour
        )
    }
}

struct GenerateCustomAlarmTextResponse: Codable, Sendable {
    let scripts: [String]
}

// MARK: - Rewrite Alarm Times

/// Sent to the same `generate-custom-alarm-text` endpoint but with the
/// rewrite-mode fields populated. `rewrite_scripts` triggers the time-swap
/// branch on the backend; `snooze_count` and `custom_prompt` are ignored in
/// that mode but are kept in the payload so the request shape stays
/// consistent.
struct RewriteAlarmTimesRequest: Codable, Sendable {
    let voice_persona: String
    let tone: String?
    let intensity: String?
    let why_context: String?
    let custom_prompt: String
    let includes: [String]
    let wake_time_local: String?
    let leave_time_local: String?
    let timezone: String
    let snooze_count: Int
    let snooze_interval_minutes: Int?
    let rewrite_scripts: [String]
    let old_wake_time_local: String?
    let new_wake_time_local: String?
    let old_leave_time_local: String?
    let new_leave_time_local: String?
    let uses_24_hour: Bool

    static func from(
        alarm: AlarmConfiguration,
        timezone: TimeZone,
        scripts: [String],
        oldWake: Date?,
        newWake: Date?,
        oldLeave: Date?,
        newLeave: Date?
    ) -> RewriteAlarmTimesRequest {
        let f = DateFormatter()
        f.timeZone = timezone
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")

        let uses24Hour = ComposeRequest.deviceUses24HourTime()
        let newWakeLocal = (newWake ?? alarm.wakeTime).map { f.string(from: $0) }
        let newLeaveLocal = (newLeave ?? alarm.leaveTime).map { f.string(from: $0) }

        return RewriteAlarmTimesRequest(
            voice_persona: alarm.voicePersona?.rawValue ?? "calm_guide",
            tone: alarm.tone?.rawValue,
            intensity: alarm.intensity?.rawValue,
            why_context: alarm.whyContext?.rawValue,
            custom_prompt: alarm.customPrompt ?? "",
            includes: alarm.customPromptIncludes.map(\.rawValue).sorted(),
            wake_time_local: newWakeLocal,
            leave_time_local: newLeaveLocal,
            timezone: timezone.identifier,
            snooze_count: 0,
            snooze_interval_minutes: alarm.snoozeInterval,
            rewrite_scripts: scripts,
            old_wake_time_local: oldWake.map { f.string(from: $0) },
            new_wake_time_local: newWake.map { f.string(from: $0) },
            old_leave_time_local: oldLeave.map { f.string(from: $0) },
            new_leave_time_local: newLeave.map { f.string(from: $0) },
            uses_24_hour: uses24Hour
        )
    }
}
