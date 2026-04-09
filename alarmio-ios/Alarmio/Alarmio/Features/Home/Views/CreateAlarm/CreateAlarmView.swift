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
        intensity: .gentle
    )
    @State private var step: Int
    @State private var cardsVisible = false
    @State private var buttonVisible = false
    @State private var isTransitioning = false
    @State private var selectedDays: Set<Int> = []
    @State private var voiceIndex: Int = 0
    @State private var voicePlayer = VoicePreviewPlayer()
    @State private var waveformPulse: Bool = false
    @State private var expandedFactor: FactorKind?

    // MARK: - Constants

    let onCreate: (AlarmConfiguration) -> Void

    // MARK: - Init

    init(initialStep: Int = 1, onCreate: @escaping (AlarmConfiguration) -> Void) {
        self._step = State(initialValue: initialStep)
        self.onCreate = onCreate
    }

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

            // Section label
            Text("SNOOZE")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Snooze count stepper — always visible
            snoozeCountRow

            // Interval stepper — only when count > 0
            if alarm.maxSnoozes > 0 {
                snoozeIntervalRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: alarm.maxSnoozes)
    }

    private var snoozeCountRow: some View {
        HStack(spacing: 16) {
            Button {
                HapticManager.shared.selection()
                alarm.maxSnoozes = max(0, alarm.maxSnoozes - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }

            HStack(spacing: 6) {
                if alarm.maxSnoozes == 0 {
                    Text("No snooze")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.numericText())
                } else {
                    Text("\(alarm.maxSnoozes)")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(alarm.maxSnoozes == 1 ? "snooze" : "snoozes")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.numericText())
                }
            }
            .frame(width: Self.snoozeStepperLabelWidth)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: alarm.maxSnoozes)

            Button {
                HapticManager.shared.selection()
                alarm.maxSnoozes = min(3, alarm.maxSnoozes + 1)
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
                alarm.snoozeInterval = max(1, alarm.snoozeInterval - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }

            HStack(spacing: 6) {
                Text("\(alarm.snoozeInterval)")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(alarm.snoozeInterval == 1 ? "minute" : "minutes")
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.7))
                    .contentTransition(.numericText())
            }
            .frame(width: Self.snoozeStepperLabelWidth)
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

    /// Fixed width for the center label of both snooze stepper rows, so the
    /// plus/minus buttons align vertically across rows regardless of which
    /// text ("No snooze" vs "15 minutes") is currently showing.
    private static let snoozeStepperLabelWidth: CGFloat = 110

    // MARK: - Step 2: Style

    private var stepTwo: some View {
        ScrollView {
            VStack(spacing: AppSpacing.itemGap(deviceInfo.spacingScale)) {

                // Voice (hero)
                voiceHeroCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0, duration: 0.4)

                // Factors (tone + reason + intensity in one card)
                factorsCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0.1, duration: 0.4)

                // Tone (old pill grid — replaced by factorsCard above)
                // toneCard
                //     .padding(.horizontal, AppSpacing.screenHorizontal)
                //     .premiumBlur(isVisible: cardsVisible, delay: 0, duration: 0.4)

                // Why (old pill grid — replaced by factorsCard above)
                // whyCard
                //     .padding(.horizontal, AppSpacing.screenHorizontal)
                //     .premiumBlur(isVisible: cardsVisible, delay: 0.1, duration: 0.4)

                // Intensity (old card — replaced by factorsCard above)
                // intensityCard
                //     .padding(.horizontal, AppSpacing.screenHorizontal)
                //     .premiumBlur(isVisible: cardsVisible, delay: 0.2, duration: 0.4)

                // Voice (old pill grid — replaced by voiceHeroCard above)
                // voiceCard
                //     .padding(.horizontal, AppSpacing.screenHorizontal)
                //     .premiumBlur(isVisible: cardsVisible, delay: 0.3, duration: 0.4)

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

            // Two-column grid of equal-width pills
            LazyVGrid(columns: Self.pillGridColumns, spacing: 8) {
                ForEach(toneOptions, id: \.tone) { option in
                    tonePill(for: option)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    private func tonePill(for option: ToneOption) -> some View {
        let isSelected = alarm.tone == option.tone
        return Button {
            HapticManager.shared.selection()
            alarm.tone = option.tone
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

    /// Shared grid spec for the tone / reason / voice pill cards. Two equal
    /// columns with an 8pt gutter — makes pills rigidly aligned regardless
    /// of label length.
    private static let pillGridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REASON")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .center)

            // Two-column grid of equal-width pills
            LazyVGrid(columns: Self.pillGridColumns, spacing: 8) {
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

            // Two-column grid of equal-width pills
            LazyVGrid(columns: Self.pillGridColumns, spacing: 8) {
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Factors Card

    private var factorsCard: some View {
        VStack(spacing: 0) {

            // Caption
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
                icon: alarm.intensity == nil ? Self.unsetIcon : intensityIcon(alarm.intensity),
                label: "Intensity",
                value: alarm.intensity == nil ? "Tap to select" : intensityLabel(alarm.intensity),
                hasSelection: alarm.intensity != nil,
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
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    /// Empty-state icon for unset factor rows. A small filled dot reads as
    /// neutral/placeholder, unlike a questionmark which implies the row
    /// is tappable for help.
    private static let unsetIcon: String = "circle.fill"

    private func toggleFactor(_ kind: FactorKind) {
        HapticManager.shared.selection()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            expandedFactor = (expandedFactor == kind) ? nil : kind
        }
    }

    /// Wraps an inline picker so it animates in place via premiumBlur rather
    /// than sliding from outside the card. Always kept in the view tree so
    /// both directions animate; layout height collapses when closed.
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

    private var toneInlinePicker: some View {
        LazyVGrid(columns: Self.pillGridColumns, spacing: 8) {
            ForEach(toneOptions, id: \.tone) { option in
                let isSelected = alarm.tone == option.tone
                Button {
                    HapticManager.shared.selection()
                    alarm.tone = option.tone
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
                let isSelected = alarm.whyContext == option.why
                Button {
                    HapticManager.shared.selection()
                    alarm.whyContext = option.why
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
                let isSelected = alarm.intensity == option.intensity
                Button {
                    HapticManager.shared.selection()
                    alarm.intensity = option.intensity
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

    private var selectedToneOption: ToneOption? {
        toneOptions.first(where: { $0.tone == alarm.tone })
    }

    private var selectedWhyOption: WhyOption? {
        whyOptions.first(where: { $0.why == alarm.whyContext })
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

    // MARK: - Voice Hero Card

    private var voiceHeroCard: some View {
        let voice = heroVoices[voiceIndex]
        let isPlayingThis = voicePlayer.isPlaying && voicePlayer.currentPersona == voice.persona

        return VStack(spacing: 14) {

            // Section label
            Text("VOICE")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Waveform — subtle visual anchor, driven by VoicePreviewPlayer.
            // Brief scale+opacity pulse on voice change gives a "new voice"
            // cue even when audio isn't playing.
            VoiceWaveform(bands: voicePlayer.bands, isPlaying: isPlayingThis)
                .frame(height: 28)
                .scaleEffect(waveformPulse ? 1.08 : 1.0)
                .opacity(waveformPulse ? 0.4 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: waveformPulse)

            // Voice name — numeric-text crossfade on cycle
            Text(voice.name)
                .font(AppTypography.labelLarge)
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: voiceIndex)

            // Control row: prev chevron | Play + Preview pill | next chevron
            HStack(spacing: 6) {
                Button {
                    HapticManager.shared.selection()
                    cycleVoice(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }

                Button {
                    HapticManager.shared.buttonTap()
                    togglePreview()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isPlayingThis ? "stop.fill" : "play.fill")
                            .font(.system(size: 14))
                            .contentTransition(.symbolEffect(.replace))

                        Text(isPlayingThis ? "Stop" : "Preview")
                            .font(AppTypography.labelMedium)
                            .contentTransition(.numericText())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 36)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPlayingThis)

                Button {
                    HapticManager.shared.selection()
                    cycleVoice(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
        .onDisappear { voicePlayer.stop() }
    }

    // MARK: - Voice Hero Actions

    private func cycleVoice(by delta: Int) {
        let newIndex = (voiceIndex + delta + heroVoices.count) % heroVoices.count
        voiceIndex = newIndex
        alarm.voicePersona = heroVoices[newIndex].persona

        // Pulse the waveform briefly so the change is visible even when
        // audio isn't playing.
        waveformPulse = true
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            waveformPulse = false
        }

        // If a preview is in flight, hand it off to the new voice so the
        // user keeps momentum while browsing.
        if voicePlayer.isPlaying {
            voicePlayer.play(persona: heroVoices[newIndex].persona)
        }
    }

    private func togglePreview() {
        let voice = heroVoices[voiceIndex]
        if voicePlayer.isPlaying && voicePlayer.currentPersona == voice.persona {
            voicePlayer.stop()
        } else {
            voicePlayer.play(persona: voice.persona)
        }
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

    // MARK: - Factor Kind

    private enum FactorKind: Identifiable {
        case tone
        case reason
        case intensity

        var id: Self { self }

        var caption: String {
            switch self {
            case .tone: return "TONE"
            case .reason: return "REASON"
            case .intensity: return "INTENSITY"
            }
        }
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

    // MARK: - Hero Voice Data

    private struct HeroVoice {
        let persona: VoicePersona
        let name: String
        let descriptor: String
    }

    /// The 8 hero voices shown in the voice card. Until we add new cases
    /// to the `VoicePersona` enum, several entries reuse existing personas
    /// as placeholders — swap these out when the new MP3s are in and the
    /// enum is expanded.
    private var heroVoices: [HeroVoice] {
        [
            HeroVoice(persona: .calmGuide,     name: "Calm Guide",    descriptor: "Soothing · Gentle"),
            HeroVoice(persona: .energeticCoach, name: "Coach",        descriptor: "Upbeat · Motivating"),
            HeroVoice(persona: .hardSergeant,  name: "Sergeant",      descriptor: "Firm · Direct"),
            HeroVoice(persona: .evilSpaceLord, name: "Space Lord",    descriptor: "Dramatic · Commanding"),
            HeroVoice(persona: .playful,       name: "Playful",       descriptor: "Bright · Lighthearted"),
            // Placeholders — reuse existing personas until enum expands.
            HeroVoice(persona: .calmGuide,     name: "Morning Sun",   descriptor: "Warm · Optimistic"),
            HeroVoice(persona: .energeticCoach, name: "Mentor",       descriptor: "Steady · Wise"),
            HeroVoice(persona: .playful,       name: "Zen",           descriptor: "Grounded · Peaceful"),
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

// MARK: - Voice Waveform

/// A centered, symmetric bar visualizer driven by `VoicePreviewPlayer.bands`.
/// Resting state: a flat low-amplitude silhouette. Playing state: bars reflect
/// live audio amplitude from the 24-band metering array.
private struct VoiceWaveform: View {

    // MARK: - Constants

    let bands: [CGFloat]
    let isPlaying: Bool

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 4
    private let minBarHeight: CGFloat = 3
    /// Resting silhouette: soft sine curve so the card isn't visually empty
    /// when audio is stopped. Deterministic so the shape doesn't change
    /// across renders.
    private let restingHeights: [CGFloat] = (0..<24).map { i in
        let t = CGFloat(i) / 23.0
        // Gentle centered hump, 0.2–0.5 normalized amplitude
        let hump = sin(t * .pi)
        return 0.2 + hump * 0.3
    }

    // MARK: - Body

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

#Preview("Step 1") {
    CreateAlarmView(onCreate: { _ in })
}

#Preview("Step 2") {
    CreateAlarmView(initialStep: 2, onCreate: { _ in })
}
