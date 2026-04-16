//
//  ProScriptReconciler.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/16/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation

/// Keeps `AlarmConfiguration.approvedScripts` in sync with later changes to
/// snooze count or wake/leave times, without forcing the user to re-approve
/// their text. Silent by design — the user's main message is preserved
/// word-for-word whenever possible.
///
/// Decision order (first match wins):
///   1. `alarmType != .pro` → return `new` unchanged.
///   2. No existing scripts → full regenerate.
///   3. Wake time changed with `.alarmTime` include on (or leave time changed
///      with `.leaveTime` on) → surgical time-rewrite of existing scripts.
///   4. After time reconciliation, if count matches expected → done.
///   5. Count too high → trim tail.
///   6. Count too low → keep existing main, regen snoozes from base_script.
///
/// "Expected count" is a pure function of `creativeSnoozes`, `unlimitedSnooze`,
/// `maxSnoozes`:
///   - creative off    → 1   (compose-alarm will loop the main for snoozes)
///   - unlimited       → 2   (main + 1 loop snooze)
///   - limited (N)     → 1 + N
struct ProScriptReconciler {

    let composer: ComposerService

    // MARK: - Public

    func reconcile(
        from old: AlarmConfiguration,
        to new: AlarmConfiguration
    ) async throws -> AlarmConfiguration {
        guard new.alarmType == .pro else { return new }

        let expected = expectedScriptCount(for: new)

        // 1. No scripts on a pro alarm — shouldn't happen, but defensive.
        guard let scripts = new.approvedScripts, !scripts.isEmpty else {
            return try await fullRegenerate(new: new, expected: expected)
        }

        var working = new

        // 2. Time drift. Rewrite the existing scripts in place (same words,
        //    only time references change). Runs if the time moved AND the
        //    user asked for that time to be referenced in the script.
        let wakeDrift = old.wakeTime != new.wakeTime
            && new.customPromptIncludes.contains(.alarmTime)
        let leaveDrift = old.leaveTime != new.leaveTime
            && new.customPromptIncludes.contains(.leaveTime)

        if wakeDrift || leaveDrift {
            let rewritten = try await composer.rewriteAlarmTimes(
                draft: new,
                scripts: scripts,
                oldWake: wakeDrift ? old.wakeTime : nil,
                newWake: wakeDrift ? new.wakeTime : nil,
                oldLeave: leaveDrift ? old.leaveTime : nil,
                newLeave: leaveDrift ? new.leaveTime : nil
            )
            working.approvedScripts = rewritten
        }

        let workingScripts = working.approvedScripts ?? scripts
        let currentCount = workingScripts.count

        // 3. Count matches (possibly after rewrite) — done. Voice/tone
        //    changes don't need text changes; compose-alarm will re-TTS.
        if currentCount == expected { return working }

        // 4. Count decreased — trim, no API.
        if currentCount > expected {
            working.approvedScripts = Array(workingScripts.prefix(expected))
            return working
        }

        // 5. Count increased — keep existing main, regen snoozes from it.
        let snoozesNeeded = expected - 1
        guard snoozesNeeded > 0 else {
            // Shouldn't happen (expected is always ≥ 1) but bail safely.
            return working
        }
        let newSnoozes = try await composer.generateCustomAlarmText(
            draft: working,
            prompt: working.customPrompt ?? "",
            includes: working.customPromptIncludes,
            snoozeCount: snoozesNeeded,
            baseScript: workingScripts[0]
        )
        working.approvedScripts = [workingScripts[0]] + newSnoozes
        return working
    }

    // MARK: - Private

    private func fullRegenerate(
        new: AlarmConfiguration,
        expected: Int
    ) async throws -> AlarmConfiguration {
        let scripts = try await composer.generateCustomAlarmText(
            draft: new,
            prompt: new.customPrompt ?? "",
            includes: new.customPromptIncludes,
            snoozeCount: max(0, expected - 1),
            baseScript: nil
        )
        var copy = new
        copy.approvedScripts = scripts
        return copy
    }

    private func expectedScriptCount(for c: AlarmConfiguration) -> Int {
        if !c.creativeSnoozes { return 1 }
        if c.unlimitedSnooze { return 2 }
        return 1 + c.maxSnoozes
    }
}
