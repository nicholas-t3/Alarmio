//
//  CreateAlarmView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI
import Functions

struct CreateAlarmView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceInfo) private var deviceInfo
    @Environment(\.composerService) private var composerService
    @Environment(\.alertManager) private var alertManager
    @Environment(\.alarmStore) private var alarmStore

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
    @State private var phase: Phase = .configuring
    @State private var sunriseProgress: Double = 0
    @State private var starSpinProgress: Double = 0
    @State private var generatingStatusText: String = ""
    @State private var confirmationHeroVisible: Bool = false
    @State private var confirmationCheckVisible: Bool = false
    @State private var confirmationHeroExited: Bool = false
    @State private var confirmationCardVisible: Bool = false
    @State private var statusTextVisible: Bool = false
    @State private var isRegenerating: Bool = false

    // MARK: - Constants

    let onCreate: (AlarmConfiguration) -> Void

    // MARK: - Init

    init(
        initialStep: Int = 1,
        initialPhase: Phase = .configuring,
        previewStatusText: String = "",
        onCreate: @escaping (AlarmConfiguration) -> Void
    ) {
        self._step = State(initialValue: initialStep)
        self._phase = State(initialValue: initialPhase)
        self._generatingStatusText = State(initialValue: previewStatusText)
        self._sunriseProgress = State(initialValue: initialPhase == .configuring ? 0 : 1)
        self._starSpinProgress = State(initialValue: initialPhase == .configuring ? 0 : 1)
        self.onCreate = onCreate
    }

    // MARK: - Body

    var body: some View {
        ZStack {

            // Background — shared across all phases. Sunrise + star spin
            // ramp up when we enter the generating phase and stay lit
            // through the confirmation phase.
            MorningSky(
                starOpacity: 0.6,
                showConstellations: false, sunriseProgress: sunriseProgress,
                starSpinProgress: starSpinProgress
            )

            VStack(spacing: 0) {

                // Header
                header

                // Phase content
                switch phase {
                case .configuring:
                    if step == 1 {
                        stepOne
                    } else {
                        stepTwo
                    }

                case .generating:
                    generatingPhase

                case .confirming:
                    confirmationPhase
                }

                Spacer(minLength: 0)

                // Bottom button
                bottomBar
            }

            // Alert overlay — must live inside this ZStack because
            // CreateAlarmView is presented as a .fullScreenCover, which
            // creates a separate presentation context. The GlobalAlertOverlay
            // in RootView is behind the cover and invisible from here.
            GlobalAlertOverlay()

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

            // Back / Close — hidden during generating and confirming
            if phase == .configuring {
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
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Title — swaps per phase
            Text(headerTitle)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: phase)

            Spacer()

            // Invisible spacer to balance
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal - 8)
    }

    private var headerTitle: String {
        switch phase {
        case .configuring: return "New Alarm"
        case .generating: return ""
        case .confirming: return "New Alarm"
        }
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

            // Interval stepper — premium blur in/out
            snoozeIntervalRow
                .premiumBlur(isVisible: alarm.maxSnoozes > 0 || alarm.unlimitedSnooze, duration: 0.3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    private var snoozeCountRow: some View {
        HStack(spacing: 16) {
            Button {
                HapticManager.shared.selection()
                // Unlimited → back to 3, otherwise decrement.
                if alarm.unlimitedSnooze {
                    alarm.unlimitedSnooze = false
                    alarm.maxSnoozes = 3
                } else {
                    alarm.maxSnoozes = max(0, alarm.maxSnoozes - 1)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }

            HStack(spacing: 6) {
                if alarm.unlimitedSnooze {
                    Text("Unlimited")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                } else if alarm.maxSnoozes == 0 {
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
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: alarm.unlimitedSnooze)

            Button {
                HapticManager.shared.selection()
                // Past 3 → unlimited. maxSnoozes stays at 3 (unused in
                // unlimited mode but harmless for Codable back-compat).
                if alarm.unlimitedSnooze {
                    // Already unlimited, no-op.
                } else if alarm.maxSnoozes >= 3 {
                    alarm.unlimitedSnooze = true
                } else {
                    alarm.maxSnoozes = min(3, alarm.maxSnoozes + 1)
                }
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

                // Customize (tone + reason + intensity + leave time)
                factorsCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0.1, duration: 0.4)

                Spacer()
                    .frame(height: 20)
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .mask(scrollFadeMask)
    }

    /// Shared grid spec for the inline tone / reason pickers inside the
    /// Customize card. Two equal columns with an 8pt gutter.
    private static let pillGridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    // MARK: - Customize Card

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

            Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 4)

            // Leave time
            leaveTimeRow

            inlineExpandable(isOpen: alarm.leaveTime != nil) {
                leaveTimeInlinePicker
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Leave Time Row

    private var leaveTimeRow: some View {
        let isOn = alarm.leaveTime != nil

        return HStack(spacing: 12) {
            Image(systemName: isOn ? "arrow.up.right.circle.fill" : Self.unsetIcon)
                .font(.system(size: isOn ? 14 : 7))
                .foregroundStyle(.white.opacity(isOn ? 0.9 : 0.3))
                .frame(width: 20)
                .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))

            Text("Time to Leave")
                .font(AppTypography.labelLarge)
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(
                get: { alarm.leaveTime != nil },
                set: { newValue in
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        if newValue {
                            alarm.leaveTime = defaultLeaveTime()
                            // Close any expanded factor — leave time has its
                            // own "always open when on" behavior and
                            // shouldn't conflict with the mutually exclusive
                            // expandedFactor state.
                            expandedFactor = nil
                        } else {
                            alarm.leaveTime = nil
                        }
                    }
                }
            ))
            .labelsHidden()
            .tint(Color(hex: "0a1628"))
        }
        .padding(.vertical, 14)
    }

    private var leaveTimeInlinePicker: some View {
        VStack(spacing: 16) {

            // Descriptor
            Text("Your alarm will use this to let you know how much time you have before you need to leave.")
                .font(AppTypography.labelSmall)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            // Time stepper (5-min increments)
            HStack(spacing: 16) {
                Button {
                    HapticManager.shared.selection()
                    adjustLeaveTime(minutes: -5)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }

                HStack(spacing: 6) {
                    Text(leaveTimeClockString)
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    if let period = leaveTimePeriodString {
                        Text(period)
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(.white.opacity(0.7))
                            .contentTransition(.numericText())
                    }
                }
                .frame(width: 110)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: alarm.leaveTime)

                Button {
                    HapticManager.shared.selection()
                    adjustLeaveTime(minutes: 5)
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
    }

    /// The numeric portion of the leave-time clock string (e.g. "8:00" or
    /// "20:00" on 24-hour locales).
    private var leaveTimeClockString: String {
        let date = alarm.leaveTime ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("jm")
        let full = formatter.string(from: date)

        // Strip the AM/PM marker if present so it can render separately at
        // a smaller size. On 24-hour locales the symbols are empty and this
        // returns the unchanged string.
        let am = formatter.amSymbol ?? ""
        let pm = formatter.pmSymbol ?? ""
        return full
            .replacingOccurrences(of: am, with: "")
            .replacingOccurrences(of: pm, with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// The AM/PM marker shown next to the numeric clock string at a
    /// smaller weight. Nil on 24-hour locales (no period marker).
    private var leaveTimePeriodString: String? {
        let date = alarm.leaveTime ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("jm")
        let full = formatter.string(from: date)

        let am = formatter.amSymbol ?? ""
        let pm = formatter.pmSymbol ?? ""

        if !am.isEmpty, full.contains(am) { return am }
        if !pm.isEmpty, full.contains(pm) { return pm }
        return nil
    }

    /// Default leave time when the toggle is first flipped on: wake time
    /// + 1 hour, rounded to the nearest 5 minutes.
    private func defaultLeaveTime() -> Date {
        let base = alarm.wakeTime ?? Date()
        let oneHourLater = base.addingTimeInterval(60 * 60)
        return roundToFiveMinutes(oneHourLater)
    }

    private func roundToFiveMinutes(_ date: Date) -> Date {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        let rounded = Int((Double(minute) / 5.0).rounded()) * 5
        let delta = rounded - minute
        return calendar.date(byAdding: .minute, value: delta, to: date) ?? date
    }

    private func adjustLeaveTime(minutes: Int) {
        guard let current = alarm.leaveTime else { return }
        guard let wake = alarm.wakeTime else {
            alarm.leaveTime = current.addingTimeInterval(TimeInterval(minutes * 60))
            return
        }

        let proposed = current.addingTimeInterval(TimeInterval(minutes * 60))

        // Clamp: can't leave before waking up, can't be more than 12 hours
        // after wake time.
        let minAllowed = wake
        let maxAllowed = wake.addingTimeInterval(60 * 60 * 12)

        alarm.leaveTime = min(max(proposed, minAllowed), maxAllowed)
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

    // MARK: - Generating Phase

    private var generatingPhase: some View {
        VStack {

            Spacer()

            Text(generatingStatusText)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 0)
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 0)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .premiumBlur(isVisible: statusTextVisible, duration: 0.4, disableScale: true, disableOffset: true)

            Spacer()
        }
    }

    // MARK: - Confirmation Phase

    @ViewBuilder
    private var confirmationPhase: some View {
        ZStack {

            // Substate 1: Hero
            if !confirmationHeroExited {
                confirmationHero
            }

            // Substate 2: Empty placeholder card
            if confirmationHeroExited {
                confirmationCard
            }
        }
        .task {
            await runConfirmationSequence()
        }
    }

    private var confirmationHero: some View {
        VStack(spacing: 20) {

            Spacer()

            // Checkmark + title — tight stack matching onboarding
            VStack(spacing: 0) {

                ZStack {
                    Circle()
                        .fill(Color(hex: "4AFF8E").opacity(0.08))
                        .frame(width: 80, height: 80)
                        .blur(radius: 16)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(hex: "4AFF8E"))
                        .opacity(confirmationCheckVisible ? 1 : 0)
                        .scaleEffect(confirmationCheckVisible ? 1 : 0.5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: confirmationCheckVisible)
                }

                Text("Your alarm is ready")
                    .font(AppTypography.headlineLarge)
                    .tracking(AppTypography.headlineLargeTracking)
                    .foregroundStyle(.white)
            }
            .premiumBlur(isVisible: confirmationHeroVisible, duration: 0.5)

            Spacer()
        }
    }

    private var confirmationCard: some View {
        VStack {

            Spacer()

            // Audio preview card
            VStack(spacing: 16) {

                // Label
                Text("PREVIEW")
                    .font(AppTypography.caption)
                    .tracking(AppTypography.captionTracking)
                    .foregroundStyle(.white.opacity(0.4))

                // Waveform visualizer
                VoiceWaveform(bands: voicePlayer.bands, isPlaying: voicePlayer.isPlaying)
                    .frame(height: 48)
                    .padding(.horizontal, 8)

                // Play + Regenerate buttons
                HStack(spacing: 12) {

                    // Play / Stop
                    Button {
                        HapticManager.shared.buttonTap()
                        toggleAlarmPreview()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: voicePlayer.isPlaying ? "stop.fill" : "play.fill")
                                .font(.system(size: 14))
                                .contentTransition(.symbolEffect(.replace))

                            Text(voicePlayer.isPlaying ? "Stop" : "Preview")
                                .font(AppTypography.labelMedium)
                        }
                        .foregroundStyle(.white)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .disabled(isRegenerating)

                    // Regenerate
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
                                    .font(.system(size: 14))
                            }

                            Text(isRegenerating ? "Generating" : "Regenerate")
                                .font(AppTypography.labelMedium)
                        }
                        .foregroundStyle(.white.opacity(isRegenerating ? 0.5 : 1))
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .disabled(isRegenerating)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .premiumBlur(isVisible: confirmationCardVisible, duration: 0.5)

            Spacer()
        }
    }

    private func toggleAlarmPreview() {
        if voicePlayer.isPlaying {
            voicePlayer.stop()
        } else {
            guard let fileName = alarm.soundFileName else { return }
            let url = alarmStore.audioFileManager.soundFileURL(named: fileName)
            voicePlayer.playFromFile(url: url, persona: alarm.voicePersona)
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
                let initialFileName = try await composerService.generateAndDownloadAudio(for: alarm)
                alarm.soundFileName = initialFileName
                isRegenerating = false
                HapticManager.shared.success()
            } catch {
                isRegenerating = false
                print("[CreateAlarmView] Regenerate failed: \(error)")
                alertManager.showModal(
                    title: "Regeneration failed",
                    message: "Please try again.",
                    primaryAction: AlertAction(label: "OK") {}
                )
            }
        }
    }

    private func runConfirmationSequence() async {
        // 1. Hero blurs in
        try? await Task.sleep(for: .milliseconds(100))
        confirmationHeroVisible = true

        // 2. Checkmark pops
        try? await Task.sleep(for: .milliseconds(250))
        confirmationCheckVisible = true
        HapticManager.shared.success()

        // 3. Hold the hero on screen
        try? await Task.sleep(for: .seconds(1.5))

        // 4. Blur the hero out + fade the sky back to calm
        confirmationHeroVisible = false
        withAnimation(.easeOut(duration: 1.0)) {
            sunriseProgress = 0
            starSpinProgress = 0
        }

        // 5. Once the hero blur-out finishes, swap to the card substate
        try? await Task.sleep(for: .milliseconds(500))
        confirmationHeroExited = true

        // 6. Card blurs in, button follows shortly after
        try? await Task.sleep(for: .milliseconds(100))
        confirmationCardVisible = true

        try? await Task.sleep(for: .milliseconds(500))
        buttonVisible = true
    }

    // MARK: - Phase Transition

    private func transitionToPhase(_ newPhase: Phase) {
        guard !isTransitioning else { return }
        isTransitioning = true
        cardsVisible = false
        buttonVisible = false

        Task {
            // Wait for blur-out
            try? await Task.sleep(for: .milliseconds(400))

            // Swap phase while content is hidden
            phase = newPhase

            // Small delay so new views enter the hierarchy with cardsVisible = false
            try? await Task.sleep(for: .milliseconds(50))

            // Stagger in new content
            cardsVisible = true

            // Button visibility is phase-specific:
            // - configuring: comes in 500ms after content
            // - generating: never (no button)
            // - confirming: managed by runConfirmationSequence (held until
            //   after the hero exits)
            if newPhase == .configuring {
                try? await Task.sleep(for: .milliseconds(500))
                buttonVisible = true
            }
            isTransitioning = false
        }
    }

    private func startGeneration() {
        transitionToPhase(.generating)

        Task { @MainActor in
            // Wait for the configuring phase to finish blurring out and the
            // generating phase to mount before kicking off animations and
            // status messages. transitionToPhase uses 400ms blur + 50ms
            // re-mount delay, so 450ms aligns the generation start with the
            // generating view first becoming visible.
            try? await Task.sleep(for: .milliseconds(450))

            // Kick off background animations. Sunrise ramps over a longer
            // window than the old stub because the real Composer call is
            // variable-length; star spin ramps to full in 2s as before.
            animateSunrise(duration: 8.0)
            animateStarSpin()

            // Cycle personalized status messages with premium blur transitions.
            // Each message blurs out, swaps, then blurs back in.
            let messages = buildStatusMessages()
            let statusTask = Task { @MainActor in
                var i = 0
                while !Task.isCancelled {
                    generatingStatusText = messages[i % messages.count]
                    statusTextVisible = true
                    // Hold visible
                    try? await Task.sleep(for: .seconds(2.0))
                    guard !Task.isCancelled else { break }
                    // Blur out
                    statusTextVisible = false
                    try? await Task.sleep(for: .milliseconds(400))
                    i += 1
                }
            }

            // Real Composer call.
            do {
                guard let composerService else {
                    throw NSError(
                        domain: "ComposerService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Composer service unavailable"]
                    )
                }
                let initialFileName = try await composerService.generateAndDownloadAudio(for: alarm)
                statusTask.cancel()
                statusTextVisible = false
                alarm.soundFileName = initialFileName
                try? await Task.sleep(for: .milliseconds(300))
                generatingStatusText = "Almost ready..."
                statusTextVisible = true
                try? await Task.sleep(for: .milliseconds(600))
                transitionToPhase(.confirming)
            } catch {
                statusTask.cancel()
                statusTextVisible = false
                // Log the full error including response body for 401/4xx debugging.
                if case FunctionsError.httpError(let code, let data) = error {
                    let body = String(data: data, encoding: .utf8) ?? "non-utf8"
                    print("[CreateAlarmView] Composer failed: HTTP \(code) — \(body)")
                } else {
                    print("[CreateAlarmView] Composer failed: \(error)")
                }
                generatingStatusText = ""

                // Present the modal over the generating screen. When the
                // user taps "Continue", fade the sky back and transition
                // to the configuring phase. Doing both in the action
                // closure avoids the sky reset racing with transitionToPhase.
                alertManager.showModal(
                    title: "Something went wrong",
                    message: "We'll investigate this issue. Please try again later.",
                    primaryAction: AlertAction(label: "Continue") { [self] in
                        withAnimation(.easeOut(duration: 0.6)) {
                            sunriseProgress = 0
                            starSpinProgress = 0
                        }
                        transitionToPhase(.configuring)
                    }
                )
            }
        }
    }

    private func animateStarSpin() {
        Task { @MainActor in
            let steps = 30
            let duration = 2.0
            let interval = duration / Double(steps)
            for i in 1...steps {
                try? await Task.sleep(for: .seconds(interval))
                let p = Double(i) / Double(steps)
                // Ease-out
                starSpinProgress = 1.0 - (1.0 - p) * (1.0 - p)
            }
        }
    }

    private func animateSunrise(duration: Double) {
        Task { @MainActor in
            let steps = 60
            let interval = duration / Double(steps)
            for i in 1...steps {
                try? await Task.sleep(for: .seconds(interval))
                let progress = Double(i) / Double(steps)
                // Smooth ease-in-out
                sunriseProgress = progress * progress * (3.0 - 2.0 * progress)
            }
        }
    }

    private func buildStatusMessages() -> [String] {
        var messages: [String] = []

        if let tone = alarm.tone {
            messages.append(toneStatusMessage(tone))
        }
        if let why = alarm.whyContext {
            messages.append(whyStatusMessage(why))
        }
        if let intensity = alarm.intensity {
            messages.append(intensityStatusMessage(intensity))
        }
        if let voice = alarm.voicePersona {
            messages.append(voiceStatusMessage(voice))
        }
        messages.append("Writing your wake-up call")

        // Always make sure we have at least a few messages so the phase
        // doesn't feel empty if the user skipped optional fields.
        if messages.count < 3 {
            messages.append("Almost ready")
        }

        return messages
    }

    private func toneStatusMessage(_ tone: AlarmTone) -> String {
        switch tone {
        case .calm: return "Setting a calm tone"
        case .encourage: return "Adding some encouragement"
        case .push: return "Turning up the push"
        case .strict: return "Making it strict"
        case .fun: return "Making it fun"
        case .other: return "Adding your personal touch"
        }
    }

    private func whyStatusMessage(_ why: WhyContext) -> String {
        switch why {
        case .work: return "Getting you ready for work"
        case .school: return "Prepping for the school day"
        case .gym: return "Fueling your morning workout"
        case .family: return "Making time for family"
        case .personalGoal: return "Aligning with your goals"
        case .important: return "Locking in on what matters"
        case .other: return "Personalizing your morning"
        }
    }

    private func intensityStatusMessage(_ intensity: AlarmIntensity) -> String {
        switch intensity {
        case .gentle: return "Keeping it gentle"
        case .balanced: return "Finding the right balance"
        case .intense: return "Cranking up the intensity"
        }
    }

    private func voiceStatusMessage(_ voice: VoicePersona) -> String {
        switch voice {
        case .calmGuide: return "Calling the calm guide"
        case .energeticCoach: return "Warming up the coach"
        case .hardSergeant: return "Calling the drill sergeant"
        case .evilSpaceLord: return "Summoning the space lord"
        case .playful: return "Bringing the fun"
        case .bro: return "Grabbing the bro"
        case .digitalAssistant: return "Booting the assistant"
        }
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        switch phase {
        case .configuring:
            configuringBottomBar
        case .generating:
            // No button while generating — keep the layout slot empty
            Color.clear.frame(height: 0)
        case .confirming:
            confirmingBottomBar
        }
    }

    private var configuringBottomBar: some View {
        Button {
            HapticManager.shared.buttonTap()
            if step == 1 {
                transitionToStep(2)
            } else {
                startGeneration()
            }
        } label: {
            Text(step == 1 ? "Next" : "Create Alarm")
        }
        .primaryButton()
        .padding(.horizontal, AppButtons.horizontalPadding)
        .padding(.bottom, AppSpacing.screenBottom)
        .premiumBlur(isVisible: buttonVisible, delay: 0, duration: 0.4)
    }

    private var confirmingBottomBar: some View {
        Button {
            HapticManager.shared.buttonTap()
            voicePlayer.stop()
            alarm.isEnabled = true
            onCreate(alarm)
            dismiss()
        } label: {
            Text("Schedule Alarm")
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
    }

    // MARK: - Phase

    enum Phase: Equatable {
        case configuring
        case generating
        case confirming
    }

    // MARK: - Hero Voice Data

    private struct HeroVoice {
        let persona: VoicePersona
        let name: String
        let descriptor: String
    }

    /// The 8 hero voices shown in the voice card. Seven are real personas
    /// backed by distinct ElevenLabs voices; one ("Morning Sun") remains a
    /// placeholder reusing `calmGuide` until an eighth voice is chosen.
    private var heroVoices: [HeroVoice] {
        [
            HeroVoice(persona: .calmGuide,        name: "Calm Guide",    descriptor: "Soothing · Gentle"),
            HeroVoice(persona: .energeticCoach,   name: "Coach",         descriptor: "Upbeat · Motivating"),
            HeroVoice(persona: .hardSergeant,     name: "Sergeant",      descriptor: "Firm · Direct"),
            HeroVoice(persona: .evilSpaceLord,    name: "Space Lord",    descriptor: "Dramatic · Commanding"),
            HeroVoice(persona: .playful,          name: "Playful",       descriptor: "Bright · Lighthearted"),
            HeroVoice(persona: .bro,              name: "The Bro",       descriptor: "Casual · Vibes"),
            HeroVoice(persona: .digitalAssistant, name: "Digital",       descriptor: "Robotic · Helpful"),
            // Placeholder — reuses calmGuide until an eighth voice is chosen.
            HeroVoice(persona: .calmGuide,        name: "Morning Sun",   descriptor: "Warm · Optimistic"),
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

#Preview("Generating") {
    CreateAlarmView(
        initialStep: 2,
        initialPhase: .generating,
        previewStatusText: "Calling the calm guide",
        onCreate: { _ in }
    )
}

#Preview("Confirming") {
    CreateAlarmView(
        initialStep: 2,
        initialPhase: .confirming,
        onCreate: { _ in }
    )
}
