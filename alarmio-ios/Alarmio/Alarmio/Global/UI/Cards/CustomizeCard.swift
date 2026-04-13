//
//  CustomizeCard.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/10/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct CustomizeCard: View {

    // MARK: - Bindings

    @Binding var tone: AlarmTone?
    @Binding var whyContext: WhyContext?
    @Binding var intensity: AlarmIntensity?
    @Binding var leaveTime: Date?

    // MARK: - Constants

    let wakeTime: Date?
    let showLeaveTime: Bool
    let mode: CardMode

    // MARK: - State

    @State private var expandedFactor: FactorKind?

    // MARK: - Init

    init(
        tone: Binding<AlarmTone?>,
        whyContext: Binding<WhyContext?>,
        intensity: Binding<AlarmIntensity?>,
        leaveTime: Binding<Date?> = .constant(nil),
        wakeTime: Date? = nil,
        showLeaveTime: Bool = false,
        mode: CardMode = .standard
    ) {
        self._tone = tone
        self._whyContext = whyContext
        self._intensity = intensity
        self._leaveTime = leaveTime
        self.wakeTime = wakeTime
        self.showLeaveTime = showLeaveTime
        self.mode = mode
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // Header
            Text("CUSTOMIZE")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 10)

            // Tone
            factorRow(
                icon: tone?.icon ?? Self.unsetIcon,
                label: "Tone",
                value: tone?.displayName ?? "Tap to select",
                hasSelection: tone != nil,
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
                icon: whyContext?.icon ?? Self.unsetIcon,
                label: "Reason",
                value: whyContext?.displayName ?? "Tap to select",
                hasSelection: whyContext != nil,
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
                icon: intensity?.icon ?? Self.unsetIcon,
                label: "Intensity",
                value: intensity?.displayName ?? "Tap to select",
                hasSelection: intensity != nil,
                isExpanded: expandedFactor == .intensity
            ) {
                toggleFactor(.intensity)
            }

            inlineExpandable(isOpen: expandedFactor == .intensity) {
                intensityInlineSlider
            }

            // Leave time (optional)
            if showLeaveTime {
                Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 4)

                leaveTimeRow

                inlineExpandable(isOpen: leaveTime != nil) {
                    leaveTimeInlinePicker
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: mode))
    }

    // MARK: - Factor Logic

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

    // MARK: - Factor Row

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

    // MARK: - Inline Pickers

    private var toneInlinePicker: some View {
        LazyVGrid(columns: Self.pillGridColumns, spacing: 8) {
            ForEach(Self.toneCases, id: \.self) { option in
                let isSelected = tone == option
                Button {
                    HapticManager.shared.selection()
                    tone = option
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        expandedFactor = nil
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option.icon)
                            .font(.system(size: 12))
                        Text(option.displayName)
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
            ForEach(WhyContext.allCases, id: \.self) { option in
                let isSelected = whyContext == option
                Button {
                    HapticManager.shared.selection()
                    whyContext = option
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        expandedFactor = nil
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: option.icon)
                            .font(.system(size: 11))
                        Text(option.displayName)
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
            ForEach(AlarmIntensity.allCases, id: \.self) { option in
                let isSelected = intensity == option
                Button {
                    HapticManager.shared.selection()
                    intensity = option
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        expandedFactor = nil
                    }
                } label: {
                    Text(option.displayName)
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

    // MARK: - Leave Time

    private var leaveTimeRow: some View {
        let isOn = leaveTime != nil

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
                get: { leaveTime != nil },
                set: { newValue in
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        if newValue {
                            leaveTime = defaultLeaveTime()
                            expandedFactor = nil
                        } else {
                            leaveTime = nil
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

            Text("Your alarm will use this to let you know how much time you have before you need to leave.")
                .font(AppTypography.labelSmall)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

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
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: leaveTime)

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

    // MARK: - Leave Time Helpers

    private var leaveTimeClockString: String {
        let date = leaveTime ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("jm")
        let full = formatter.string(from: date)
        let am = formatter.amSymbol ?? ""
        let pm = formatter.pmSymbol ?? ""
        return full
            .replacingOccurrences(of: am, with: "")
            .replacingOccurrences(of: pm, with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private var leaveTimePeriodString: String? {
        let date = leaveTime ?? Date()
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

    private func defaultLeaveTime() -> Date {
        let base = wakeTime ?? Date()
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
        guard let current = leaveTime else { return }
        guard let wake = wakeTime else {
            leaveTime = current.addingTimeInterval(TimeInterval(minutes * 60))
            return
        }
        let proposed = current.addingTimeInterval(TimeInterval(minutes * 60))
        let minAllowed = wake
        let maxAllowed = wake.addingTimeInterval(60 * 60 * 12)
        leaveTime = min(max(proposed, minAllowed), maxAllowed)
    }

    // MARK: - Data

    private enum FactorKind: Identifiable {
        case tone, reason, intensity
        var id: Self { self }
    }

    /// Tone options shown in the picker (excludes `.other` which is reserved
    /// for free-form custom prompts entered elsewhere).
    private static let toneCases: [AlarmTone] = [.calm, .encourage, .push, .strict, .fun]
}

// MARK: - Previews

#Preview("Standard") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        CustomizeCard(
            tone: .constant(.calm),
            whyContext: .constant(.work),
            intensity: .constant(.gentle)
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("With Leave Time") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        CustomizeCard(
            tone: .constant(.calm),
            whyContext: .constant(nil),
            intensity: .constant(nil),
            leaveTime: .constant(nil),
            wakeTime: Calendar.current.date(from: DateComponents(hour: 7, minute: 0)),
            showLeaveTime: true
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("Edit Mode") {
    ZStack {
        Color(hex: "0f1a2e").ignoresSafeArea()
        CustomizeCard(
            tone: .constant(.encourage),
            whyContext: .constant(.gym),
            intensity: .constant(.balanced),
            mode: .edit
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}
