//
//  CreateAlarmView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct CreateAlarmView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - State

    @State private var alarm = AlarmConfiguration(
        intensity: .gentle,
        difficulty: .easy
    )
    @State private var step = 1
    @State private var cardsVisible = false
    @State private var buttonVisible = false
    @State private var isTransitioning = false
    @State private var selectedDays: Set<Int> = []

    // MARK: - Constants

    let onCreate: (AlarmConfiguration) -> Void

    // MARK: - Body

    var body: some View {
        ZStack {

            // Background
            MorningSky(starOpacity: 0.6, showConstellations: false)

            VStack(spacing: 0) {

                // Header
                header

                // Step content
                if step == 1 {
                    stepOne
                } else {
                    stepTwo
                }

                Spacer(minLength: 0)

                // Bottom button
                bottomBar
            }
        }
        .task {
            alarm.wakeTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0))
            try? await Task.sleep(for: .milliseconds(100))
            cardsVisible = true
            try? await Task.sleep(for: .milliseconds(500))
            buttonVisible = true
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {

            // Back / Close
            Button {
                HapticManager.shared.buttonTap()
                if step == 2 {
                    transitionToStep(1)
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: step == 2 ? "chevron.left" : "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }

            Spacer()

            // Title
            Text("New Alarm")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            // Invisible spacer to balance
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal - 8)
    }

    // MARK: - Step 1: When + Snooze

    private var stepOne: some View {
        ScrollView {
            VStack(spacing: AppSpacing.itemGap(deviceInfo.spacingScale)) {

                // Time picker
                timeCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0, duration: 0.4)

                // Day selector
                scheduleCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0.1, duration: 0.4)

                // Snooze
                snoozeCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0.2, duration: 0.4)
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .mask(scrollFadeMask)
    }

    private var timeCard: some View {
        VStack(spacing: 4) {
            Text("WAKE TIME")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            DatePicker("", selection: Binding(
                get: { alarm.wakeTime ?? Date() },
                set: { alarm.wakeTime = $0 }
            ), displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .colorScheme(.dark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    private var scheduleCard: some View {
        VStack(spacing: 14) {
            Text("REPEAT")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            DayPicker(selectedDays: $selectedDays)
                .onChange(of: selectedDays) { _, newDays in
                    alarm.repeatDays = newDays.isEmpty ? nil : Array(newDays).sorted()
                }

            Text(scheduleSummary)
                .font(AppTypography.bodySmall)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    private var snoozeCard: some View {
        VStack(spacing: 14) {
            Text("SNOOZE")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Count
            HStack {
                Text("Times")
                    .font(AppTypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        HapticManager.shared.selection()
                        alarm.snoozeCount = max(0, alarm.snoozeCount - 1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.1))
                            .clipShape(Circle())
                    }

                    Text(alarm.snoozeCount == 0 ? "Off" : "\(alarm.snoozeCount)")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white)
                        .frame(width: 32)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: alarm.snoozeCount)

                    Button {
                        HapticManager.shared.selection()
                        alarm.snoozeCount = min(10, alarm.snoozeCount + 1)
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

            // Interval
            if alarm.snoozeCount > 0 {
                HStack {
                    Text("Minutes")
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            HapticManager.shared.selection()
                            alarm.snoozeInterval = max(1, alarm.snoozeInterval - 1)
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.white.opacity(0.1))
                                .clipShape(Circle())
                        }

                        Text("\(alarm.snoozeInterval)")
                            .font(AppTypography.labelLarge)
                            .foregroundStyle(.white)
                            .frame(width: 32)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: alarm.snoozeInterval)

                        Button {
                            HapticManager.shared.selection()
                            alarm.snoozeInterval = min(15, alarm.snoozeInterval + 1)
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
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeOut(duration: 0.25), value: alarm.snoozeCount)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Step 2: Style

    private var stepTwo: some View {
        ScrollView {
            VStack(spacing: AppSpacing.itemGap(deviceInfo.spacingScale)) {

                // Tone
                toneCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0, duration: 0.4)

                // Why
                whyCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0.1, duration: 0.4)

                // Intensity + Difficulty
                intensityCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0.2, duration: 0.4)

                // Voice
                voiceCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0.3, duration: 0.4)

                Spacer()
                    .frame(height: 20)
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .mask(scrollFadeMask)
    }

    private var toneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TONE")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .center)

            // Wrapping pills
            FlowLayout(spacing: 8) {
                ForEach(toneOptions, id: \.tone) { option in
                    let isSelected = alarm.tone == option.tone

                    Button {
                        HapticManager.shared.selection()
                        alarm.tone = option.tone
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: option.icon)
                                .font(.system(size: 12))
                            Text(option.label)
                                .font(AppTypography.labelSmall)
                        }
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(isSelected ? .white : .white.opacity(0.08))
                        .clipShape(Capsule())
                        .fixedSize()
                    }
                    .animation(.easeOut(duration: 0.2), value: isSelected)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REASON")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .center)

            // Wrapping pills
            FlowLayout(spacing: 8) {
                ForEach(whyOptions, id: \.why) { option in
                    let isSelected = alarm.whyContext == option.why

                    Button {
                        HapticManager.shared.selection()
                        alarm.whyContext = option.why
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: option.icon)
                                .font(.system(size: 11))
                            Text(option.label)
                                .font(AppTypography.labelSmall)
                        }
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isSelected ? .white : .white.opacity(0.08))
                        .clipShape(Capsule())
                        .fixedSize()
                    }
                    .animation(.easeOut(duration: 0.2), value: isSelected)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    private var intensityCard: some View {
        VStack(spacing: 16) {

            // Intensity
            VStack(spacing: 10) {
                Text("INTENSITY")
                    .font(AppTypography.caption)
                    .tracking(AppTypography.captionTracking)
                    .foregroundStyle(.white.opacity(0.4))

                HStack(spacing: 0) {
                    ForEach(intensityOptions, id: \.intensity) { option in
                        let isSelected = alarm.intensity == option.intensity

                        Button {
                            HapticManager.shared.selection()
                            alarm.intensity = option.intensity
                        } label: {
                            Text(option.label)
                                .font(AppTypography.labelSmall)
                                .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(isSelected ? .white : .clear)
                                .clipShape(Capsule())
                        }
                        .animation(.easeOut(duration: 0.2), value: isSelected)
                    }
                }
                .padding(3)
                .background(.white.opacity(0.08))
                .clipShape(Capsule())
            }

            // Difficulty
            VStack(spacing: 10) {
                Text("DIFFICULTY")
                    .font(AppTypography.caption)
                    .tracking(AppTypography.captionTracking)
                    .foregroundStyle(.white.opacity(0.4))

                HStack(spacing: 0) {
                    ForEach(difficultyOptions, id: \.difficulty) { option in
                        let isSelected = alarm.difficulty == option.difficulty

                        Button {
                            HapticManager.shared.selection()
                            alarm.difficulty = option.difficulty
                        } label: {
                            Text(option.label)
                                .font(AppTypography.labelSmall)
                                .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(isSelected ? .white : .clear)
                                .clipShape(Capsule())
                        }
                        .animation(.easeOut(duration: 0.2), value: isSelected)
                    }
                }
                .padding(3)
                .background(.white.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    private var voiceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VOICE")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .center)

            // Wrapping pills
            FlowLayout(spacing: 8) {
                ForEach(voiceOptions, id: \.persona) { option in
                    let isSelected = alarm.voicePersona == option.persona

                    Button {
                        HapticManager.shared.selection()
                        alarm.voicePersona = option.persona
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: option.icon)
                                .font(.system(size: 12))
                            Text(option.label)
                                .font(AppTypography.labelSmall)
                        }
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isSelected ? .white : .white.opacity(0.08))
                        .clipShape(Capsule())
                        .fixedSize()
                    }
                    .animation(.easeOut(duration: 0.2), value: isSelected)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        Button {
            HapticManager.shared.buttonTap()
            if step == 1 {
                transitionToStep(2)
            } else {
                alarm.isEnabled = true
                onCreate(alarm)
                dismiss()
            }
        } label: {
            Text(step == 1 ? "Next" : "Create Alarm")
        }
        .primaryButton()
        .padding(.horizontal, AppButtons.horizontalPadding)
        .padding(.bottom, AppSpacing.screenBottom)
        .premiumBlur(isVisible: buttonVisible, delay: 0, duration: 0.4)
    }

    private var scrollFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 16)

            Color.white

            LinearGradient(
                stops: [
                    .init(color: .white, location: 0),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 16)
        }
    }

    // MARK: - Private Methods

    private func transitionToStep(_ newStep: Int) {
        guard !isTransitioning else { return }
        isTransitioning = true
        cardsVisible = false
        buttonVisible = false

        Task {
            // Wait for blur-out
            try? await Task.sleep(for: .milliseconds(400))

            // Swap step while cards are hidden
            step = newStep

            // Small delay so new views enter the hierarchy with cardsVisible = false
            try? await Task.sleep(for: .milliseconds(50))

            // Stagger in new cards
            cardsVisible = true

            // Button comes in last
            try? await Task.sleep(for: .milliseconds(500))
            buttonVisible = true
            isTransitioning = false
        }
    }

    // MARK: - Data

    private struct ToneOption {
        let tone: AlarmTone
        let label: String
        let icon: String
    }

    private var toneOptions: [ToneOption] {
        [
            ToneOption(tone: .calm, label: "Calm", icon: "leaf.fill"),
            ToneOption(tone: .encourage, label: "Encourage", icon: "hand.thumbsup.fill"),
            ToneOption(tone: .push, label: "Push", icon: "bolt.fill"),
            ToneOption(tone: .strict, label: "Strict", icon: "exclamationmark.triangle.fill"),
            ToneOption(tone: .fun, label: "Fun", icon: "face.smiling.fill"),
        ]
    }

    private struct WhyOption {
        let why: WhyContext
        let label: String
        let icon: String
    }

    private var whyOptions: [WhyOption] {
        [
            WhyOption(why: .work, label: "Work", icon: "briefcase.fill"),
            WhyOption(why: .school, label: "School", icon: "book.fill"),
            WhyOption(why: .gym, label: "Gym", icon: "dumbbell.fill"),
            WhyOption(why: .family, label: "Family", icon: "house.fill"),
            WhyOption(why: .personalGoal, label: "Goal", icon: "star.fill"),
            WhyOption(why: .important, label: "Important", icon: "exclamationmark.circle.fill"),
            WhyOption(why: .other, label: "Other", icon: "ellipsis.circle.fill"),
        ]
    }

    private struct IntensityOption {
        let intensity: AlarmIntensity
        let label: String
    }

    private var intensityOptions: [IntensityOption] {
        [
            IntensityOption(intensity: .gentle, label: "Gentle"),
            IntensityOption(intensity: .balanced, label: "Balanced"),
            IntensityOption(intensity: .intense, label: "Intense"),
        ]
    }

    private struct DifficultyOption {
        let difficulty: AlarmDifficulty
        let label: String
    }

    private var difficultyOptions: [DifficultyOption] {
        [
            DifficultyOption(difficulty: .easy, label: "Easy"),
            DifficultyOption(difficulty: .sometimesHard, label: "Medium"),
            DifficultyOption(difficulty: .veryHard, label: "Hard"),
        ]
    }

    private struct VoiceOption {
        let persona: VoicePersona
        let label: String
        let icon: String
    }

    private var voiceOptions: [VoiceOption] {
        [
            VoiceOption(persona: .calmGuide, label: "Calm Guide", icon: "leaf.fill"),
            VoiceOption(persona: .energeticCoach, label: "Coach", icon: "figure.run"),
            VoiceOption(persona: .hardSergeant, label: "Sergeant", icon: "shield.fill"),
            VoiceOption(persona: .evilSpaceLord, label: "Space Lord", icon: "sparkles"),
            VoiceOption(persona: .playful, label: "Playful", icon: "face.smiling.fill"),
        ]
    }

    private var scheduleSummary: String {
        if selectedDays.isEmpty {
            return "One-time alarm"
        } else if selectedDays == Set([1, 2, 3, 4, 5]) {
            return "Weekdays"
        } else if selectedDays == Set([0, 6]) {
            return "Weekends"
        } else if selectedDays.count == 7 {
            return "Every day"
        } else {
            return "\(selectedDays.count) days per week"
        }
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = buildRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(CGFloat(0)) { total, row in
            total + row.height + (total > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = buildRows(proposal: proposal, subviews: subviews)
        var y: CGFloat = 0

        var subviewIndex = 0
        for row in rows {
            let rowOffset = (bounds.width - row.width) / 2
            var x = rowOffset

            for i in 0..<row.count {
                let size = subviews[subviewIndex].sizeThatFits(.unspecified)
                subviews[subviewIndex].place(
                    at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                    proposal: .unspecified
                )
                x += size.width + spacing
                subviewIndex += 1
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var count: Int
        var width: CGFloat
        var height: CGFloat
    }

    private func buildRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var currentRow = Row(count: 0, width: 0, height: 0)

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let neededWidth = currentRow.count > 0 ? currentRow.width + spacing + size.width : size.width

            if neededWidth > maxWidth && currentRow.count > 0 {
                rows.append(currentRow)
                currentRow = Row(count: 1, width: size.width, height: size.height)
            } else {
                currentRow.width = neededWidth
                currentRow.height = max(currentRow.height, size.height)
                currentRow.count += 1
            }
        }

        if currentRow.count > 0 {
            rows.append(currentRow)
        }

        return rows
    }
}

// MARK: - Previews

#Preview("Step 1") {
    CreateAlarmView(onCreate: { _ in })
}

#Preview("Step 2") {
    CreateAlarmView(onCreate: { _ in })
}
