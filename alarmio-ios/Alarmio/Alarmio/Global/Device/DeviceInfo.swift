//
//  DeviceInfo.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

@Observable
final class DeviceInfo {

    var screenWidth: CGFloat = 393
    var screenHeight: CGFloat = 852

    func updateScreenSize(width: CGFloat, height: CGFloat) {
        self.screenWidth = width
        self.screenHeight = height
    }

    // MARK: - Size Classes

    /// Compact: SE, mini, or anything under 700pt tall
    var isCompact: Bool {
        screenHeight < 750
    }

    /// Large: Pro Max, Plus, Air — anything over 900pt
    var isLarge: Bool {
        screenHeight > 900
    }

    /// Has home button (no bottom safe area)
    var hasHomeButton: Bool {
        let bottomInset = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.bottom) ?? 0
        return bottomInset == 0
    }

    // MARK: - Spacing Scale

    /// Multiplier for vertical spacing — compact devices get tighter layouts
    var spacingScale: CGFloat {
        if screenHeight < 700 { return 0.65 }       // SE
        if screenHeight < 750 { return 0.75 }       // Mini
        if screenHeight < 860 { return 1.0 }        // Standard
        return 1.0                                    // Pro Max, Air, etc.
    }
}

// MARK: - Environment

struct DeviceInfoKey: EnvironmentKey {
    static let defaultValue = DeviceInfo()
}

extension EnvironmentValues {
    var deviceInfo: DeviceInfo {
        get { self[DeviceInfoKey.self] }
        set { self[DeviceInfoKey.self] = newValue }
    }
}
