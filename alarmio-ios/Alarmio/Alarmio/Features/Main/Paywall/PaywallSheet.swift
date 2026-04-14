//
//  PaywallSheet.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/13/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

/// Wraps RevenueCat's `PaywallView` with our callbacks. The actual paywall
/// layout, copy, and products are configured in the RevenueCat dashboard
/// (Paywalls tab) and can be iterated on without an app rebuild.
///
/// Soft/skippable by default — shows a close button so free users can
/// dismiss and continue.
struct PaywallSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.subscriptionService) private var subscription

    // MARK: - Body

    var body: some View {
        PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { _ in
                Task {
                    await subscription.refresh()
                    HapticManager.shared.success()
                    dismiss()
                }
            }
            .onRestoreCompleted { _ in
                Task {
                    await subscription.refresh()
                    if subscription.isPro {
                        HapticManager.shared.success()
                        dismiss()
                    }
                }
            }
    }
}

// MARK: - Previews

#Preview("Paywall Sheet") {
    struct PreviewContainer: View {
        @State private var show = true

        var body: some View {
            ZStack {
                MorningSky(starOpacity: 0.8, showConstellations: false)
            }
            .sheet(isPresented: $show) {
                PaywallSheet()
            }
        }
    }

    return PreviewContainer()
}
