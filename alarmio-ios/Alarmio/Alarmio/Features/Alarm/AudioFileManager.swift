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
        } catch {
            print("[AudioFileManager] Setup failed: \(error)")
        }
    }

    // MARK: - Sound Resolution

    func soundFileName(for alarmId: UUID, configured: String? = nil) -> String {
        // Priority 1: Explicitly configured filename (from Composer)
        if let configured, fileExists(named: configured) {
            return configured
        }

        // Priority 2: Custom generated file for this alarm
        let customName = "alarm_\(alarmId.uuidString).mp3"
        if fileExists(named: customName) {
            return customName
        }

        // Priority 3: Default fallback
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

    private func fileExists(named fileName: String) -> Bool {
        let fileURL = soundsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}
