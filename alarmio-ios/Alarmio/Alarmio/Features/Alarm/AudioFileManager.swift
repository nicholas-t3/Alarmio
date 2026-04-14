//
//  AudioFileManager.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/3/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation

@MainActor
final class AudioFileManager {

    // MARK: - Constants

    static let defaultSoundFileName = "default_alarm.mp3"
    private static let soundsDirectoryName = "Sounds"
    private static let defaultBundleResource = "calm_guide"
    private static let defaultBundleExtension = "mp3"

    // MARK: - Computed Properties

    private var soundsDirectory: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.soundsDirectoryName)
    }

    // MARK: - Setup

    func ensureSetup() {
        do {
            try ensureSoundsDirectory()
            copyDefaultSoundIfNeeded()
            copyTestAlarmSoundsIfNeeded()
        } catch {
            print("[AudioFileManager] Setup failed: \(error)")
        }
    }

    /// POC test: copies alarm1.mp3 / alarm2.mp3 / alarm3.mp3 from the bundle
    /// into Library/Sounds/ so AlarmKit can reference them by filename.
    /// Used to prove per-snooze audio swapping works end-to-end.
    private func copyTestAlarmSoundsIfNeeded() {
        for name in ["alarm1", "alarm2", "alarm3"] {
            let destinationURL = soundsDirectory.appendingPathComponent("\(name).mp3")
            // Always overwrite for the POC so rebuilds pick up any changes.
            try? FileManager.default.removeItem(at: destinationURL)

            guard let bundleURL = Bundle.main.url(forResource: name, withExtension: "mp3") else {
                print("[AudioFileManager] \(name).mp3 not found in bundle")
                continue
            }
            do {
                try FileManager.default.copyItem(at: bundleURL, to: destinationURL)
                print("[AudioFileManager] copied \(name).mp3 → \(destinationURL.lastPathComponent)")
            } catch {
                print("[AudioFileManager] failed to copy \(name).mp3: \(error)")
            }
        }
    }

    // MARK: - Sound Resolution

    func soundFileName(for alarmId: UUID, configured: String? = nil) -> String {
        // Priority 1: Explicitly configured filename (from Composer)
        if let configured, fileExists(named: configured) {
            return configured
        }

        // Priority 2: Custom generated file for this alarm (legacy single-file scheme)
        let customName = "alarm_\(alarmId.uuidString).mp3"
        if fileExists(named: customName) {
            return customName
        }

        // Priority 3: Any indexed-0 file on disk (covers nonce-suffixed names)
        let prefix = "alarm_\(alarmId.uuidString)_0"
        if let match = (try? FileManager.default.contentsOfDirectory(atPath: soundsDirectory.path))?
            .first(where: { $0.hasPrefix(prefix) && $0.hasSuffix(".mp3") }) {
            return match
        }

        // Priority 4: Default fallback
        return Self.defaultSoundFileName
    }

    func hasCustomSound(for alarmId: UUID) -> Bool {
        let customName = "alarm_\(alarmId.uuidString).mp3"
        return fileExists(named: customName)
    }

    // MARK: - File Management

    @discardableResult
    func saveSound(data: Data, for alarmId: UUID, extension ext: String = "mp3") throws -> String {
        try ensureSoundsDirectory()
        let fileName = "alarm_\(alarmId.uuidString).\(ext)"
        let fileURL = soundsDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileName
    }

    /// Indexed filename for a per-snooze-fire audio file.
    /// Index 0 = initial fire, 1+ = snooze chain.
    /// Includes a nonce so every (re)generation writes to a fresh path —
    /// this sidesteps AVAudioPlayer / CDN caching on overwrite.
    func indexedFileName(for alarmId: UUID, index: Int, nonce: String) -> String {
        "alarm_\(alarmId.uuidString)_\(index)_\(nonce).mp3"
    }

    /// Generates a short, URL-safe nonce used to freshen regenerated files.
    static func newAudioNonce() -> String {
        UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .prefix(8)
            .lowercased()
    }

    /// Saves a per-index sound file using a nonce-suffixed filename.
    @discardableResult
    func saveSound(
        data: Data,
        for alarmId: UUID,
        index: Int,
        nonce: String,
        extension ext: String = "mp3"
    ) throws -> String {
        try ensureSoundsDirectory()
        let fileName = "alarm_\(alarmId.uuidString)_\(index)_\(nonce).\(ext)"
        let fileURL = soundsDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileName
    }

    /// Deletes every indexed audio file (any nonce) belonging to the given
    /// alarm, except those whose nonce appears in `keepingNonce`. Used on
    /// save-commit so orphaned preview files from abandoned regenerations
    /// get cleaned up without touching the freshly-committed nonce.
    func purgeIndexedSounds(for alarmId: UUID, keepingNonce: String? = nil) {
        let prefix = "alarm_\(alarmId.uuidString)_"
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(atPath: soundsDirectory.path)) ?? []
        for name in contents where name.hasPrefix(prefix) && name.hasSuffix(".mp3") {
            if let keepingNonce, name.contains("_\(keepingNonce).") { continue }
            let url = soundsDirectory.appendingPathComponent(name)
            try? fm.removeItem(at: url)
        }
    }

    func deleteSound(for alarmId: UUID) {
        let customName = "alarm_\(alarmId.uuidString).mp3"
        let fileURL = soundsDirectory.appendingPathComponent(customName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Private Methods

    private func ensureSoundsDirectory() throws {
        try FileManager.default.createDirectory(
            at: soundsDirectory,
            withIntermediateDirectories: true
        )
    }

    private func copyDefaultSoundIfNeeded() {
        let destinationURL = soundsDirectory.appendingPathComponent(Self.defaultSoundFileName)
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else { return }

        guard let bundleURL = Bundle.main.url(
            forResource: Self.defaultBundleResource,
            withExtension: Self.defaultBundleExtension
        ) else {
            print("[AudioFileManager] Default sound not found in bundle")
            return
        }

        do {
            try FileManager.default.copyItem(at: bundleURL, to: destinationURL)
        } catch {
            print("[AudioFileManager] Failed to copy default sound: \(error)")
        }
    }

    func soundFileURL(named fileName: String) -> URL {
        soundsDirectory.appendingPathComponent(fileName)
    }

    func fileExists(named fileName: String) -> Bool {
        let fileURL = soundsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}
