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
    /// Kept in sync with `leaveTime` so pro scripts (and the reconciler) know
    /// when Time to Leave should influence the generated text. The toggle
    /// adds/removes `.leaveTime` here as it flips.
    @Binding var customPromptIncludes: Set<CustomPromptInclude>
    /// Pro guidelines text. Only mounted when `showProInlineRows && isProOn`.
    @Binding var customPrompt: String
    /// Toggle for the Creative Snoozes row. Only mounted when
    /// `showProInlineRows && isProOn`.
    @Binding var creativeSnoozes: Bool
    /// Optional toggle binding. Nil hides the Pro row.
    @Binding var isProOn: Bool

    // MARK: - Constants

    let wakeTime: Date?
    let showLeaveTime: Bool
    let showProRow: Bool
    let proCustomized: Bool
    /// When true the card grows three extra rows (Guidelines, Include,
    /// Creative Snoozes) whenever `isProOn` is true. Step 2 of
    /// `CreateAlarmView` passes true; the confirmation and edit surfaces
    /// still default to false.
    let showProInlineRows: Bool
    /// Called when the row is tapped (not the toggle). Only fires when
    /// `isProOn` is already true.
    let onTapProRow: (() -> Void)?
    /// Called when the toggle flips from off → on. The parent typically
    /// auto-navigates to the Pro screen from here.
    let onFlipProOn: (() -> Void)?
    /// Called whenever the Pro toggle flips (on or off) and the parent
    /// wants to intercept the transition — e.g. to run a coordinated
    /// blur-out/blur-in sequence before committing the model change.
    /// When non-nil, the toggle delegates the actual `isProOn` write to
    /// this callback instead of setting the binding directly.
    let onFlipPro: ((Bool) -> Void)?
    let mode: CardMode

    // MARK: - State

    @State private var expandedFactor: FactorKind?

    // MARK: - Init

    init(
        tone: Binding<AlarmTone?>,
        whyContext: Binding<WhyContext?>,
        intensity: Binding<AlarmIntensity?>,
        leaveTime: Binding<Date?> = .constant(nil),
        customPromptIncludes: Binding<Set<CustomPromptInclude>> = .constant([]),
        customPrompt: Binding<String> = .constant(""),
        creativeSnoozes: Binding<Bool> = .constant(true),
        wakeTime: Date? = nil,
        showLeaveTime: Bool = false,
        isProOn: Binding<Bool> = .constant(false),
        showProRow: Bool = false,
        showProInlineRows: Bool = false,
        proCustomized: Bool = false,
        onTapProRow: (() -> Void)? = nil,
        onFlipProOn: (() -> Void)? = nil,
        onFlipPro: ((Bool) -> Void)? = nil,
        mode: CardMode = .standard
    ) {
        self._tone = tone
        self._whyContext = whyContext
        self._intensity = intensity
        self._leaveTime = leaveTime
        self._customPromptIncludes = customPromptIncludes
        self._customPrompt = customPrompt
        self._creativeSnoozes = creativeSnoozes
        self.wakeTime = wakeTime
        self.showLeaveTime = showLeaveTime
        self._isProOn = isProOn
        self.showProRow = showProRow
        self.showProInlineRows = showProInlineRows
        self.proCustomized = proCustomized
        self.onTapProRow = onTapProRow
        self.onFlipProOn = onFlipProOn
        self.onFlipPro = onFlipPro
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

            // Pro row (optional, shown first so it's the entry point for
            // the whole card). Tone/Reason/Intensity flow through to the
            // Pro text endpoint too, so they stay fully active when Pro
            // is on — no more dimming.
            if showProRow {
                proRow

                Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 4)
            }

            // Guidelines — slotted here (second) when Pro is on so it's
            // the very first Pro-specific input the user sees. Auto-opens
            // on entry (via the `.task` below) so they can start typing
            // without an extra tap.
            if showProRow && showProInlineRows && isProOn {
                guidelinesRowGroup

                Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 4)
            }

            standardFactorRows

            // Remaining Pro rows (Include + Creative Snoozes) stay at
            // the bottom so related basic settings stay grouped above.
            if showProRow && showProInlineRows && isProOn {
                proInlineRows
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: mode))
        .onChange(of: isProOn) { _, newValue in
            // Auto-expand Guidelines as soon as Pro turns on so the user
            // lands on an open text field — matches the old Pro screen,
            // which led with the prompt. Collapse when Pro turns off.
            if newValue && showProInlineRows {
                expandedFactor = .guidelines
            } else if !newValue {
                expandedFactor = nil
            }
        }
    }

    // MARK: - Standard Rows

    private var standardFactorRows: some View {
        VStack(spacing: 0) {

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

            // Leave time — shown here in the basic flow. In Pro mode it's
            // reordered below Include (see `proInlineRows`), so skip here.
            if showLeaveTime && !(showProInlineRows && isProOn) {
                Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 4)

                leaveTimeRow

                inlineExpandable(isOpen: leaveTime != nil) {
                    leaveTimeInlinePicker
                }
            }
        }
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
        pulseWhenUnset: Bool = true,
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
                    .foregroundStyle(.white.opacity(hasSelection ? 0.7 : 0.45))
                    .contentTransition(.numericText())
                    .modifier(UnsetValuePulse(isActive: pulseWhenUnset && !hasSelection))

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
                            customPromptIncludes.insert(.leaveTime)
                            expandedFactor = nil
                        } else {
                            leaveTime = nil
                            customPromptIncludes.remove(.leaveTime)
                        }
                    }
                }
            ))
            .labelsHidden()
            .tint(Color(hex: "4AFF8E"))
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

    // MARK: - Pro Row

    private var proRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "E9C46A"))
                .frame(width: 20)

            // Row label — tapping this area navigates to the Pro screen
            // when the toggle is on.
            Button {
                guard isProOn else { return }
                HapticManager.shared.buttonTap()
                onTapProRow?()
            } label: {
                HStack(spacing: 8) {
                    Text("Pro")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Toggle — green when on, matches the confirmation-hero green.
            // If the parent supplied `onFlipPro`, hand the value to it and
            // let the parent write `isProOn` at the right moment in its
            // transition choreography. Otherwise fall back to the legacy
            // behavior: write immediately and fire `onFlipProOn` on off→on.
            Toggle("", isOn: Binding(
                get: { isProOn },
                set: { newValue in
                    HapticManager.shared.selection()
                    if let onFlipPro {
                        onFlipPro(newValue)
                        return
                    }
                    let wasOff = !isProOn
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isProOn = newValue
                    }
                    if newValue && wasOff {
                        onFlipProOn?()
                    }
                }
            ))
            .labelsHidden()
            .tint(Color(hex: "4AFF8E"))
        }
        .padding(.vertical, 14)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: proCustomized)
    }

    // MARK: - Pro Inline Rows

    /// Guidelines row + its expandable editor. Pulled out of `proInlineRows`
    /// so it can be slotted as the second row (right after Pro) instead of
    /// at the bottom of the card.
    private var guidelinesRowGroup: some View {
        VStack(spacing: 0) {

            factorRow(
                icon: customPrompt.isEmpty ? Self.unsetIcon : "text.bubble.fill",
                label: "Guidelines",
                value: guidelinesSummary,
                hasSelection: !customPrompt.isEmpty,
                isExpanded: expandedFactor == .guidelines
            ) {
                toggleFactor(.guidelines)
            }

            inlineExpandable(isOpen: expandedFactor == .guidelines) {
                guidelinesInlineEditor
            }
        }
    }

    /// Include → Leave Time → Creative Snoozes. Shown at the bottom of the
    /// card when Pro is on. Guidelines used to live here too but was
    /// promoted to a top slot because it's the primary Pro input. Leave
    /// Time is reordered here (below Include) in Pro mode only; the basic
    /// flow still shows it inside `standardFactorRows`.
    private var proInlineRows: some View {
        VStack(spacing: 0) {

            Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 4)

            // Include — optional; no pulse when unset.
            factorRow(
                icon: includeChipsSelected.isEmpty ? Self.unsetIcon : "checklist",
                label: "Include",
                value: includeSummary,
                hasSelection: !includeChipsSelected.isEmpty,
                isExpanded: expandedFactor == .includeTags,
                pulseWhenUnset: false
            ) {
                toggleFactor(.includeTags)
            }

            inlineExpandable(isOpen: expandedFactor == .includeTags) {
                includeInlineChips
            }

            // Leave Time — reordered here in Pro mode so it sits with the
            // other content-shaping toggles.
            if showLeaveTime {
                Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 4)

                leaveTimeRow

                inlineExpandable(isOpen: leaveTime != nil) {
                    leaveTimeInlinePicker
                }
            }

            Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 4)

            // Creative Snoozes — toggle-only row. Caption beneath, matching
            // the old ProPromptView.creativeSnoozesCard copy.
            creativeSnoozesRow
        }
    }

    private var guidelinesSummary: String {
        let trimmed = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Tap to write" : ""
    }

    /// User-selectable include chips, with `.leaveTime` hidden — Time to
    /// Leave is owned by the standard leave-time row.
    private var includeChipsSelected: [CustomPromptInclude] {
        CustomPromptInclude.allCases
            .filter { $0 != .leaveTime && customPromptIncludes.contains($0) }
    }

    private var includeSummary: String {
        let selected = includeChipsSelected
        switch selected.count {
        case 0:  return "Optional"
        case 1:  return selected[0].label
        default: return "\(selected.count) selections"
        }
    }

    private var guidelinesInlineEditor: some View {
        TextField(
            "",
            text: $customPrompt,
            prompt: Text("Keep it short and fun. Mention my big meeting today and remind me to drink water.")
                .foregroundStyle(.white.opacity(0.3)),
            axis: .vertical
        )
        .font(AppTypography.labelMedium)
        .foregroundStyle(.white)
        .tint(.white)
        .lineLimit(4...)
        .submitLabel(.done)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        // `maxHeight: .infinity` + `.topLeading` alignment makes the text
        // stick to the top-left instead of vertically centering. `minHeight`
        // reserves enough vertical room for the full placeholder on
        // narrower screens (iPhone SE/17 wrap it to ~3 lines), so nothing
        // gets truncated and the box is tall enough to feel like a prompt
        // input rather than a single-line field.
        .frame(
            maxWidth: .infinity,
            minHeight: 92,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .onChange(of: customPrompt) { _, newValue in
            // Strip user-typed newlines and resign first responder so the
            // keyboard's Return key acts as Done, matching the old
            // ProPromptView.promptCard behavior.
            if newValue.contains("\n") {
                customPrompt = newValue.replacingOccurrences(of: "\n", with: "")
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        }
    }

    private var includeInlineChips: some View {
        FlowLayout(spacing: 8, rowSpacing: 8) {
            ForEach(CustomPromptInclude.allCases.filter { $0 != .leaveTime }) { include in
                includeChip(include)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func includeChip(_ include: CustomPromptInclude) -> some View {
        let isOn = customPromptIncludes.contains(include)

        return Button {
            HapticManager.shared.selection()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                if isOn {
                    customPromptIncludes.remove(include)
                } else {
                    customPromptIncludes.insert(include)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: include.onIconName)
                    .font(.system(size: 11))
                Text(include.label)
                    .font(AppTypography.labelSmall)
            }
            .foregroundStyle(isOn ? .black : .white.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isOn ? .white : .white.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isOn)
    }

    private var creativeSnoozesRow: some View {
        VStack(spacing: 0) {

            // Toggle row
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(creativeSnoozes ? 0.9 : 0.3))
                    .frame(width: 20)

                Text("Creative Snoozes")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                Toggle("", isOn: Binding(
                    get: { creativeSnoozes },
                    set: { newValue in
                        HapticManager.shared.selection()
                        creativeSnoozes = newValue
                    }
                ))
                .labelsHidden()
                .tint(Color(hex: "4AFF8E"))
            }
            .padding(.vertical, 14)

            // Caption — centered to match the Leave Time picker's caption.
            // `inlineExpandable` uses the same premiumBlur + height-clip
            // so it disappears cleanly instead of sliding.
            inlineExpandable(isOpen: creativeSnoozes) {
                Text("We'll change the snooze message, but it'll still fit your vibe. Turn this off to repeat the same alarm each time.")
                    .font(AppTypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Data

    private enum FactorKind: Identifiable {
        case tone, reason, intensity, guidelines, includeTags
        var id: Self { self }
    }

    /// Tone options shown in the picker (excludes `.other` which is reserved
    /// for free-form custom prompts entered elsewhere).
    private static let toneCases: [AlarmTone] = [.calm, .encourage, .push, .strict, .fun]
}

// MARK: - Unset Value Pulse

/// Gentle repeating opacity/scale pulse applied to a factor row's value
/// text when the row has no selection — draws the eye without requiring
/// a default. Stops pulsing the instant the row has a value (the user
/// can't unset a factor once chosen, so there's no awkward flicker).
private struct UnsetValuePulse: ViewModifier {

    // MARK: - Constants

    let isActive: Bool

    // MARK: - State

    @State private var pulseOn: Bool = false

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? (pulseOn ? 1.0 : 0.55) : 1.0)
            .scaleEffect(isActive ? (pulseOn ? 1.02 : 1.0) : 1.0)
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulseOn = true
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    pulseOn = false
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                        pulseOn = true
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        pulseOn = false
                    }
                }
            }
    }
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

#Preview("Pro Off") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        CustomizeCard(
            tone: .constant(.calm),
            whyContext: .constant(nil),
            intensity: .constant(nil),
            isProOn: .constant(false),
            showProRow: true,
            proCustomized: false,
            onTapProRow: { },
            onFlipProOn: { }
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("Pro On (legacy dim)") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        CustomizeCard(
            tone: .constant(.calm),
            whyContext: .constant(.work),
            intensity: .constant(.balanced),
            isProOn: .constant(true),
            showProRow: true,
            proCustomized: true,
            onTapProRow: { },
            onFlipProOn: { }
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("Pro Inline Rows") {
    struct PreviewContainer: View {
        @State var tone: AlarmTone? = .calm
        @State var why: WhyContext? = .work
        @State var intensity: AlarmIntensity? = .balanced
        @State var leaveTime: Date? = Calendar.current.date(from: DateComponents(hour: 8, minute: 0))
        @State var includes: Set<CustomPromptInclude> = [.alarmTime, .humor]
        @State var prompt: String = "Keep it short and fun"
        @State var creative: Bool = true
        @State var isPro: Bool = true

        var body: some View {
            ZStack {
                Color(hex: "050505").ignoresSafeArea()
                ScrollView {
                    CustomizeCard(
                        tone: $tone,
                        whyContext: $why,
                        intensity: $intensity,
                        leaveTime: $leaveTime,
                        customPromptIncludes: $includes,
                        customPrompt: $prompt,
                        creativeSnoozes: $creative,
                        wakeTime: Calendar.current.date(from: DateComponents(hour: 7, minute: 0)),
                        showLeaveTime: true,
                        isProOn: $isPro,
                        showProRow: true,
                        showProInlineRows: true,
                        proCustomized: true
                    )
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }
            }
        }
    }
    return PreviewContainer()
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
