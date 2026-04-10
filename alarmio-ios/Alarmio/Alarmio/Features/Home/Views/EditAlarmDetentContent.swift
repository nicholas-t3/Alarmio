//
//  EditAlarmDetentContent.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/10/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct EditAlarmDetentContent: View {

    // MARK: - Constants

    let alarm: AlarmConfiguration
    let onSave: (AlarmConfiguration) -> Void
    var onDelete: (() -> Void)?

    // MARK: - Bindings

    @Binding var currentStep: DetentStep

    // MARK: - State

    @State private var editTime: Date = Date()
    @State private var editDays: Set<Int> = []
    @State private var editSnoozeInterval: Int = 5
    @State private var editMaxSnoozes: Int = 3
    @State private var editVoicePersona: VoicePersona?
    @State private var visiblePage = 0
    @State private var targetPage = 0
    @State private var contentRevealed = true

    // MARK: - Constants

    private let summaryStep = DetentStep(480, id: "edit-summary")
    private let scheduleStep = DetentStep(560, id: "edit-schedule")
    private let snoozeStep = DetentStep(360, id: "edit-snooze")
    private let voiceStep = DetentStep(500, id: "edit-voice")

    // MARK: - Computed Properties

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: editTime)
    }

    private var scheduleSummary: String {
        if editDays.isEmpty {
            return "One-time alarm"
        } else if editDays == Set([1, 2, 3, 4, 5]) {
            return "Weekdays"
        } else if editDays == Set([0, 6]) {
            return "Weekends"
        } else if editDays.count == 7 {
            return "Every day"
        } else {
            return "\(editDays.count) days per week"
        }
    }

    private var snoozeSummary: String {
        if editMaxSnoozes == 0 {
            return "Off"
        } else {
            return "\(editMaxSnoozes) × \(editSnoozeInterval) min"
        }
    }

    private var snoozeDetail: String? {
        if editMaxSnoozes == 0 { return nil }
        let total = editMaxSnoozes * editSnoozeInterval
        return "\(total) min total"
    }

    private func stepForPage(_ page: Int) -> DetentStep {
        switch page {
        case 0: return summaryStep
        case 1: return scheduleStep
        case 2: return snoozeStep
        case 3: return voiceStep
        default: return summaryStep
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            switch visiblePage {
            case 1:
                schedulePage
            case 2:
                snoozePage
            case 3:
                voicePage
            default:
                summaryPage
            }
        }
        .premiumBlur(
            isVisible: contentRevealed,
            duration: 0.2,
            disableScale: true,
            disableOffset: true
        )
        .onAppear {
            editTime = alarm.wakeTime ?? Date()
            editDays = Set(alarm.repeatDays ?? [])
            editSnoozeInterval = alarm.snoozeInterval
            editMaxSnoozes = alarm.maxSnoozes
            editVoicePersona = alarm.voicePersona
        }
        .onChange(of: targetPage) { _, newPage in
            contentRevealed = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                visiblePage = newPage
                currentStep = stepForPage(newPage)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                contentRevealed = true
            }
        }
    }

    // MARK: - Summary Page

    private var summaryPage: some View {
        VStack(spacing: 12) {

            // Schedule row
            summaryRow(
                icon: "clock.fill",
                label: "Schedule",
                value: timeString,
                detail: scheduleSummary
            )
            .contentShape(Rectangle())
            .onTapGesture { targetPage = 1 }

            // Snooze row
            summaryRow(
                icon: "zzz",
                label: "Snooze",
                value: snoozeSummary,
                detail: snoozeDetail
            )
            .contentShape(Rectangle())
            .onTapGesture { targetPage = 2 }

            // Voice row
            summaryRow(
                icon: "waveform",
                label: "Voice",
                value: voiceLabel(editVoicePersona),
                detail: voiceDescriptor(editVoicePersona)
            )
            .contentShape(Rectangle())
            .onTapGesture { targetPage = 3 }

            // Save button
            Button {
                HapticManager.shared.success()
                var updated = alarm
                updated.wakeTime = editTime
                updated.repeatDays = editDays.isEmpty ? nil : Array(editDays).sorted()
                updated.snoozeInterval = editSnoozeInterval
                updated.maxSnoozes = editMaxSnoozes
                updated.voicePersona = editVoicePersona
                onSave(updated)
            } label: {
                Text("Save")
            }
            .primaryButton()
            .padding(.top, 8)

            // Delete
            if onDelete != nil {
                Button {
                    HapticManager.shared.warning()
                    onDelete?()
                } label: {
                    Text("Delete")
                        .font(AppTypography.button)
                        .tracking(AppTypography.buttonTracking)
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 16)
        .padding(.bottom, 50)
    }

    // MARK: - Schedule Page

    private var schedulePage: some View {
        VStack(spacing: 16) {

            // Back row
            backButton

            // Time picker
            VStack(spacing: 4) {
                Text("WAKE TIME")
                    .font(AppTypography.caption)
                    .tracking(AppTypography.captionTracking)
                    .foregroundStyle(.white.opacity(0.4))

                DatePicker("", selection: $editTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))

            // Day picker
            VStack(spacing: 14) {
                Text("REPEAT")
                    .font(AppTypography.caption)
                    .tracking(AppTypography.captionTracking)
                    .foregroundStyle(.white.opacity(0.4))

                DayPicker(selectedDays: $editDays)

                Text(scheduleSummary)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 12)
        .padding(.bottom, 50)
    }

    // MARK: - Snooze Page

    private var snoozePage: some View {
        VStack(spacing: 16) {

            // Back row
            backButton

            // Snooze controls
            VStack(spacing: 14) {
                Text("SNOOZE")
                    .font(AppTypography.caption)
                    .tracking(AppTypography.captionTracking)
                    .foregroundStyle(.white.opacity(0.4))

                snoozeCountRow

                snoozeIntervalRow
                    .premiumBlur(isVisible: editMaxSnoozes > 0, duration: 0.3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 12)
        .padding(.bottom, 50)
    }

    // MARK: - Voice Page

    private var voicePage: some View {
        VStack(spacing: 12) {

            // Back row
            backButton

            // Voice options
            ForEach(VoicePersona.allCases, id: \.self) { persona in
                let isSelected = editVoicePersona == persona

                Button {
                    HapticManager.shared.selection()
                    editVoicePersona = persona
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: voiceIcon(persona))
                            .font(.system(size: 14))
                            .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                            .frame(width: 20)

                        Text(voiceLabel(persona))
                            .font(AppTypography.labelLarge)
                            .foregroundStyle(isSelected ? .black : .white)

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.black.opacity(0.7))
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(isSelected ? .white : .white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .animation(.easeOut(duration: 0.2), value: isSelected)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 12)
        .padding(.bottom, 50)
    }

    // MARK: - Subviews

    private var backButton: some View {
        HStack {
            Button {
                targetPage = 0
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(AppTypography.labelMedium)
                }
                .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
    }

    private func summaryRow(
        icon: String,
        label: String,
        value: String,
        detail: String?
    ) -> some View {
        HStack(spacing: 14) {

            // Icon
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 24)

            // Labels
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.5))

                Text(value)
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white)

                if let detail {
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            Spacer(minLength: 0)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Snooze Steppers

    private var snoozeCountRow: some View {
        HStack(spacing: 16) {
            Button {
                HapticManager.shared.selection()
                editMaxSnoozes = max(0, editMaxSnoozes - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }

            HStack(spacing: 6) {
                if editMaxSnoozes == 0 {
                    Text("No snooze")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.numericText())
                } else {
                    Text("\(editMaxSnoozes)")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(editMaxSnoozes == 1 ? "snooze" : "snoozes")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 110)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editMaxSnoozes)

            Button {
                HapticManager.shared.selection()
                editMaxSnoozes = min(3, editMaxSnoozes + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    private var snoozeIntervalRow: some View {
        HStack(spacing: 16) {
            Button {
                HapticManager.shared.selection()
                editSnoozeInterval = max(1, editSnoozeInterval - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }

            HStack(spacing: 6) {
                Text("\(editSnoozeInterval)")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(editSnoozeInterval == 1 ? "minute" : "minutes")
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.7))
                    .contentTransition(.numericText())
            }
            .frame(width: 110)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editSnoozeInterval)

            Button {
                HapticManager.shared.selection()
                editSnoozeInterval = min(15, editSnoozeInterval + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Helpers

    private func voiceLabel(_ persona: VoicePersona?) -> String {
        guard let persona else { return "Not set" }
        switch persona {
        case .calmGuide: return "Calm Guide"
        case .energeticCoach: return "Coach"
        case .hardSergeant: return "Sergeant"
        case .evilSpaceLord: return "Space Lord"
        case .playful: return "Playful"
        case .bro: return "The Bro"
        case .digitalAssistant: return "Digital"
        }
    }

    private func voiceDescriptor(_ persona: VoicePersona?) -> String {
        guard let persona else { return "" }
        switch persona {
        case .calmGuide: return "Soothing · Gentle"
        case .energeticCoach: return "Upbeat · Motivating"
        case .hardSergeant: return "Firm · Direct"
        case .evilSpaceLord: return "Dramatic · Commanding"
        case .playful: return "Bright · Lighthearted"
        case .bro: return "Casual · Vibes"
        case .digitalAssistant: return "Robotic · Helpful"
        }
    }

    private func voiceIcon(_ persona: VoicePersona) -> String {
        switch persona {
        case .calmGuide: return "leaf.fill"
        case .energeticCoach: return "flame.fill"
        case .hardSergeant: return "bolt.fill"
        case .evilSpaceLord: return "sparkles"
        case .playful: return "face.smiling.fill"
        case .bro: return "hand.wave.fill"
        case .digitalAssistant: return "cpu"
        }
    }
}

// MARK: - Previews

#Preview("Edit Summary") {
    ZStack {
        NightSkyBackground()
    }
    .detentModal(
        isPresented: .constant(true),
        currentStep: .constant(DetentStep(360, id: "edit-summary"))
    ) {
        EditAlarmDetentContent(
            alarm: AlarmConfiguration(
                isEnabled: true,
                wakeTime: Calendar.current.date(from: DateComponents(hour: 7, minute: 0)),
                repeatDays: [1, 2, 3, 4, 5],
                tone: .calm,
                intensity: .gentle,
                voicePersona: .calmGuide,
                snoozeInterval: 5,
                maxSnoozes: 2
            ),
            onSave: { _ in }, onDelete: {}, currentStep: .constant(DetentStep(360, id: "edit-summary"))
        )
    }
}
