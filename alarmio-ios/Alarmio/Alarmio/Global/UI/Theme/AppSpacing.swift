//
//  AppSpacing.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

enum AppSpacing {

    // MARK: - Screen Layout

    static let screenHorizontal: CGFloat = 24
    static let screenTopInset: CGFloat = 80

    static var screenBottom: CGFloat {
        let bottomInset = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.bottom) ?? 0
        return bottomInset > 0 ? 40 : 32
    }

    // MARK: - Content (fixed)

    static let tightGap: CGFloat = 8
    static let titleSubtitleGap: CGFloat = 12

    // MARK: - Content (scaled by DeviceInfo.spacingScale)

    static func sectionGap(_ scale: CGFloat) -> CGFloat { 48 * scale }
    static func itemGap(_ scale: CGFloat) -> CGFloat { 16 * scale }
    static func rowVertical(_ scale: CGFloat) -> CGFloat { 16 * scale }

    // MARK: - List Rows (fixed)

    static let rowHorizontal: CGFloat = 20
    static let rowIconWidth: CGFloat = 32
    static let rowIconGap: CGFloat = 16

    // MARK: - Bottom Bar

    static let bottomBarHeight: CGFloat = 130

    // MARK: - Selection Indicators

    static let selectionCircleSize: CGFloat = 28
    static let selectionCheckmarkSize: CGFloat = 12
    static let selectionStrokeWidth: CGFloat = 1.5
}
