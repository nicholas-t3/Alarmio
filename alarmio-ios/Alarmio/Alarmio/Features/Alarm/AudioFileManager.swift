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

        // Priority 3: Indexed initial-fire file (new multi-file scheme)
        let indexedInitial = "alarm_\(alarmId.uuidString)_0.mp3"
        if fileExists(named: indexedInitial) {
            return indexedInitial
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
    func indexedFileName(for alarmId: UUID, index: Int) -> String {
        "alarm_\(alarmId.uuidString)_\(index).mp3"
    }

    /// Saves a per-index sound file. Used by ComposerService to lay down
    /// the N files returned for one composition.
    @discardableResult
    func saveSound(data: Data, for alarmId: UUID, index: Int, extension ext: String = "mp3") throws -> String {
        try ensureSoundsDirectory()
        let fileName = "alarm_\(alarmId.uuidString)_\(index).\(ext)"
        let fileURL = soundsDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileName
    }

    /// Deletes a set of indexed files for one alarm. Used when an alarm
    /// is removed or its audio is regenerated.
    func deleteSounds(for alarmId: UUID, indices: [Int]) {
        for index in indices {
            let fileName = "alarm_\(alarmId.uuidString)_\(index).mp3"
            let fileURL = soundsDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: fileURL)
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
