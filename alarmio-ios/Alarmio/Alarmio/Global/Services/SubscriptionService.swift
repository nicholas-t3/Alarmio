//
//  SubscriptionService.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/13/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation
import RevenueCat
import SwiftUI

/// Wraps RevenueCat and exposes the Pro entitlement as an observable `isPro`
/// flag. RevenueCat is the source of truth for subscription state; this
/// service is just a thin SwiftUI-friendly adapter.
///
/// In DEBUG builds, supports a UserDefaults-backed simulator override so you
/// can flip Pro on/off without real purchases.
@Observable
@MainActor
final class SubscriptionService {

    // MARK: - State

    private(set) var isPro: Bool = false
    private(set) var isLoading: Bool = true
    private(set) var simulatorOverride: SimulatorOverride?

    // MARK: - Constants

    /// Identifier for the Pro entitlement configured in the RevenueCat
    /// dashboard. Must match exactly.
    static let entitlementId = "pro"
    private static let overrideKey = "alarmio.dev.subscriptionOverride"

    // MARK: - Types

    enum SimulatorOverride: String {
        case forcePro
        case forceFree
    }

    // MARK: - Configuration

    /// Configure the RevenueCat SDK. Call once, early in app lifecycle.
    func configure() {
        Purchases.logLevel = .info
        Purchases.configure(withAPIKey: Secrets.revenueCatPublicKey)
        loadPersistedOverride()
        Task { await refresh() }
    }

    /// Link RC's anonymous app_user_id to the Supabase user id so a future
    /// webhook integration can reconcile entitlements across both systems.
    /// Call after Supabase anonymous auth completes.
    func identify(userId: String) async {
        guard simulatorOverride == nil else { return }
        _ = try? await Purchases.shared.logIn(userId)
        await refresh()
    }

    // MARK: - State Refresh

    /// Re-read entitlement state from RevenueCat (or the override) and
    /// update `isPro`.
    func refresh() async {
        if let override = simulatorOverride {
            isPro = (override == .forcePro)
            isLoading = false
            return
        }

        let info = try? await Purchases.shared.customerInfo()
        isPro = info?.entitlements[Self.entitlementId]?.isActive == true
        isLoading = false
    }

    // MARK: - Purchases

    /// Restore prior purchases. Throws on network failure.
    /// Returns true if an active entitlement was restored.
    @discardableResult
    func restorePurchases() async throws -> Bool {
        let info = try await Purchases.shared.restorePurchases()
        let active = info.entitlements[Self.entitlementId]?.isActive == true
        isPro = active
        return active
    }

    // MARK: - Simulator Override (DEBUG only)

    #if DEBUG
    /// Force a Pro/Free state for testing. Pass `nil` to clear and
    /// resume reading from RevenueCat.
    func setSimulatorOverride(_ override: SimulatorOverride?) {
        simulatorOverride = override
        if let override {
            UserDefaults.standard.set(override.rawValue, forKey: Self.overrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.overrideKey)
        }
        Task { await refresh() }
    }
    #endif

    // MARK: - Private

    private func loadPersistedOverride() {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: Self.overrideKey),
           let value = SimulatorOverride(rawValue: raw) {
            simulatorOverride = value
        }
        #endif
    }
}

// MARK: - Environment Key

struct SubscriptionServiceKey: EnvironmentKey {
    @MainActor static let defaultValue = SubscriptionService()
}

extension EnvironmentValues {
    var subscriptionService: SubscriptionService {
        get { self[SubscriptionServiceKey.self] }
        set { self[SubscriptionServiceKey.self] = newValue }
    }
}
