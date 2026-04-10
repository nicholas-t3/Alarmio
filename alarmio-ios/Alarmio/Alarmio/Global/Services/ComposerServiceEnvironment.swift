//
//  ComposerServiceEnvironment.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/9/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

private struct ComposerServiceKey: EnvironmentKey {
    static let defaultValue: ComposerService? = nil
}

extension EnvironmentValues {
    var composerService: ComposerService? {
        get { self[ComposerServiceKey.self] }
        set { self[ComposerServiceKey.self] = newValue }
    }
}
