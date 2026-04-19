//
//  AlarmioWidgetBundle.swift
//  AlarmioWidget
//
//  Created by Nicholas Towery on 4/15/26.
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI
import WidgetKit

@main
struct AlarmioWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlarmioWidgetLiveActivity()
    }
}
