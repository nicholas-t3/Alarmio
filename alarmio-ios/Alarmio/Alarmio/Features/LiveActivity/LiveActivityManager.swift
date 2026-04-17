//
//  LiveActivityManager.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/16/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import ActivityKit
import Foundation
import SwiftUI

/// Owns the single consolidated countdown Live Activity for the current
/// user. Responsibilities:
///
/// 1. **Token lifecycle** — subscribes to `pushToStartTokenUpdates` (for
///    remote starts when no Activity exists) and to each live Activity's
///    `pushTokenUpdates` (for remote updates/ends once one is running).
///    Uploads both to Supabase so the server-side cron can target the
///    right one.
/// 2. **Alarm schedule sync** — on alarm create/edit/delete and on
///    foreground, computes the next `fireDate` for every enabled alarm
///    with `liveActivityEnabled == true` and upserts the row in the
///    `alarm_schedules` table. The backend cron decides who enters the
///    card.
/// 3. **Local fallback starts** — on foreground, if the user has alarms
///    currently in their lead window but no Activity is running, starts
///    one locally with the correct `ContentState`. Acts as belt-and-
///    suspenders against APNs delivery gaps.
/// 4. **Local updates from intents** — called by `SnoozeAlarmIntent` and
///    `StopAlarmIntent` to update or end the active Activity in the
///    same transaction as the AlarmKit reschedule.
///
/// The backend push pipeline is the primary driver; this manager exists
/// to keep the server in sync and to paper over the narrow window where
/// the app is foregrounded and should immediately reflect current state.
@Observable
@MainActor
final class LiveActivityManager {

    // MARK: - State

    /// Current push-to-start token, if any. Kept for debug surfacing.
    private(set) var pushToStartToken: String?

    // MARK: - Dependencies

    private let scheduler: AlarmScheduler

    // MARK: - Constants

    /// Hard cap on alarm entries rendered in the card. Overflow goes
    /// into the "+ N more" footer. Matches widget UI cap.
    static let maxDisplayedEntries = 2

    // MARK: - Init

    init(scheduler: AlarmScheduler) {
        self.scheduler = scheduler
    }

    // MARK: - Lifecycle

    /// Called once from `RootView` after the app authenticates.
    /// Kicks off the token observer tasks and a first reconcile.
    func start() {
        print("[LiveActivityManager] start() called")
        Task { [weak self] in
            print("[LiveActivityManager] entering pushToStartTokenUpdates loop")
            await self?.observePushToStartTokens()
            print("[LiveActivityManager] pushToStartTokenUpdates loop exited")
        }
        Task { [weak self] in
            await self?.observeExistingActivityTokens()
        }
    }

    // MARK: - Reconciliation

    /// Compute which alarms belong in the card right now and align the
    /// active Activity with that set. Safe to call from `.scenePhase`
    /// foreground transitions and after any alarm edit.
    ///
    /// - Parameter alarms: the current in-memory alarm list from
    ///   `AlarmStore`. The manager does not read storage itself — keeps
    ///   it testable and avoids a circular dependency.
    func reconcile(alarms: [AlarmConfiguration]) async {
        let now = Date()
        let entries = computeEntries(from: alarms, now: now)
        let state = CountdownActivityAttributes.ContentState(
            entries: Array(entries.prefix(Self.maxDisplayedEntries)),
            additionalCount: max(0, entries.count - Self.maxDisplayedEntries)
        )

        let existing = Activity<CountdownActivityAttributes>.activities.first

        if entries.isEmpty {
            // Nothing in window — end any running activity.
            if let existing {
                await existing.end(nil, dismissalPolicy: .immediate)
                print("[LiveActivityManager] ended activity — no alarms in window")
            }
            return
        }

        if let existing {
            // Update if the state actually changed. `Hashable` on
            // ContentState makes this a cheap comparison.
            if existing.content.state != state {
                await existing.update(ActivityContent(state: state, staleDate: nil))
                print("[LiveActivityManager] updated activity — \(entries.count) entries")
            }
        } else {
            // Start locally.
            do {
                let attrs = CountdownActivityAttributes(userID: currentUserID())
                let activity = try Activity.request(
                    attributes: attrs,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: .token
                )
                observeUpdateToken(for: activity)
                print("[LiveActivityManager] started activity id=\(activity.id)")
            } catch {
                print("[LiveActivityManager] start failed: \(error)")
            }
        }
    }

