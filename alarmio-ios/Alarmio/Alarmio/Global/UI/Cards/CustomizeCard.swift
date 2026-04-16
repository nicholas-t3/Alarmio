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
    /// Optional toggle binding. Nil hides the Pro row. Non-nil drives the
    /// green switch and dims the other rows when true.
    @Binding var isProOn: Bool

    // MARK: - Constants

    let showProRow: Bool
    let proCustomized: Bool
    /// Called when the row is tapped (not the toggle). Only fires when
    /// `isProOn` is already true.
    let onTapProRow: (() -> Void)?
    /// Called when the toggle flips from off → on. The parent typically
    /// auto-navigates to the Pro screen from here.
    let onFlipProOn: (() -> Void)?
    let mode: CardMode

    // MARK: - State

    @State private var expandedFactor: FactorKind?

    // MARK: - Init

    init(
        tone: Binding<AlarmTone?>,
        whyContext: Binding<WhyContext?>,
        intensity: Binding<AlarmIntensity?>,
        isProOn: Binding<Bool> = .constant(false),
        showProRow: Bool = false,
        proCustomized: Bool = false,
        onTapProRow: (() -> Void)? = nil,
        onFlipProOn: (() -> Void)? = nil,
        mode: CardMode = .standard
    ) {
        self._tone = tone
        self._whyContext = whyContext
        self._intensity = intensity
        self._isProOn = isProOn
        self.showProRow = showProRow
        self.proCustomized = proCustomized
        self.onTapProRow = onTapProRow
        self.onFlipProOn = onFlipProOn
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

            // Tone / Reason / Intensity — dimmed + disabled when Pro is on
            // because these inputs don't feed the Pro generation flow.
            standardFactorRows
                .opacity(isProOn ? 0.25 : 1)
                .allowsHitTesting(!isProOn)
                .animation(.easeInOut(duration: 0.25), value: isProOn)

            // Pro customization (optional)
            if showProRow {
                Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 4)

                proRow
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: mode))
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
            // Uses an intermediary binding so we can fire `onFlipProOn` on
            // the off → on transition for auto-navigation.
            Toggle("", isOn: Binding(
                get: { isProOn },
                set: { newValue in
                    HapticManager.shared.selection()
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

#Preview("Pro On (dimmed)") {
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
