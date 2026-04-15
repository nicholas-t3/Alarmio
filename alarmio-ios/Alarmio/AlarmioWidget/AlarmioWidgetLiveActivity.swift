//
//  AlarmioWidgetLiveActivity.swift
//  AlarmioWidget
//
//  Created by Nicholas Towery on 4/15/26.
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// Empty Live Activity registration. Exists solely so the widget
/// extension binary is installed on disk — `extensiond` needs that
/// binary to spawn the extension process when the user taps Snooze
/// or Stop from the lock screen, which is how `SnoozeAlarmIntent` /
/// `StopAlarmIntent` run after force-quit.
///
/// All UI returns `EmptyView()` by design: we don't want any lock
/// screen card or Dynamic Island content, but AlarmKit still requires
/// a registered `ActivityConfiguration` matching the `AlarmAttributes`
/// metadata type used on scheduling (`AlarmAttributes<AlarmioMetadata>`).
struct AlarmioWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<AlarmioMetadata>.self) { _ in
            EmptyView()
        } dynamicIsland: { _ in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { EmptyView() }
                DynamicIslandExpandedRegion(.trailing) { EmptyView() }
                DynamicIslandExpandedRegion(.bottom) { EmptyView() }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                EmptyView()
            } minimal: {
                EmptyView()
            }
        }
    }
}
