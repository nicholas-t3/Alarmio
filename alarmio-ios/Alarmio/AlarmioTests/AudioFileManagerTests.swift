//
//  AudioFileManagerTests.swift
//  AlarmioTests
//
//  Created by Parenthood ApS on 4/3/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Testing
import Foundation
@testable import Alarmio

@MainActor
struct AudioFileManagerTests {

    // MARK: - Helpers

    private func makeManager() -> AudioFileManager {
        AudioFileManager()
    }

    // MARK: - Sound Resolution

    @Test("No custom file, no configured name → default")
    func defaultFallback() {
        let manager = makeManager()
        let alarmId = UUID()

        let result = manager.soundFileName(for: alarmId, configured: nil)
        #expect(result == AudioFileManager.defaultSoundFileName)
    }

    @Test("Configured name with non-existent file → default")
    func configuredButMissing() {
        let manager = makeManager()
        let alarmId = UUID()

        let result = manager.soundFileName(for: alarmId, configured: "nonexistent_file.mp3")

        // File doesn't exist, so should fall through
        // If custom alarm file also doesn't exist, returns default
        if !manager.hasCustomSound(for: alarmId) {
            #expect(result == AudioFileManager.defaultSoundFileName)
        }
    }

    @Test("hasCustomSound returns false for new alarm ID")
    func noCustomSoundForNewAlarm() {
        let manager = makeManager()
        let alarmId = UUID()

        #expect(manager.hasCustomSound(for: alarmId) == false)
    }

    @Test("saveSound creates file and hasCustomSound returns true")
    func saveSoundCreatesFile() throws {
        let manager = makeManager()
        manager.ensureSetup()
        let alarmId = UUID()

        let testData = Data("test audio content".utf8)
        let fileName = try manager.saveSound(data: testData, for: alarmId)

        #expect(fileName == "alarm_\(alarmId.uuidString).mp3")
        #expect(manager.hasCustomSound(for: alarmId) == true)

        // Cleanup
        manager.deleteSound(for: alarmId)
        #expect(manager.hasCustomSound(for: alarmId) == false)
    }

    @Test("soundFileName returns custom file when it exists")
    func customFileReturned() throws {
        let manager = makeManager()
        manager.ensureSetup()
        let alarmId = UUID()

        let testData = Data("test".utf8)
        _ = try manager.saveSound(data: testData, for: alarmId)

        let result = manager.soundFileName(for: alarmId, configured: nil)
        #expect(result == "alarm_\(alarmId.uuidString).mp3")

        // Cleanup
        manager.deleteSound(for: alarmId)
    }

    @Test("deleteSound removes the file")
    func deleteSoundRemoves() throws {
        let manager = makeManager()
        manager.ensureSetup()
        let alarmId = UUID()

        let testData = Data("test".utf8)
        _ = try manager.saveSound(data: testData, for: alarmId)
        #expect(manager.hasCustomSound(for: alarmId) == true)

        manager.deleteSound(for: alarmId)
        #expect(manager.hasCustomSound(for: alarmId) == false)
    }
}
