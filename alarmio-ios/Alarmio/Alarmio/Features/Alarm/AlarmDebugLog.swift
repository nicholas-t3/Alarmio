//
//  AlarmDebugLog.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/20/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation
import os

/// Ring-buffer logger for AlarmKit diagnostics. Writes to App Group file
/// so widget extension + main app share the same stream. Readable via
/// Settings → "Export alarm logs".
///
/// Each call is also mirrored to `os.Logger` so Console.app / sysdiagnose
/// captures them with subsystem "com.parenthoodaps.alarmio" category "alarm".
enum AlarmDebugLog {

    private static let logger = Logger(subsystem: "com.parenthoodaps.alarmio", category: "alarm")
    private static let maxEntries = 500
    private static let fileURL: URL = {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        )!
        return container.appendingPathComponent("alarm_debug.log")
    }()
    private static let lock = NSLock()

    /// Append one line. Format: `ISO8601 [category] message`.
    static func log(_ category: String, _ message: String) {
        let ts = ISO8601DateFormatter.withMillis.string(from: Date())
        let line = "\(ts) [\(category)] \(message)\n"
        logger.log("\(category, privacy: .public): \(message, privacy: .public)")

        lock.lock()
        defer { lock.unlock() }

        // Append, then trim to maxEntries from the tail if we overflow.
        let existing = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        var combined = existing + line
        let lines = combined.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count > maxEntries {
            combined = lines.suffix(maxEntries).joined(separator: "\n") + "\n"
        }
        try? combined.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    static func readAll() -> String {
        lock.lock()
        defer { lock.unlock() }
        return (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "(empty)"
    }

    static func clear() {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileURL)
    }

    static var exportFileURL: URL { fileURL }
}

private extension ISO8601DateFormatter {
    static let withMillis: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
