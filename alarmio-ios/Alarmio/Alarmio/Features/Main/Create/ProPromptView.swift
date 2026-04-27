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
    @Binding var creativeSnoozes: Bool

    // MARK: - Constants

    let cardsVisible: Bool
    let generated: String?
    let isGenerating: Bool
    let errorMessage: String?
    let onPromptChange: () -> Void

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Result card — only inserted after a successful generation.
                // Springs in above the prompt so the user sees their result
                // and can scroll up to edit the inputs if they want to try
                // again.
                if let text = generated, !isGenerating {
                    resultCard(text: text)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                // Error card — shown in place of the result when generation
                // failed.
                if let error = errorMessage, !isGenerating {
                    errorCard(message: error)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .transition(.opacity)
                }

                // Custom prompt input
                promptCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0.05, duration: 0.4)

                // Include chip cloud
                includeCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0.1, duration: 0.4)

                // Creative snoozes
                creativeSnoozesCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0.15, duration: 0.4)

                Spacer(minLength: 0)
                    .frame(height: 20)
            }
            .padding(.top, 8)
            .animation(.spring(response: 0.5, dampingFraction: 0.82), value: generated)
            .animation(.easeInOut(duration: 0.25), value: errorMessage)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Subviews

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Section label
            Text("GUIDELINES")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Vertical TextField wraps onto multiple visible lines as the
            // user types, but return dismisses the keyboard instead of
            // inserting a newline. We intercept any newline the user
            // types, strip it, and fire resignFirstResponder.
            TextField(
                "\"Keep it short and fun. Mention that I have a big meeting today and remind me to drink water.\"",
                text: $prompt,
                axis: .vertical
            )
            .font(AppTypography.labelMedium)
            .foregroundStyle(.white)
            .tint(.white)
            .lineLimit(1...6)
            .submitLabel(.done)
            .onChange(of: prompt) { _, newValue in
                if newValue.contains("\n") {
                    prompt = newValue.replacingOccurrences(of: "\n", with: "")
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                onPromptChange()
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: .standard))
    }

    private var includeCard: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            Text("INCLUDE")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Chip cloud — flowing wrap of include tags, tap to toggle.
            // `.leaveTime` is intentionally excluded: Time to Leave is owned
            // by the Customize card's toggle, and the composer auto-reads
            // draft.leaveTime; no user-facing chip needed here.
            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(CustomPromptInclude.allCases.filter { $0 != .leaveTime }) { include in
                    includeChip(include)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: .standard))
    }

    private func includeChip(_ include: CustomPromptInclude) -> some View {
        let isOn = includes.contains(include)

        return Button {
            HapticManager.shared.selection()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                if isOn {
                    includes.remove(include)
                } else {
                    includes.insert(include)
                }
            }
            onPromptChange()
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

    private func resultCard(text: String) -> some View {
        VStack(spacing: 14) {

            Text("PREVIEW")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            Text(Self.stripTTSTags(text))
                .font(AppTypography.labelMedium)
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: .standard))
    }

    /// Remove ElevenLabs `<break time="..."/>` pronunciation markers for
    /// user-visible display. The raw text (with tags) is still what goes
    /// to TTS — we only clean up the preview. Collapses any double-spaces
    /// left behind so punctuation like `. <break> Next sentence` renders
    /// as `. Next sentence` rather than `.  Next sentence`.
    private static func stripTTSTags(_ text: String) -> String {
        let breakPattern = #"\s*<break\s+time="[^"]+"\s*/?>\s*"#
        let withoutTags: String
        if let regex = try? NSRegularExpression(pattern: breakPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            withoutTags = regex.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
        } else {
            withoutTags = text
        }
        return withoutTags
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
        @State var creativeSnoozes: Bool = true

        var body: some View {
            ZStack {
                MorningSky(starOpacity: 0.6, showConstellations: false)
                ProPromptView(
                    prompt: $prompt,
                    includes: $includes,
                    creativeSnoozes: $creativeSnoozes,
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
        @State var includes: Set<CustomPromptInclude> = [.alarmTime, .humor]
        @State var creativeSnoozes: Bool = false

        var body: some View {
            ZStack {
                MorningSky(starOpacity: 0.6, showConstellations: false)
                ProPromptView(
                    prompt: $prompt,
                    includes: $includes,
                    creativeSnoozes: $creativeSnoozes,
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
