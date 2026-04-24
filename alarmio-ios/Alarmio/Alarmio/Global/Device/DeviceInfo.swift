//
//  DeviceInfo.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI
import UIKit

@Observable
final class DeviceInfo {

    let screenWidth: CGFloat
    let screenHeight: CGFloat

    init() {
        let bounds = DeviceInfo.resolveScreenBounds()
        self.screenWidth = bounds.width
        self.screenHeight = bounds.height

        // Inject the real hardware screen height into any static detent
        // structs that can't read environment themselves.
        EditSummaryDetent.hardwareScreenHeight = bounds.height

        let sizeClass: String = {
            if bounds.height < 750 { return "COMPACT (SE/mini)" }
            if bounds.height > 900 { return "LARGE (Pro Max/Plus/Air)" }
            return "STANDARD"
        }()
        print("[DeviceInfo] \(Int(bounds.width))×\(Int(bounds.height))pt → \(sizeClass)")
    }

    // MARK: - Screen resolution (hardware, read once)

    /// Reads the true screen bounds from the connected window scene.
    /// Falls back to a reasonable default if no scene is attached yet.
    private static func resolveScreenBounds() -> CGRect {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        if let screen = scene?.screen {
            return screen.bounds
        }
        return CGRect(x: 0, y: 0, width: 393, height: 852)
    }

    // MARK: - Size Classes

    /// Compact: SE, mini, or anything under 750pt tall
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
