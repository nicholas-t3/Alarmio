//
//  AppGroupDefaults.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/9/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation

/// Shared UserDefaults suite backed by the App Group entitlement, so both
/// the main app and the AlarmioWidget extension read/write the same alarm
/// storage. Without this, the widget extension process sees an empty
/// `UserDefaults.standard` and can't load alarm configurations when the
/// SnoozeAlarmIntent / StopAlarmIntent runs after force-quit.
enum AppGroup {
    static let identifier = "group.com.parenthoodaps.alarmio"

    /// Force-unwrap is acceptable here: if the App Group entitlement is
    /// missing, the app is fundamentally broken and we want to crash loudly
    /// during development rather than silently fall back to local defaults.
    static let defaults = UserDefaults(suiteName: identifier)!

    static let alarmConfigurationsKey = "alarm_configurations"
}
