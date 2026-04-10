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

    // MARK: - Environment

    @Environment(\.alarmStore) private var alarmStore
    @Environment(\.composerService) private var composerService
    @Environment(\.alertManager) private var alertManager

    // MARK: - State

    @State private var editTime: Date = Date()
    @State private var editDays: Set<Int> = []
    @State private var editSnoozeInterval: Int = 5
    @State private var editMaxSnoozes: Int = 3
    @State private var editVoicePersona: VoicePersona?
    @State private var editTone: AlarmTone?
    @State private var editIntensity: AlarmIntensity?
    @State private var editWhyContext: WhyContext?
    @State private var editLeaveTime: Date?
    @State private var visiblePage = 0
    @State private var targetPage = 0
    @State private var contentRevealed = true
    @State private var voicePlayer = VoicePreviewPlayer()
    @State private var expandedFactor: FactorKind?
    @State private var waveformPulse = false
    @State private var voiceIndex: Int = 0
    @State private var isRegenerating = false
    @State private var editSoundFileName: String?

    // MARK: - Steps

    private let summaryStep = DetentStep(480, id: "edit-summary")
    private let scheduleStep = DetentStep(560, id: "edit-schedule")
    private let snoozeStep = DetentStep(360, id: "edit-snooze")
    private let styleStep = DetentStep(650, id: "edit-style")

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
            let labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return Array(editDays).sorted().compactMap { $0 < labels.count ? labels[$0] : nil }.joined(separator: ", ")
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

    private var styleSummary: String {
        var parts: [String] = []
        if let tone = editTone { parts.append(toneLabel(tone)) }
        if let persona = editVoicePersona { parts.append(voiceLabel(persona)) }
        if parts.isEmpty { return "Not configured" }
        return parts.joined(separator: " · ")
    }

    private var hasChanges: Bool {
        let originalTime = alarm.wakeTime ?? Date()
        let originalDays = Set(alarm.repeatDays ?? [])

        let cal = Calendar.current
        let timeChanged = cal.component(.hour, from: editTime) != cal.component(.hour, from: originalTime)
            || cal.component(.minute, from: editTime) != cal.component(.minute, from: originalTime)

        return timeChanged
            || editDays != originalDays
            || editSnoozeInterval != alarm.snoozeInterval
            || editMaxSnoozes != alarm.maxSnoozes
            || editVoicePersona != alarm.voicePersona
            || editTone != alarm.tone
            || editIntensity != alarm.intensity
            || editWhyContext != alarm.whyContext
    }

    private var hasStyleChanges: Bool {
        editVoicePersona != alarm.voicePersona
            || editTone != alarm.tone
            || editIntensity != alarm.intensity
            || editWhyContext != alarm.whyContext
    }

    private func stepForPage(_ page: Int) -> DetentStep {
        switch page {
        case 0: return summaryStep
        case 1: return scheduleStep
        case 2: return snoozeStep
        case 3: return styleStep
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
                stylePage
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
            // Reset page state for clean re-presentation
            visiblePage = 0
            targetPage = 0
            contentRevealed = true
            expandedFactor = nil

            editTime = alarm.wakeTime ?? Date()
            editDays = Set(alarm.repeatDays ?? [])
            editSnoozeInterval = alarm.snoozeInterval
            editMaxSnoozes = alarm.maxSnoozes
            editVoicePersona = alarm.voicePersona
            editTone = alarm.tone
            editIntensity = alarm.intensity
            editWhyContext = alarm.whyContext
            editLeaveTime = alarm.leaveTime
            editSoundFileName = alarm.soundFileName

            if let persona = alarm.voicePersona,
               let idx = VoicePersona.allCases.firstIndex(of: persona) {
                voiceIndex = idx
            }
        }
        .onDisappear {
            voicePlayer.stop()
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
            .onTapGesture {
                HapticManager.shared.softTap()
                targetPage = 1
            }

            // Snooze row
            summaryRow(
                icon: "zzz",
                label: "Snooze",
                value: snoozeSummary,
                detail: snoozeDetail
            )
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.shared.softTap()
                targetPage = 2
            }

            // Voice & Style row
            summaryRow(
                icon: "waveform",
                label: "Voice & Style",
                value: voiceLabel(editVoicePersona),
                detail: styleSummary
            )
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.shared.softTap()
                targetPage = 3
            }

            // Save button
            Button {
                HapticManager.shared.success()
                var updated = alarm
                updated.wakeTime = editTime
                updated.repeatDays = editDays.isEmpty ? nil : Array(editDays).sorted()
                updated.snoozeInterval = editSnoozeInterval
                updated.maxSnoozes = editMaxSnoozes
                updated.voicePersona = editVoicePersona
                updated.tone = editTone
                updated.intensity = editIntensity
                updated.whyContext = editWhyContext
                updated.leaveTime = editLeaveTime
                updated.soundFileName = editSoundFileName
                onSave(updated)
            } label: {
                Text("Save")
            }
            .primaryButton(isEnabled: hasChanges)
            .disabled(!hasChanges)
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

    // MARK: - Style Page (Voice + Factors)

    private var stylePage: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Back row
                backButton

                // Alarm audio preview
                alarmPreviewCard

                // Compact voice selector
                compactVoiceCard

                // Customize card (tone, reason, intensity)
                factorsCard

                // Regenerate button — only visible when style fields changed
                if hasStyleChanges {
                    Button {
                        HapticManager.shared.buttonTap()
                        regenerateAlarm()
                    } label: {
                        HStack(spacing: 8) {
                            if isRegenerating {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .medium))
                            }

                            Text(isRegenerating ? "Generating..." : "Regenerate")
                                .font(AppTypography.labelMedium)
                        }
                        .foregroundStyle(.white.opacity(isRegenerating ? 0.5 : 1))
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .disabled(isRegenerating)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: hasStyleChanges)
                }

                Spacer(minLength: 0)
                    .frame(height: 20)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 50)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Alarm Preview Card

    private var alarmPreviewCard: some View {
        let isPlaying = voicePlayer.isPlaying && !isPlayingVoiceSample

        return VStack(spacing: 14) {

            Text("ALARM PREVIEW")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Waveform
            AlarmWaveform(bands: voicePlayer.bands, isPlaying: isPlaying)
                .frame(height: 40)
                .padding(.horizontal, 8)

            // Play button
            Button {
                HapticManager.shared.buttonTap()
                toggleAlarmAudioPreview()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 14))
                        .contentTransition(.symbolEffect(.replace))

                    Text(isPlaying ? "Stop" : "Play")
                        .font(AppTypography.labelMedium)
                        .contentTransition(.numericText())
                }
                .foregroundStyle(.white)
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .disabled(editSoundFileName == nil)
            .opacity(editSoundFileName == nil ? 0.4 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPlaying)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Compact Voice Card

    private var compactVoiceCard: some View {
        let voice = VoicePersona.allCases[voiceIndex]

        return HStack(spacing: 10) {

            // Prev
            Button {
                HapticManager.shared.selection()
                cycleVoice(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }

            // Voice info
            VStack(spacing: 2) {
                Text(voiceLabel(voice))
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(voiceDescriptor(voice))
                    .font(AppTypography.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: voiceIndex)

            // Next
            Button {
                HapticManager.shared.selection()
                cycleVoice(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Factors Card

    private var factorsCard: some View {
        VStack(spacing: 0) {

            Text("CUSTOMIZE")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 10)

            // Tone
            factorRow(
                icon: selectedToneOption?.icon ?? Self.unsetIcon,
                label: "Tone",
                value: selectedToneOption?.label ?? "Tap to select",
                hasSelection: selectedToneOption != nil,
                isExpanded: expandedFactor == .tone
            ) {
                toggleFactor(.tone)
            }

            inlineExpandable(isOpen: expandedFactor == .tone) {
                toneInlinePicker
            }

            Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 4)

            // Reason
            factorRow(
                icon: selectedWhyOption?.icon ?? Self.unsetIcon,
                label: "Reason",
                value: selectedWhyOption?.label ?? "Tap to select",
                hasSelection: selectedWhyOption != nil,
                isExpanded: expandedFactor == .reason
            ) {
                toggleFactor(.reason)
            }

            inlineExpandable(isOpen: expandedFactor == .reason) {
                reasonInlinePicker
            }

            Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 4)

            // Intensity
            factorRow(
                icon: editIntensity == nil ? Self.unsetIcon : intensityIcon(editIntensity),
                label: "Intensity",
                value: editIntensity == nil ? "Tap to select" : intensityLabel(editIntensity),
                hasSelection: editIntensity != nil,
                isExpanded: expandedFactor == .intensity
            ) {
                toggleFactor(.intensity)
            }

            inlineExpandable(isOpen: expandedFactor == .intensity) {
                intensityInlineSlider
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Factor Rows & Pickers

    private static let unsetIcon = "circle.fill"

    private static let pillGridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private func toggleFactor(_ kind: FactorKind) {
        HapticManager.shared.selection()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            expandedFactor = (expandedFactor == kind) ? nil : kind
        }
    }

    @ViewBuilder
    private func inlineExpandable<Content: View>(
        isOpen: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.top, 4)
            .padding(.bottom, 14)
            .premiumBlur(isVisible: isOpen, duration: 0.35)
            .frame(height: isOpen ? nil : 0, alignment: .top)
            .clipped()
            .allowsHitTesting(isOpen)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isOpen)
    }

    private func factorRow(
        icon: String,
        label: String,
        value: String,
        hasSelection: Bool,
        isExpanded: Bool? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let usesExpandChevron = isExpanded != nil
        let chevronName = usesExpandChevron ? "chevron.down" : "chevron.right"
        let rotation: Double = (isExpanded == true) ? 180 : 0

        return Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: hasSelection ? 14 : 7))
                    .foregroundStyle(.white.opacity(hasSelection ? 0.9 : 0.3))
                    .frame(width: 20)
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))

                Text(label)
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                Text(value)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(hasSelection ? 0.7 : 0.35))
                    .contentTransition(.numericText())

                Image(systemName: chevronName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
                    .rotationEffect(.degrees(rotation))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: rotation)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: value)
    }

    private var toneInlinePicker: some View {
        LazyVGrid(columns: Self.pillGridColumns, spacing: 8) {
            ForEach(toneOptions, id: \.tone) { option in
                let isSelected = editTone == option.tone
                Button {
                    HapticManager.shared.selection()
                    editTone = option.tone
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        expandedFactor = nil
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option.icon)
                            .font(.system(size: 12))
                        Text(option.label)
                            .font(AppTypography.labelSmall)
                    }
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSelected ? .white : .white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .animation(.easeOut(duration: 0.2), value: isSelected)
            }
        }
    }

    private var reasonInlinePicker: some View {
        LazyVGrid(columns: Self.pillGridColumns, spacing: 8) {
            ForEach(whyOptions, id: \.why) { option in
                let isSelected = editWhyContext == option.why
                Button {
                    HapticManager.shared.selection()
                    editWhyContext = option.why
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        expandedFactor = nil
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: option.icon)
                            .font(.system(size: 11))
                        Text(option.label)
                            .font(AppTypography.labelSmall)
                    }
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSelected ? .white : .white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .animation(.easeOut(duration: 0.2), value: isSelected)
            }
        }
    }

    private var intensityInlineSlider: some View {
        HStack(spacing: 0) {
            ForEach(intensityOptions, id: \.intensity) { option in
                let isSelected = editIntensity == option.intensity
                Button {
                    HapticManager.shared.selection()
                    editIntensity = option.intensity
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        expandedFactor = nil
                    }
                } label: {
                    Text(option.label)
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.9))
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

    // MARK: - Subviews

    private var backButton: some View {
        HStack {
            Button {
                voicePlayer.stop()
                expandedFactor = nil
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

    // MARK: - Voice Actions

    /// True when the player is playing a bundled voice sample (not the alarm audio).
    private var isPlayingVoiceSample: Bool {
        guard voicePlayer.isPlaying else { return false }
        // If there's no sound file, any playback is a voice sample.
        // If there is one, check if the current persona matches — voice samples
        // are played via persona, alarm audio is played from file.
        if alarm.soundFileName == nil { return true }
        return voicePlayer.currentPersona != nil
            && voicePlayer.currentPersona == VoicePersona.allCases[voiceIndex]
    }

    private func cycleVoice(by delta: Int) {
        let allVoices = VoicePersona.allCases
        let newIndex = (voiceIndex + delta + allVoices.count) % allVoices.count
        voiceIndex = newIndex
        editVoicePersona = allVoices[newIndex]
    }

    private func toggleAlarmAudioPreview() {
        if voicePlayer.isPlaying {
            voicePlayer.stop()
        } else if let fileName = editSoundFileName {
            let url = alarmStore.audioFileManager.soundFileURL(named: fileName)
            voicePlayer.playFromFile(url: url, persona: editVoicePersona)
        }
    }

    private func regenerateAlarm() {
        voicePlayer.stop()
        isRegenerating = true

        Task { @MainActor in
            do {
                guard let composerService else {
                    throw NSError(
                        domain: "ComposerService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Composer service unavailable"]
                    )
                }

                // Build a config with the current edit state for generation
                var config = alarm
                config.voicePersona = editVoicePersona
                config.tone = editTone
                config.intensity = editIntensity
                config.whyContext = editWhyContext

                let newFileName = try await composerService.generateAndDownloadAudio(for: config)
                editSoundFileName = newFileName
                isRegenerating = false
                HapticManager.shared.success()
            } catch {
                isRegenerating = false
                print("[EditAlarmDetentContent] Regenerate failed: \(error)")
                alertManager.showModal(
                    title: "Regeneration failed",
                    message: "Please try again.",
                    primaryAction: AlertAction(label: "OK") {}
                )
            }
        }
    }

    // MARK: - Data

    private enum FactorKind: Identifiable {
        case tone
        case reason
        case intensity

        var id: Self { self }
    }

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

    private var selectedToneOption: ToneOption? {
        toneOptions.first(where: { $0.tone == editTone })
    }

    private var selectedWhyOption: WhyOption? {
        whyOptions.first(where: { $0.why == editWhyContext })
    }

    // MARK: - Helpers

    private func toneLabel(_ tone: AlarmTone) -> String {
        switch tone {
        case .calm: return "Calm"
        case .encourage: return "Encourage"
        case .push: return "Push"
        case .strict: return "Strict"
        case .fun: return "Fun"
        case .other: return "Other"
        }
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

    private func intensityLabel(_ intensity: AlarmIntensity?) -> String {
        switch intensity {
        case .gentle: return "Gentle"
        case .balanced: return "Balanced"
        case .intense: return "Intense"
        case .none: return "None"
        }
    }

    private func intensityIcon(_ intensity: AlarmIntensity?) -> String {
        switch intensity {
        case .gentle: return "leaf"
        case .balanced: return "circle.grid.2x2"
        case .intense: return "bolt.fill"
        case .none: return "questionmark.circle"
        }
    }
}

// MARK: - Alarm Waveform

private struct AlarmWaveform: View {

    let bands: [CGFloat]
    let isPlaying: Bool

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 4
    private let minBarHeight: CGFloat = 3
    private let restingHeights: [CGFloat] = (0..<24).map { i in
        let t = CGFloat(i) / 23.0
        let hump = sin(t * .pi)
        return 0.2 + hump * 0.3
    }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<bands.count, id: \.self) { i in
                    let amplitude = isPlaying ? max(bands[i], 0.05) : restingHeights[i]
                    let height = max(minBarHeight, amplitude * geo.size.height)

                    Capsule()
                        .fill(.white.opacity(isPlaying ? 0.9 : 0.35))
                        .frame(width: barWidth, height: height)
                        .animation(.easeOut(duration: 0.08), value: amplitude)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .animation(.easeInOut(duration: 0.3), value: isPlaying)
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
        currentStep: .constant(DetentStep(480, id: "edit-summary"))
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
            onSave: { _ in }, onDelete: {}, currentStep: .constant(DetentStep(480, id: "edit-summary"))
        )
    }
}
