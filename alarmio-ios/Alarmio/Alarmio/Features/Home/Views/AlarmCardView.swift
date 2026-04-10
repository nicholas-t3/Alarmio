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
    let onToggle: () -> Void
    let onEdit: () -> Void

    // MARK: - Body

    var body: some View {
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

                // Toggle — visual only, tap fires callback
                Toggle("", isOn: .constant(alarm.isEnabled))
                    .labelsHidden()
                    .tint(Color(hex: "0a1628"))
                    .allowsHitTesting(false)
                    .overlay {
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { onToggle() }
                    }
            }

            // Detail row — schedule + persona left, edit button right
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {

                    // Schedule
                    Text(scheduleSummary)
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(.white.opacity(alarm.isEnabled ? 0.85 : 0.35))

                    // Tone + persona
                    if let tone = alarm.tone, let persona = alarm.voicePersona {
                        HStack(spacing: 6) {
                            Image(systemName: toneIcon(tone))
                                .font(.system(size: 11))

                            Text(personaLabel(persona))
                                .font(AppTypography.caption)
                                .tracking(0.3)
                        }
                        .foregroundStyle(.white.opacity(alarm.isEnabled ? 0.5 : 0.2))
                    }
                }

                Spacer()

                // Edit
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .padding(.trailing, -6)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
        .opacity(alarm.isEnabled ? 1.0 : 0.7)
        .animation(.easeOut(duration: 0.3), value: alarm.isEnabled)
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

    private func toneIcon(_ tone: AlarmTone) -> String {
        switch tone {
        case .calm: return "leaf.fill"
        case .encourage: return "hand.thumbsup.fill"
        case .push: return "flame.fill"
        case .strict: return "bolt.fill"
        case .fun: return "face.smiling.fill"
        case .other: return "sparkles"
        }
    }

    private func personaLabel(_ persona: VoicePersona) -> String {
        switch persona {
        case .calmGuide: return "Calm Guide"
        case .energeticCoach: return "Energetic Coach"
        case .hardSergeant: return "Hard Sergeant"
        case .evilSpaceLord: return "Evil Space Lord"
        case .playful: return "Playful"
        case .bro: return "The Bro"
        case .digitalAssistant: return "Digital"
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
                wakeTime: Calendar.current.date(from: DateComponents(hour: 6, minute: 30)),
                repeatDays: [1, 2, 3, 4, 5],
                tone: .calm,
                voicePersona: .calmGuide
            ),
            onToggle: {},
            onEdit: {}
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("Disabled") {
    ZStack {
        MorningSky(starOpacity: 0.35)

        AlarmCardView(
            alarm: AlarmConfiguration(
                isEnabled: false,
                wakeTime: Calendar.current.date(from: DateComponents(hour: 9, minute: 0)),
                repeatDays: [0, 6],
                tone: .fun,
                voicePersona: .playful
            ),
            onToggle: {},
            onEdit: {}
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}
