//
//  Secrets.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/13/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation

/// Centralized API keys and service endpoints.
///
/// These are the *public* keys that ship in the client binary. Supabase
/// anon keys and RevenueCat public app-specific keys are designed to be
/// exposed — security is enforced server-side via RLS and RevenueCat's
/// receipt validation respectively. Never put private/service-role keys here.
enum Secrets {
    static let revenueCatPublicKey = "appl_OaVrhYXbqqIHSRGPxbWOjpJHOHT"
}