    /// Convenience entry point for callers that don't have the alarm
    /// list on hand. Loads from App Group defaults, mirroring what
    /// `SnoozeAlarmIntent` already does. Do not call from inside a hot
    /// loop — loads+decodes the whole list each time.
    func reconcileFromSharedStore() async {
        guard let data = AppGroup.defaults.data(forKey: AppGroup.alarmConfigurationsKey),
              let alarms = try? JSONDecoder().decode([AlarmConfiguration].self, from: data) else {
            return
        }
        await reconcile(alarms: alarms)
    }

    // MARK: - Entry Computation

    private func computeEntries(
        from alarms: [AlarmConfiguration],
        now: Date
    ) -> [CountdownActivityAttributes.Entry] {
        alarms
            .compactMap { alarm -> CountdownActivityAttributes.Entry? in
                guard alarm.isEnabled,
                      alarm.liveActivityEnabled,
                      let fireDate = scheduler.buildIntendedFireDate(from: alarm, referenceDate: now)
                else { return nil }

                let leadSeconds = TimeInterval(alarm.liveActivityLeadHours) * 3600
                let windowStart = fireDate.addingTimeInterval(-leadSeconds)

                // Only include alarms currently in their lead window.
                guard now >= windowStart && now < fireDate else { return nil }

                return CountdownActivityAttributes.Entry(
                    alarmID: alarm.id.uuidString,
                    title: alarm.name ?? "Alarmio Alarm",
                    fireDate: fireDate,
                    tintHex: "3A6EAA"
                )
            }
            .sorted { $0.fireDate < $1.fireDate }
    }

    // MARK: - Token Observation

    private func observePushToStartTokens() async {
        for await tokenData in Activity<CountdownActivityAttributes>.pushToStartTokenUpdates {
            let token = tokenData.map { String(format: "%02x", $0) }.joined()
            pushToStartToken = token
            print("[LiveActivityManager] push-to-start token: \(token.prefix(12))…")
            await uploadPushToStartToken(token)
        }
    }

    /// Watches Activities started before this launch (e.g. by APNs while
    /// the app was closed) so we can capture their per-Activity update
    /// tokens and forward them to the server.
    private func observeExistingActivityTokens() async {
        for activity in Activity<CountdownActivityAttributes>.activities {
            observeUpdateToken(for: activity)
        }
        for await activity in Activity<CountdownActivityAttributes>.activityUpdates {
            observeUpdateToken(for: activity)
        }
    }

    private func observeUpdateToken(for activity: Activity<CountdownActivityAttributes>) {
        Task { [weak self] in
            for await tokenData in activity.pushTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                print("[LiveActivityManager] update token: \(token.prefix(12))… (activity=\(activity.id))")
                await self?.uploadUpdateToken(token, activityID: activity.id)
            }
        }
    }

    // MARK: - Supabase Upload (Phase 2 wires these up)

    private func uploadPushToStartToken(_ token: String) async {
        await LiveActivitySync.shared.upsertPushToStartToken(
            token,
            environment: apnsEnvironment()
        )
    }

    private func uploadUpdateToken(_ token: String, activityID: String) async {
        await LiveActivitySync.shared.upsertPushUpdateToken(
            token,
            environment: apnsEnvironment()
        )
    }

    // MARK: - Private Helpers

    private func currentUserID() -> String {
        SupabaseClient.shared.currentUserId?.uuidString ?? "anonymous"
    }

    private func apnsEnvironment() -> String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }
}

// MARK: - Environment Key

struct LiveActivityManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: LiveActivityManager = {
        let store = AlarmStore.create()
        return LiveActivityManager(scheduler: store.scheduler)
    }()
}

extension EnvironmentValues {
    var liveActivityManager: LiveActivityManager {
        get { self[LiveActivityManagerKey.self] }
        set { self[LiveActivityManagerKey.self] = newValue }
    }
}
