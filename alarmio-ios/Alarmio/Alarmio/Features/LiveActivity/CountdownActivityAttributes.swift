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
