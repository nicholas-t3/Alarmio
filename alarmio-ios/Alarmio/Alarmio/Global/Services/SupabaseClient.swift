//
//  SupabaseClient.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/9/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation
import Supabase

/// Singleton wrapper around the Supabase Swift SDK.
///
/// On first launch, the app calls `ensureAuthenticated()` from `RootView`
/// to silently sign the user in anonymously. The SDK persists the session
/// in the keychain, so subsequent launches are no-ops.
@MainActor
final class SupabaseClient {

    // MARK: - Singleton

    static let shared = SupabaseClient()

    // MARK: - State

    let client: Supabase.SupabaseClient

    // MARK: - Init

    private init() {
        // Legacy anon key (JWT format) — safe to ship in the client.
        // The new sb_publishable_* format isn't yet supported by the Edge
        // Function gateway, so we use the legacy key which works everywhere.
        // Permissions are scoped by RLS; the dangerous service-role key
        // never leaves Supabase Edge Function secrets.
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhlcnl2cGFxaHdxc29tY2xjZXZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ4OTY1ODUsImV4cCI6MjA5MDQ3MjU4NX0.LXfcjpDIgbuCnpUhp7tfGxCDUBjQ3q4Ml-QBxtjvDKI"

        self.client = Supabase.SupabaseClient(
            supabaseURL: URL(string: "https://heryvpaqhwqsomclcevf.supabase.co")!,
            supabaseKey: anonKey
        )
    }

    // MARK: - Auth

    /// Ensures the app has an authenticated session.
    /// If a session already exists in the keychain, this is a no-op.
    /// Otherwise it calls `signInAnonymously()` and the SDK persists the result.
    func ensureAuthenticated() async throws {
        if (try? await client.auth.session) != nil {
            return
        }
        try await client.auth.signInAnonymously()
    }

    var currentUserId: UUID? {
        client.auth.currentUser?.id
    }
}
