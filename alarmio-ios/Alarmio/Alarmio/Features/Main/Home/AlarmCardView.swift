//
//  AlarmCardView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct AlarmCardView: View {

    // MARK: - Constants

    let alarm: AlarmConfiguration
    /// True when the shared home-screen player is currently playing this
    /// alarm's generated audio. Drives the Play ↔ Stop symbol swap.
    let isPlayingThis: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onTogglePlay: () -> Void

    // MARK: - Body

    var body: some View {
        // Whole card is a Button → edit sheet. The Play + Toggle buttons
        // below sit on top and claim their own tap regions; SwiftUI's
        // hit testing picks the innermost Button for the hit location,
        // so they never fall through to the outer edit tap.
        Button {
            HapticManager.shared.softTap()
            onEdit()
        } label: {
            VStack(alignment: .leading, spacing: 6) {

                // Time row — time left, toggle right
                HStack(alignment: .center) {
                    if let time = alarm.wakeTime {
                        Text(time, format: .dateTime.hour().minute())
                            .font(.system(size: 42, weight: .light, design: .rounded))
                            .foregroundStyle(.white.opacity(alarm.isEnabled ? 1 : 0.3))
                            .minimumScaleFactor(0.7)
                    }

                    Spacer()

                    // Toggle — visual only, tap fires callback. A clear
                    // overlay eats the tap so it doesn't propagate up to
                    // the card-level edit tap.
                    Toggle("", isOn: .constant(alarm.isEnabled))
                        .labelsHidden()
                        .allowsHitTesting(false)
                        .overlay {
                            Button(action: onToggle) {
                                Color.clear.contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                }

                // Detail row — schedule + persona left, play/stop button right
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {

                        // Name (optional, primary info line)
                        if let name = alarm.name, !name.isEmpty {
                            Text(name)
                                .font(AppTypography.labelSmall)
                                .foregroundStyle(.white.opacity(alarm.isEnabled ? 0.95 : 0.4))
                                .lineLimit(1)
                        }

                        // Schedule
                        Text(scheduleSummary)
                            .font(AppTypography.labelSmall)
                            .foregroundStyle(.white.opacity(alarm.isEnabled ? 0.85 : 0.35))

                        // Tone icon (or crown for pro) + persona name
                        if let persona = alarm.voicePersona {
                            HStack(spacing: 6) {
                                if alarm.alarmType == .pro {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color(hex: "E9C46A"))
                                } else if let tone = alarm.tone {
                                    Image(systemName: tone.icon)
                                        .font(.system(size: 11))
                                }

                                Text(persona.displayName)
                                    .font(AppTypography.caption)
                                    .tracking(0.3)
                            }
                            .foregroundStyle(.white.opacity(alarm.isEnabled ? 0.5 : 0.2))
                        }
                    }

                    Spacer()

                    // Play / Stop — previews the alarm's generated audio.
                    // Inner Button claims the tap for its own frame; taps
                    // outside it fall through to the outer card button.
                    Button {
                        HapticManager.shared.buttonTap()
                        onTogglePlay()
                    } label: {
                        Image(systemName: isPlayingThis ? "stop.fill" : "play.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(alarm.soundFileName == nil)
                    .opacity(alarm.soundFileName == nil ? 0.35 : 1)
                    .padding(.trailing, -6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPlayingThis)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
            .opacity(alarm.isEnabled ? 1.0 : 0.7)
            .animation(.easeOut(duration: 0.3), value: alarm.isEnabled)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Private Methods

    private var scheduleSummary: String {
        guard let days = alarm.repeatDays, !days.isEmpty else {
            return "One-time"
        }

        let weekdays = Set([1, 2, 3, 4, 5])
        let weekends = Set([0, 6])
        let daySet = Set(days)

        if daySet == weekdays {
            return "Weekdays"
        } else if daySet == weekends {
            return "Weekends"
        } else if daySet.count == 7 {
            return "Every day"
        } else {
            let labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return days.sorted().compactMap { $0 < labels.count ? labels[$0] : nil }.joined(separator: ", ")
        }
    }

}

// MARK: - Previews

#Preview("Enabled") {
    ZStack {
        MorningSky(starOpacity: 0.35)

        AlarmCardView(
            alarm: AlarmConfiguration(
                isEnabled: true,
                name: "Weekday Focus",
                wakeTime: Calendar.current.date(from: DateComponents(hour: 6, minute: 30)),
                repeatDays: [1, 2, 3, 4, 5],
                tone: .calm,
                voicePersona: .soothingSarah
            ),
            isPlayingThis: false,
            onToggle: {},
            onEdit: {},
            onTogglePlay: {}
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

//#Preview("Disabled") {
//    ZStack {
//        MorningSky(starOpacity: 0.35)
//
//        AlarmCardView(
//            alarm: AlarmConfiguration(
//                isEnabled: false,
//                wakeTime: Calendar.current.date(from: DateComponents(hour: 9, minute: 0)),
//                repeatDays: [0, 6],
//                tone: .fun,
//                voicePersona: .playful
//            ),
//            onToggle: {},
//            onEdit: {}
//        )
//        .padding(.horizontal, AppSpacing.screenHorizontal)
//    }
//}
