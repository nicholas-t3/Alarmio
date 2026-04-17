//
//  CountdownActivityAttributes.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/16/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import ActivityKit
import Foundation

/// Live Activity attributes for the pre-alarm countdown card.
///
/// Deliberately separate from `AlarmAttributes<AlarmioMetadata>` —
/// AlarmKit's activity type is reserved for the empty intent-host
/// registration (`AlarmioWidgetLiveActivity`). This type drives our
/// own countdown UI.
///
/// Consolidated single-activity model: one Activity per user, carrying
/// up to 2 alarm entries in display order plus an overflow count.
/// The backend cron picks which alarms enter the card and updates
/// via APNs as alarms enter or leave their lead windows. The client
/// can also start/update/end locally (e.g. from `SnoozeAlarmIntent`).
///
/// Shared between main app and widget extension via dual target
/// membership.
struct CountdownActivityAttributes: ActivityAttributes {
    public struct Entry: Codable, Hashable, Identifiable {
        var id: String { alarmID }
        var alarmID: String
        var title: String
        var fireDate: Date
        var tintHex: String

        private enum CodingKeys: String, CodingKey {
            case alarmID, title, fireDate, tintHex
        }

        init(alarmID: String, title: String, fireDate: Date, tintHex: String) {
            self.alarmID = alarmID
            self.title = title
            self.fireDate = fireDate
            self.tintHex = tintHex
        }

        // ActivityKit's internal decoder for APNs payloads uses default
        // JSONDecoder date strategy (.deferredToDate = seconds since
        // 2001 reference). The server sends ISO8601 strings, so we
        // decode those explicitly here. Keeps wire shape readable
        // without forcing a TimeInterval everywhere on the Swift side.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.alarmID = try c.decode(String.self, forKey: .alarmID)
            self.title = try c.decode(String.self, forKey: .title)
            self.tintHex = try c.decode(String.self, forKey: .tintHex)

            let raw = try c.decode(String.self, forKey: .fireDate)
            guard let date = Entry.isoFormatter.date(from: raw) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .fireDate,
                    in: c,
                    debugDescription: "Expected ISO8601 date, got \(raw)"
                )
            }
            self.fireDate = date
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(alarmID, forKey: .alarmID)
            try c.encode(title, forKey: .title)
            try c.encode(tintHex, forKey: .tintHex)
            try c.encode(Entry.isoFormatter.string(from: fireDate), forKey: .fireDate)
        }

        private static let isoFormatter: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }()
    }

    public struct ContentState: Codable, Hashable {
        /// Sorted by fireDate ascending. UI renders up to 2.
        var entries: [Entry]
        /// Alarms in window beyond `entries.count`. 0 = no overflow.
        var additionalCount: Int
    }

    /// Stable identifier for this user's consolidated activity.
    /// Currently just the anon user ID — one Activity per user.
    var userID: String
}
