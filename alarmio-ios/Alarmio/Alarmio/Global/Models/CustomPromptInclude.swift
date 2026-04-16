//
//  CustomPromptInclude.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/16/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation
import SwiftUI

enum CustomPromptInclude: String, CaseIterable, Codable, Sendable, Identifiable {
    case alarmTime = "alarm_time"
    case leaveTime = "leave_time"
    case humor
    case affirmation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .alarmTime:   return "Time of Alarm"
        case .leaveTime:   return "Time to Leave"
        case .humor:       return "Humor"
        case .affirmation: return "Affirmation"
        }
    }

    var onIconName: String {
        switch self {
        case .alarmTime:   return "clock.fill"
        case .leaveTime:   return "arrow.up.right.circle.fill"
        case .humor:       return "face.smiling.fill"
        case .affirmation: return "sparkles"
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(CustomPromptInclude.allCases) { include in
            HStack {
                Image(systemName: include.onIconName)
                    .frame(width: 20)
                Text(include.label)
                    .foregroundStyle(.white)
                Spacer()
                Text(include.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
