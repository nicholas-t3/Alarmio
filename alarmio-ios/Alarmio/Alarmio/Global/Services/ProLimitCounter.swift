//
//  ProLimitCounter.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/23/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation
import SwiftUI

/// Tracks two device-local, lifetime generation budgets for free users:
///
/// - `mainCount` (cap 4) — increments when a free user successfully
///   generates audio from Create or Edit.
/// - `onboardingCount` (cap 10) — increments when a free user successfully
///   generates audio anywhere in onboarding.
///
/// Pro subscribers bypass both counters (never gated, never incremented).
/// Counters persist in Keychain so uninstall/reinstall does NOT refund
/// generations. Counters never decrement — deleting an alarm doesn't give
/// a free generation back.
///
/// Every mutation logs a `[ProLimit]` line to the console for test
/// observability.
@Observable
@MainActor
final class ProLimitCounter {

    // MARK: - Constants

    static let mainCap = 4
    static let onboardingCap = 10

    private static let mainKey = "main_count"
    private static let onboardingKey = "onboarding_count"

    // MARK: - State

    private(set) var mainCount: Int
    private(set) var onboardingCount: Int

    // MARK: - Init

    init() {
        let main = KeychainStore.readInt(forKey: Self.mainKey) ?? 0
        let onboarding = KeychainStore.readInt(forKey: Self.onboardingKey) ?? 0
        self.mainCount = main
        self.onboardingCount = onboarding
        print("[ProLimit] loaded from keychain → main=\(main)/\(Self.mainCap), onboarding=\(onboarding)/\(Self.onboardingCap)")
    }

    // MARK: - Queries

    var mainRemaining: Int { max(0, Self.mainCap - mainCount) }
    var onboardingRemaining: Int { max(0, Self.onboardingCap - onboardingCount) }

    /// Pro users always allowed. Free users allowed only while under cap.
    func canUseMain(isPro: Bool) -> Bool {
        let allow = isPro || mainCount < Self.mainCap
        print("[ProLimit] gate check: main=\(mainCount)/\(Self.mainCap) isPro=\(isPro) allow=\(allow)")
        return allow
    }

    func canUseOnboarding(isPro: Bool) -> Bool {
        let allow = isPro || onboardingCount < Self.onboardingCap
        print("[ProLimit] gate check: onboarding=\(onboardingCount)/\(Self.onboardingCap) isPro=\(isPro) allow=\(allow)")
        return allow
    }

    // MARK: - Mutations

    /// Increments the main counter and persists to Keychain. Callers must
    /// gate on `!isPro` — this method doesn't check, it just mutates.
    func incrementMain() {
        mainCount += 1
        persist(mainCount, forKey: Self.mainKey)
        print("[ProLimit] main +1 → \(mainCount)/\(Self.mainCap)")
    }

    func incrementOnboarding() {
        onboardingCount += 1
        persist(onboardingCount, forKey: Self.onboardingKey)
        print("[ProLimit] onboarding +1 → \(onboardingCount)/\(Self.onboardingCap)")
    }

    // MARK: - Debug Resets

    #if DEBUG
    /// Zeros both counters and wipes their Keychain entries.
    func resetAll() {
        mainCount = 0
        onboardingCount = 0
        try? KeychainStore.delete(forKey: Self.mainKey)
        try? KeychainStore.delete(forKey: Self.onboardingKey)
        print("[ProLimit] reset all → main=0/\(Self.mainCap), onboarding=0/\(Self.onboardingCap)")
    }

    /// Zeros the main counter only. Leaves onboarding alone. Useful for
    /// repeatedly testing the main-flow paywall without re-running
    /// onboarding.
    func resetMain() {
        mainCount = 0
        try? KeychainStore.delete(forKey: Self.mainKey)
        print("[ProLimit] reset main → main=0/\(Self.mainCap) (onboarding=\(onboardingCount)/\(Self.onboardingCap) unchanged)")
    }
    #endif

    // MARK: - Private

    private func persist(_ value: Int, forKey key: String) {
        do {
            try KeychainStore.writeInt(value, forKey: key)
        } catch {
            print("[ProLimit][ERROR] keychain write failed for \(key): \(error)")
        }
    }
}

// MARK: - Environment Key

struct ProLimitCounterKey: EnvironmentKey {
    @MainActor static let defaultValue = ProLimitCounter()
}

extension EnvironmentValues {
    var proLimitCounter: ProLimitCounter {
        get { self[ProLimitCounterKey.self] }
        set { self[ProLimitCounterKey.self] = newValue }
    }
}
