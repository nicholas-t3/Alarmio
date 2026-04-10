//
//  NewEditAlarmView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/10/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

// No custom detents — fixed at .fraction(0.75)

struct NewEditAlarmView: View {

    // MARK: - Environment

    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - Constants

    let alarm: AlarmConfiguration
    let onSave: (AlarmConfiguration) -> Void
    var onDelete: (() -> Void)?

    // MARK: - State

    @State private var editDays: Set<Int> = []
    @State private var editTime: Date = Date()
    @State private var editSnoozeInterval: Int = 5
    @State private var editMaxSnoozes: Int = 3
    @State private var editVoicePersona: VoicePersona?
    @State private var navPath: [DetailPage] = []

    private var isOnSummary: Bool { navPath.isEmpty }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // Navigation content
            NavigationStack(path: $navPath) {
                summaryContent
                    .navigationDestination(for: DetailPage.self) { page in
                        detailContent(for: page)
                            .background(Color.clear)
                    }
            }

            // Bottom actions — always in the layout, opacity-driven
            bottomActions
                .opacity(isOnSummary ? 1 : 0)
                .frame(height: isOnSummary ? nil : 0)
                .clipped()
                .animation(.easeInOut(duration: 0.25), value: isOnSummary)
        }
        .presentationDetents([.fraction(0.75)])
        .presentationDragIndicator(.visible)
        .presentationBackground {
            ZStack {
                Color(hex: "060e1c")
                LinearGradient(
                    colors: [
                        Color(hex: "060e1c"),
                        Color(hex: "111d35").opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
        .onAppear {
            editTime = alarm.wakeTime ?? Date()
            editDays = Set(alarm.repeatDays ?? [])
            editSnoozeInterval = alarm.snoozeInterval
            editMaxSnoozes = alarm.maxSnoozes
            editVoicePersona = alarm.voicePersona
        }
    }

    // MARK: - Summary

    private var summaryContent: some View {
        VStack(spacing: 12) {

            // Schedule row
            summaryRow(
                icon: "clock.fill",
                label: "Schedule",
                value: timeString,
                detail: scheduleSummary
            ) {
                navPath.append(.schedule)
            }

            // Snooze row
            summaryRow(
                icon: "zzz",
                label: "Snooze",
                value: snoozeSummary,
                detail: snoozeDetail
            ) {
                navPath.append(.snooze)
            }

            // Voice row
            summaryRow(
                icon: "waveform",
                label: "Voice",
                value: voiceLabel(editVoicePersona),
                detail: voiceDescriptor(editVoicePersona)
            ) {
                navPath.append(.voice)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 8)
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.clear)
    }

    // MARK: - Summary Row

    private func summaryRow(
        icon: String,
        label: String,
        value: String,
        detail: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            HapticManager.shared.softTap()
            action()
        }) {
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
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Pages

    @ViewBuilder
    private func detailContent(for page: DetailPage) -> some View {
        switch page {
        case .schedule:
            scheduleDetailPage
        case .snooze:
            snoozeDetailPage
        case .voice:
            voiceDetailPage
        }
    }

    private var scheduleDetailPage: some View {
        VStack(spacing: 0) {

            // Time picker
            VStack(spacing: 0) {
                Text("WAKE TIME")
                    .font(AppTypography.caption)
                    .tracking(AppTypography.captionTracking)
                    .foregroundStyle(.white.opacity(0.4))

                DatePicker("", selection: $editTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
            }

            // Day picker
            VStack(spacing: 10) {
                Text("REPEAT")
                    .font(AppTypography.caption)
                    .tracking(AppTypography.captionTracking)
                    .foregroundStyle(.white.opacity(0.4))

                DayPicker(selectedDays: $editDays)

                Text(scheduleSummary)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .detailNavBar(title: "Schedule") {
            navPath.removeAll()
        }
    }

    private var snoozeDetailPage: some View {
        VStack(spacing: 0) {

            Spacer()
                .frame(height: 16)

            VStack(spacing: 14) {

                // Section label
                Text("SNOOZE")
                    .font(AppTypography.caption)
                    .tracking(AppTypography.captionTracking)
                    .foregroundStyle(.white.opacity(0.4))

                // Count stepper
                snoozeCountRow

                // Interval stepper
                snoozeIntervalRow
                    .premiumBlur(isVisible: editMaxSnoozes > 0, duration: 0.3)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .detailNavBar(title: "Snooze") {
            navPath.removeAll()
        }
    }

    private var voiceDetailPage: some View {
        ScrollView {
            VStack(spacing: 10) {

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

                            Text(voiceDescriptor(persona))
                                .font(AppTypography.caption)
                                .foregroundStyle(isSelected ? .black.opacity(0.5) : .white.opacity(0.35))

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
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .detailNavBar(title: "Voice") {
            navPath.removeAll()
        }
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
            .frame(width: Self.snoozeStepperLabelWidth)
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
            .frame(width: Self.snoozeStepperLabelWidth)
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

    private static let snoozeStepperLabelWidth: CGFloat = 110

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 16) {

            // Save
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
            .padding(.horizontal, AppButtons.horizontalPadding)

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
                .padding(.bottom, 4)
            }
        }
        .padding(.bottom, AppSpacing.screenBottom)
    }

    // MARK: - Helpers

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
        return "\(total) min total snooze time"
    }

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

// MARK: - Navigation Page

extension NewEditAlarmView {
    enum DetailPage: String, Hashable {
        case schedule
        case snooze
        case voice
    }
}

// MARK: - Detail Nav Bar

private struct DetailNavBar: ViewModifier {

    let title: String
    let onBack: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticManager.shared.softTap()
                        onBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

private extension View {
    func detailNavBar(title: String, onBack: @escaping () -> Void) -> some View {
        modifier(DetailNavBar(title: title, onBack: onBack))
    }
}

// MARK: - Previews

#Preview("New Edit - Summary") {
    struct PreviewContainer: View {
        @State private var showEdit = true

        var body: some View {
            ZStack {
                MorningSky(starOpacity: 0.8, showConstellations: false)
            }
            .sheet(isPresented: $showEdit) {
                NewEditAlarmView(
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
                    onSave: { _ in showEdit = false },
                    onDelete: { showEdit = false }
                )
            }
        }
    }

    return PreviewContainer()
}

#Preview("New Edit - Content Only") {
    ZStack {
        Color(hex: "060e1c").ignoresSafeArea()
        NewEditAlarmView(
            alarm: AlarmConfiguration(
                isEnabled: true,
                wakeTime: Calendar.current.date(from: DateComponents(hour: 6, minute: 30)),
                repeatDays: [1, 2, 3, 4, 5],
                tone: .calm,
                intensity: .gentle,
                voicePersona: .energeticCoach,
                snoozeInterval: 5,
                maxSnoozes: 3
            ),
            onSave: { _ in },
            onDelete: {}
        )
    }
}
