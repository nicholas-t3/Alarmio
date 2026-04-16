//
//  ProPromptView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/16/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

/// Full-screen Pro customization surface. Mounted inline inside
/// `CreateAlarmView` when `step == .proPrompt` so the MorningSky background
/// stays continuous — no modal seams, no re-mounted star canvas.
///
/// Lets a Pro user write a prompt describing what GPT should include,
/// toggle include flags (time of alarm, time to leave, humor, etc.),
/// configure Creative Snoozes, generate a text-only preview, and accept
/// the exact message to be used when the real audio is generated later.
struct ProPromptView: View {

    // MARK: - Environment

    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - Bindings

    @Binding var prompt: String
    @Binding var includes: Set<CustomPromptInclude>
    @Binding var leaveTime: Date?
    @Binding var creativeSnoozes: Bool

    // MARK: - Constants

    let wakeTime: Date?
    let cardsVisible: Bool
    let generated: String?
    let isGenerating: Bool
    let errorMessage: String?
    let onPromptChange: () -> Void

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.itemGap(deviceInfo.spacingScale)) {

                // Header title
                titleBlock
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0, duration: 0.4)

                // Custom prompt input
                promptCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0.05, duration: 0.4)

                // Include toggles
                includeCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0.1, duration: 0.4)

                // Creative snoozes
                creativeSnoozesCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0.15, duration: 0.4)

                // Generated message + actions
                if isGenerating || generated != nil || errorMessage != nil {
                    resultBlock
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .premiumBlur(isVisible: cardsVisible, delay: 0.2, duration: 0.4)
                }

                Spacer(minLength: 0)
                    .frame(height: 20)
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Subviews

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("PRO")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(Color(hex: "E9C46A"))

            Text("Custom Prompt")
                .font(AppTypography.headlineLarge)
                .tracking(AppTypography.headlineLargeTracking)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)

            Text("Tell us what your wake-up message should include.")
                .font(AppTypography.labelSmall)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Section label
            Text("GUIDELINES")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // TextEditor with placeholder
            ZStack(alignment: .topLeading) {
                if prompt.isEmpty {
                    Text("\"Keep it short and fun. Mention that I have a big meeting today and remind me to drink water.\"")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $prompt)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110, maxHeight: 180)
                    .onChange(of: prompt) { _, _ in onPromptChange() }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: .standard))
    }

    private var includeCard: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                Text("INCLUDE")
                    .font(AppTypography.caption)
                    .tracking(AppTypography.captionTracking)
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            }
            .padding(.bottom, 10)

            // Toggle rows
            ForEach(Array(CustomPromptInclude.allCases.enumerated()), id: \.element.id) { pair in
                let include = pair.element
                let isLast = pair.offset == CustomPromptInclude.allCases.count - 1

                includeRow(include)

                if include == .leaveTime && includes.contains(.leaveTime) {
                    LeaveTimePicker(leaveTime: $leaveTime, wakeTime: wakeTime)
                        .padding(.top, 4)
                        .padding(.bottom, 14)
                }

                if !isLast {
                    Divider().overlay(.white.opacity(0.08)).padding(.horizontal, 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: .standard))
    }

    private func includeRow(_ include: CustomPromptInclude) -> some View {
        let isOn = includes.contains(include)

        return HStack(spacing: 12) {
            Image(systemName: isOn ? include.onIconName : "circle.fill")
                .font(.system(size: isOn ? 14 : 7))
                .foregroundStyle(.white.opacity(isOn ? 0.9 : 0.3))
                .frame(width: 20)
                .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))

            Text(include.label)
                .font(AppTypography.labelLarge)
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(
                get: { includes.contains(include) },
                set: { newValue in
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        if newValue {
                            includes.insert(include)
                            if include == .leaveTime && leaveTime == nil {
                                leaveTime = LeaveTimePicker.defaultLeaveTime(wakeTime: wakeTime)
                            }
                        } else {
                            includes.remove(include)
                            if include == .leaveTime {
                                leaveTime = nil
                            }
                        }
                    }
                    onPromptChange()
                }
            ))
            .labelsHidden()
            .tint(Color(hex: "0a1628"))
        }
        .padding(.vertical, 14)
    }

    private var creativeSnoozesCard: some View {
        VStack(spacing: 6) {

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
                .tint(Color(hex: "0a1628"))
            }

            // Caption
            HStack {
                Text("We'll change the snooze message, but it'll still fit your vibe. Turn this off to repeat the same alarm each time.")
                    .font(AppTypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.leading, 32)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: .standard))
    }

    @ViewBuilder
    private var resultBlock: some View {
        if isGenerating {
            loadingCard
        } else if let text = generated {
            resultCard(text: text)
        } else if let error = errorMessage {
            errorCard(message: error)
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Writing your message…")
                .font(AppTypography.labelMedium)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: .standard))
    }

    private func resultCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PREVIEW")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            Text(text)
                .font(AppTypography.labelMedium)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: .standard))
    }

    private func errorCard(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(hex: "FF6B6B"))
            Text(message)
                .font(AppTypography.labelMedium)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: .standard))
    }

}

// MARK: - Previews

#Preview("Empty") {
    struct PreviewContainer: View {
        @State var prompt: String = ""
        @State var includes: Set<CustomPromptInclude> = []
        @State var leaveTime: Date? = nil
        @State var creativeSnoozes: Bool = true

        var body: some View {
            ZStack {
                MorningSky(starOpacity: 0.6, showConstellations: false)
                ProPromptView(
                    prompt: $prompt,
                    includes: $includes,
                    leaveTime: $leaveTime,
                    creativeSnoozes: $creativeSnoozes,
                    wakeTime: Calendar.current.date(from: DateComponents(hour: 7, minute: 0)),
                    cardsVisible: true,
                    generated: nil,
                    isGenerating: false,
                    errorMessage: nil,
                    onPromptChange: {}
                )
            }
            .preferredColorScheme(.dark)
        }
    }
    return PreviewContainer()
}

#Preview("With Preview") {
    struct PreviewContainer: View {
        @State var prompt: String = "Include a quote from Spaceballs and keep it short"
        @State var includes: Set<CustomPromptInclude> = [.alarmTime, .humor, .leaveTime]
        @State var leaveTime: Date? = Calendar.current.date(from: DateComponents(hour: 8, minute: 30))
        @State var creativeSnoozes: Bool = false

        var body: some View {
            ZStack {
                MorningSky(starOpacity: 0.6, showConstellations: false)
                ProPromptView(
                    prompt: $prompt,
                    includes: $includes,
                    leaveTime: $leaveTime,
                    creativeSnoozes: $creativeSnoozes,
                    wakeTime: Calendar.current.date(from: DateComponents(hour: 7, minute: 0)),
                    cardsVisible: true,
                    generated: "Good morning. It's 7 AM — time to rise and shine. May the Schwartz be with you today.",
                    isGenerating: false,
                    errorMessage: nil,
                    onPromptChange: {}
                )
            }
            .preferredColorScheme(.dark)
        }
    }
    return PreviewContainer()
}
