//
//  CardMode.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/10/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

enum CardMode {
    case standard
    case edit
}

struct CardGlassModifier: ViewModifier {
    let mode: CardMode

    func body(content: Content) -> some View {
        switch mode {
        case .standard:
            content
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
        case .edit:
            content
                .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))
        }
    }
}
