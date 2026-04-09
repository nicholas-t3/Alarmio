//
//  AlarmioMetadata.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/9/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import AlarmKit

/// Metadata type parameterizing AlarmAttributes<AlarmioMetadata>.
/// Must be identical across the main app and the widget extension, which
/// is why it lives in its own file with dual target membership.
nonisolated struct AlarmioMetadata: AlarmMetadata {}
