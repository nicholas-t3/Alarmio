//
//  LiveActivitySync.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/16/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation
import Supabase

/// Thin sync layer between the client and the `live_activities` +
/// `alarm_schedules` Supabase tables.
///
/// - `live_activities` stores the user's APNs tokens + environment so
///   the server cron can address pushes. One row per user.
/// - `alarm_schedules` stores the minimal per-alarm info the cron needs
///   to decide which alarms are in their Live Activity lead window.
///
/// Called from `LiveActivityManager` (on token updates, foreground
/// reconcile) and from `AlarmStore` (on create/edit/delete).
@MainActor
final class LiveActivitySync {

    // MARK: - Singleton

    static let shared = LiveActivitySync()

    // MARK: - Dependencies

    private var client: Supabase.SupabaseClient {
        SupabaseClient.shared.client
    }

    private var userID: UUID? {
        SupabaseClient.shared.currentUserId
    }

    // MARK: - Tokens

    /// Upsert the push-to-start token for the current user. Preserves
    /// any existing `push_update_token` on the row.
    func upsertPushToStartToken(_ token: String, environment: String) async {
        guard let userID else { return }
        do {
            try await client
                .from("live_activities")
                .upsert(LiveActivityUpsert(
                    user_id: userID.uuidString,
                    push_to_start_token: token,
                    push_update_token: nil,
                    environment: environment
                ), onConflict: "user_id", ignoreDuplicates: false)
                .execute()
        } catch {
            print("[LiveActivitySync] upsert push_to_start failed: \(error)")
        }
    }

    /// Store the per-Activity update token. Called whenever a running
    /// Activity issues one via `pushTokenUpdates`.
    func upsertPushUpdateToken(_ token: String, environment: String) async {
        guard let userID else { return }
        do {
            try await client
                .from("live_activities")
                .upsert(LiveActivityUpsert(
                    user_id: userID.uuidString,
                    push_to_start_token: nil,
                    push_update_token: token,
                    environment: environment
                ), onConflict: "user_id", ignoreDuplicates: false)
                .execute()
        } catch {
            print("[LiveActivitySync] upsert push_update failed: \(error)")
        }
    }

    // MARK: - Alarm Schedules

    /// Upsert an alarm's Live Activity schedule row. Call whenever the
    /// alarm's wake time, repeat, title, or Live Activity settings change.
    func upsertAlarmSchedule(
        alarmID: UUID,
        fireDate: Date,
        leadHours: Int,
        title: String,
        tintHex: String = "3A6EAA"
    ) async {
        guard let userID else { return }
        do {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]

            try await client
                .from("alarm_schedules")
                .upsert(AlarmScheduleRow(
                    alarm_id: alarmID.uuidString,
                    user_id: userID.uuidString,
                    fire_date: iso.string(from: fireDate),
                    lead_hours: leadHours,
                    title: title,
                    tint_hex: tintHex
                ), onConflict: "alarm_id", ignoreDuplicates: false)
                .execute()
        } catch {
            print("[LiveActivitySync] upsert alarm_schedules failed: \(error)")
        }
    }

    /// Remove an alarm's schedule row. Call on alarm delete and when
    /// `liveActivityEnabled` flips to false.
    func deleteAlarmSchedule(alarmID: UUID) async {
        do {
            try await client
                .from("alarm_schedules")
                .delete()
                .eq("alarm_id", value: alarmID.uuidString)
                .execute()
        } catch {
            print("[LiveActivitySync] delete alarm_schedules failed: \(error)")
        }
    }

    // MARK: - Immediate Push

    /// Ask the Edge Function to recompute and push for this user right
    /// now instead of waiting up to a minute for the next cron tick.
    /// Runs the exact same diff-on-push logic as the cron — if the user
    /// has Live Activities off, no alarms in window, or nothing changed,
    /// it no-ops server-side. Fire-and-forget: errors are logged only.
    func triggerImmediatePush() async {
        guard let userID else {
            print("[LiveActivitySync] triggerImmediatePush SKIPPED — no userID (not authenticated)")
            return
        }
        print("[LiveActivitySync] triggerImmediatePush → invoking send-live-activity-push for user \(userID.uuidString.prefix(8))…")
        do {
            try await client.functions.invoke(
                "send-live-activity-push",
                options: FunctionInvokeOptions(
                    body: ImmediatePushRequest(user_id: userID.uuidString)
                )
            )
            print("[LiveActivitySync] triggerImmediatePush ✅ invoke returned OK")
        } catch {
            print("[LiveActivitySync] triggerImmediatePush ❌ failed: \(error)")
        }
    }
}

// MARK: - Payload Types

private struct LiveActivityUpsert: Encodable {
    let user_id: String
    let push_to_start_token: String?
    let push_update_token: String?
    let environment: String
}

private struct AlarmScheduleRow: Encodable {
    let alarm_id: String
    let user_id: String
    let fire_date: String
    let lead_hours: Int
    let title: String
    let tint_hex: String
}

private struct ImmediatePushRequest: Encodable {
    let user_id: String
}
