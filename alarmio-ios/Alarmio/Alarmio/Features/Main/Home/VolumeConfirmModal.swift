//
//  VolumeConfirmModal.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/27/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation
import SwiftUI

/// One-shot interruption that nudges the user to verify their ringtone
/// volume after an alarm is scheduled. Distinct from `VolumeTipCard`'s
/// passive coach mark on the home screen — different surface, different
/// opt-out flag.
enum VolumeConfirmModal {

    /// `@AppStorage` key for the "Don't show this again" suppression flag.
    /// Intentionally separate from `volumeTipDismissed` so dismissing one
    /// does not silence the other.
    static let dismissedKey = "volumeConfirmModalDismissed"

    /// Persists the most recently observed alarm count. Used as the
    /// reference point for the count-grew trigger so we don't fire on
    /// the AlarmStore.load() hydration after a cold launch. Unset key
    /// returns 0 — exactly what we want for first-ever launch.
    static let lastSeenAlarmCountKey = "volumeConfirmModalLastSeenAlarmCount"

    /// Count-aware variant: fires only when `currentCount` exceeds the
    /// last value we persisted (a real insert), and always syncs the
    /// stored value so deletions track downward without firing.
    @MainActor
    static func presentIfNeededForCurrentCount(_ currentCount: Int, via alertManager: AlertManager) {
        let lastSeen = UserDefaults.standard.integer(forKey: lastSeenAlarmCountKey)
        defer { UserDefaults.standard.set(currentCount, forKey: lastSeenAlarmCountKey) }
        guard currentCount > lastSeen else { return }
        presentIfNeeded(via: alertManager)
    }

    /// Presents the modal unless the user has already opted out.
    @MainActor
    static func presentIfNeeded(via alertManager: AlertManager) {
        guard !UserDefaults.standard.bool(forKey: dismissedKey) else { return }
        alertManager.showModal(
            title: "Confirm Volume",
            message: """
                Alarm volume follows your ringtone volume. Adjust it here:

                1. Open Settings, then tap Sounds & Haptics.
                2. Drag the "Ringtone and Alert Volume" slider to your desired volume.
                """,
            dismissible: true,
            primaryAction: AlertAction(label: "Got It") {},
            secondaryAction: AlertAction(label: "Don't show this again") {
                UserDefaults.standard.set(true, forKey: dismissedKey)
            }
        )
    }
}

// MARK: - Preview

#Preview {
    let alertManager = AlertManager()

    return ZStack {
        NightSkyBackground()
        GlobalAlertOverlay()
    }
    .environment(\.alertManager, alertManager)
    .onAppear {
        UserDefaults.standard.set(false, forKey: VolumeConfirmModal.dismissedKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            VolumeConfirmModal.presentIfNeeded(via: alertManager)
        }
    }
}
