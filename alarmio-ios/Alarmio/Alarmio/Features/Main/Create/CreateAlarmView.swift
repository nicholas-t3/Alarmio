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
    @Environment(\.composerService) private var composerService
    @Environment(\.alertManager) private var alertManager
    @Environment(\.alarmStore) private var alarmStore
    @Environment(\.subscriptionService) private var subscriptionService

    // MARK: - State

    // Local draft — what the user is currently editing. Never passed
    // straight to onCreate; the audio may not yet reflect these values.
    @State private var draft = AlarmConfiguration(
        intensity: .gentle,
        customPromptIncludes: [.alarmTime]
    )
    // Committed config — promoted from draft only after a successful
    // generation, so it always matches the audio file that exists on disk.
    // This is what gets persisted when the user taps Schedule.
    @State private var committed = AlarmConfiguration(
        intensity: .gentle,
        customPromptIncludes: [.alarmTime]
    )
    @State private var step: Step
    @State private var showPaywall: Bool = false
    /// All scripts returned from the last preview call — `[0]` is the main
    /// wake-up message shown to the user; `[1...]` are snoozes (if creative
    /// snoozes are on and snoozes are configured). Saved to
    /// `draft.approvedScripts` when the user taps "Use This".
    @State private var proPreviewScripts: [String]?
    /// Snapshot of the inputs that produced `proPreviewScripts`. Compared
    /// against live draft values to decide whether the CTA should read
    /// "Save" (clean) or "Regenerate" (dirty).
    @State private var proPreviewSnapshot: ProPreviewInputs?
    @State private var proPreviewIsGenerating: Bool = false
    @State private var proPreviewError: String?
    /// Whether the user pressed Save during the current visit to the Pro
    /// screen. Reset on entry; consulted on exit to decide whether to revert
    /// `alarmType` back to `.basic` (if they backed out without saving).
    @State private var proSavedThisVisit: Bool = false
    /// Snapshot of the draft at the moment the user last saved on the Pro
    /// screen. Used as the "old" baseline by `ProScriptReconciler` when the
    /// user comes back to step 1 and changes snooze count or wake time —
    /// we need the original times/counts to detect drift.
    @State private var lastProSnapshot: AlarmConfiguration?
    /// True while reconcile is running on the Next button. Shows a spinner
    /// on the button and prevents double-taps.
    @State private var isReconciling: Bool = false
    /// When true, the confirmation card is swapped out for the Pro prompt
    /// editor. Only meaningful during `.confirming` phase. Mirrors the
    /// step-machine's `.proPrompt` step but inside the confirmation phase,
    /// which doesn't have a step machine of its own.
    @State private var confirmationProEditMode: Bool = false
    /// Snapshot of all pro-editable fields at the moment the user enters
    /// the Pro editor from the confirmation screen. Used to revert every
    /// field on back-without-save — matches the edit sheet's behavior.
    @State private var confirmationProRestore: ProFieldsSnapshot?
    @State private var cardsVisible = false
    @State private var buttonVisible = false
    @State private var isTransitioning = false
    /// Guards `flipPro` against double-taps while the coordinated blur-out-
    /// then-blur-in is in flight, otherwise a second toggle could swap the
    /// voice card mid-fade and look glitchy.
    @State private var proTransitioning = false
    @State private var selectedDays: Set<Int> = []
    @State private var voiceIndex: Int = 0
    @State private var voicePlayer = VoicePreviewPlayer()
    @State private var waveformPulse: Bool = false
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
    @State private var showRegenSuccess: Bool = false
    @State private var regenSuccessTask: Task<Void, Never>?
    @State private var showNameSheet: Bool = false
    @State private var sunriseTask: Task<Void, Never>?
    @State private var starSpinTask: Task<Void, Never>?

    // MARK: - Constants

    let onCreate: (AlarmConfiguration) -> Void

    // MARK: - Init

    init(
        initialStep: Int = 1,
        initialPhase: Phase = .configuring,
        previewStatusText: String = "",
        onCreate: @escaping (AlarmConfiguration) -> Void
    ) {
        self._step = State(initialValue: Step(legacy: initialStep))
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
                    switch step {
                    case .configure: stepOne
                    case .customize: stepTwo
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
            draft.wakeTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0))
            draft.voicePersona = heroVoices[voiceIndex].persona
            try? await Task.sleep(for: .milliseconds(100))
            cardsVisible = true
            try? await Task.sleep(for: .milliseconds(500))
            buttonVisible = true
        }
        .onChange(of: draft.tone) { invalidateRegenSuccess() }
        .onChange(of: draft.whyContext) { invalidateRegenSuccess() }
        .onChange(of: draft.intensity) { invalidateRegenSuccess() }
        .onChange(of: draft.voicePersona) { invalidateRegenSuccess() }
        // Keep the layout anchored; keyboard draws over instead of pushing
        // the pinned button up. Applied at root level so it takes effect
        // across the fullScreenCover boundary.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Tap anywhere outside a text field to dismiss the keyboard.
        .contentShape(Rectangle())
        .onTapGesture { dismissKeyboard() }
        // Debug: print full draft on every change. Uncomment to re-enable.
        // .onChange(of: draft) { _, newValue in
        //     print("[draft] ────────────────────────────────────────────")
        //     dump(newValue)
        // }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {

            // Back / Close — hidden during generating, during the
            // confirmation summary card (terminal state, use Regenerate
            // button instead), and while the Pro preview is in flight.
            // Shown on configuring steps AND on confirmation's Pro editor
            // substate.
            let onConfirmPro = phase == .confirming && confirmationProEditMode
            let hideBack = (phase == .generating)
                || (phase == .confirming && !confirmationProEditMode)
                || (onConfirmPro && proPreviewIsGenerating)

            if !hideBack {
                Button {
                    HapticManager.shared.buttonTap()
                    if onConfirmPro {
                        // Back from Pro editor on confirmation → revert
                        // every pro-editable field if the user didn't
                        // save. Matches the edit sheet's behavior.
                        if !proSavedThisVisit, let restore = confirmationProRestore {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                draft.alarmType = restore.alarmType
                                draft.approvedScripts = restore.approvedScripts
                                draft.customPrompt = restore.customPrompt
                                draft.customPromptIncludes = restore.customPromptIncludes
                                draft.creativeSnoozes = restore.creativeSnoozes
                                proPreviewScripts = restore.previewScripts
                                proPreviewSnapshot = restore.previewSnapshot
                            }
                        }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            confirmationProEditMode = false
                        }
                        return
                    }
                    switch step {
                    case .configure:
                        dismiss()
                    case .customize:
                        transitionToStep(.configure)
                    }
                } label: {
                    Image(systemName: (step == .configure && !onConfirmPro) ? "xmark" : "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
                    .transition(.opacity)
            }

            Spacer()

            // Title — swaps per phase / step
            headerTitleView
                .animation(.easeInOut(duration: 0.3), value: phase)
                .animation(.easeInOut(duration: 0.3), value: step)

            Spacer()

            // Invisible spacer to balance
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal - 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: proPreviewIsGenerating)
    }

    @ViewBuilder
    private var headerTitleView: some View {
        switch phase {
        case .generating:
            Color.clear.frame(height: 22)
        default:
            Text("New Alarm")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .transition(.opacity)
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
        WakeTimeCard(wakeTime: Binding(
            get: { draft.wakeTime ?? Date() },
            set: { draft.wakeTime = $0 }
        ))
    }

    private var scheduleCard: some View {
        RepeatCard(selectedDays: $selectedDays)
            .onChange(of: selectedDays) { _, newDays in
                draft.repeatDays = newDays.isEmpty ? nil : Array(newDays).sorted()
            }
    }

    private var snoozeCard: some View {
        SnoozeCard(
            maxSnoozes: $draft.maxSnoozes,
            snoozeInterval: $draft.snoozeInterval,
            unlimitedSnooze: $draft.unlimitedSnooze,
            allowUnlimited: true
        )
    }

    // MARK: - Step 2: Style

    private var stepTwo: some View {
        ScrollView {
            VStack(spacing: AppSpacing.itemGap(deviceInfo.spacingScale)) {

                // Voice — hero when Pro off, compact playable when Pro on.
                // Swapped via if/else so the VStack tracks the visible
                // card's intrinsic height (ZStack would reserve the hero's
                // full height and leave a dead gap above CustomizeCard).
                // `flipPro` blurs `cardsVisible` out before mutating
                // `alarmType`, so the actual swap happens while both
                // halves are invisible — no visible jump.
                Group {
                    if draft.alarmType == .pro {
                        compactPlayableVoiceCard
                    } else {
                        voiceHeroCard
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .premiumBlur(isVisible: cardsVisible, delay: 0, duration: 0.4)

                // Customize (tone + reason + intensity + leave time + pro
                // row + inline Pro rows when Pro is on).
                CustomizeCard(
                    tone: $draft.tone,
                    whyContext: $draft.whyContext,
                    intensity: $draft.intensity,
                    leaveTime: $draft.leaveTime,
                    customPromptIncludes: $draft.customPromptIncludes,
                    customPrompt: Binding(
                        get: { draft.customPrompt ?? "" },
                        set: { draft.customPrompt = $0.isEmpty ? nil : $0 }
                    ),
                    creativeSnoozes: $draft.creativeSnoozes,
                    wakeTime: draft.wakeTime,
                    showLeaveTime: true,
                    isProOn: Binding(
                        get: { draft.alarmType == .pro },
                        set: { _ in /* write goes through onFlipPro */ }
                    ),
                    showProRow: true,
                    showProInlineRows: true,
                    proCustomized: draft.approvedScripts != nil,
                    onTapProRow: handleTapProRow,
                    onFlipProOn: nil,
                    onFlipPro: { newValue in flipPro(to: newValue) }
                )
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .premiumBlur(isVisible: cardsVisible, delay: 0.1, duration: 0.4)

                // Pro text preview — only when Pro and we have a result.
                if draft.alarmType == .pro,
                   !proPreviewIsGenerating,
                   let first = proPreviewScripts?.first {
                    proResultCard(text: first)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                // Pro error card — shown in place of the preview on failure.
                if draft.alarmType == .pro,
                   !proPreviewIsGenerating,
                   let err = proPreviewError {
                    proErrorCard(message: err)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .transition(.opacity)
                }

                Spacer()
                    .frame(height: 20)
            }
            .padding(.top, 8)
            .animation(.spring(response: 0.5, dampingFraction: 0.82), value: proPreviewScripts)
            .animation(.easeInOut(duration: 0.25), value: proPreviewError)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .mask(scrollFadeMask)
    }

    private var compactPlayableVoiceCard: some View {
        let voice = heroVoices[voiceIndex]
        let isPlayingThis = voicePlayer.isPlaying && voicePlayer.currentPersona == voice.persona
        return CompactPlayableVoiceCard(
            voice: voice,
            isPlayingThis: isPlayingThis,
            onPrev: { cycleVoice(by: -1) },
            onNext: { cycleVoice(by: 1) },
            onTogglePlay: { togglePreview() }
        )
    }

    /// Mirror of `ProPromptView.resultCard` — inline copy so step 2 can show
    /// the pro text preview without pulling in the whole ProPromptView.
    /// Intentionally near-duplicate; will de-dup after the confirmation
    /// phase is redesigned to match.
    private func proResultCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PREVIEW")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            Text(Self.stripTTSTags(text))
                .font(AppTypography.labelMedium)
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: .standard))
    }

    private func proErrorCard(message: String) -> some View {
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

    /// Strip `<break time="..."/>` ElevenLabs tags from a TTS script so the
    /// in-app preview reads cleanly. Raw (tagged) text is still what goes
    /// to the audio endpoint.
    private static func stripTTSTags(_ text: String) -> String {
        let pattern = #"\s*<break\s+time="[^"]+"\s*/?>\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        let stripped = regex.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
        return stripped
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
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
        draft.voicePersona = heroVoices[newIndex].persona

        // Pulse the waveform briefly so the change is visible even when
        // audio isn't playing.
        waveformPulse = true
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            waveformPulse = false
        }

        // On the confirmation screen the preview plays the generated file,
        // which is tied to the previously selected voice. Cycling makes that
        // file stale, so stop playback and let the user regenerate.
        if phase == .confirming {
            voicePlayer.stop()
            return
        }

        // If a bundled-voice preview is in flight during configuration,
        // hand it off to the new voice so the user keeps momentum.
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

            // Substate 2a: Confirmation summary card
            if confirmationHeroExited && !confirmationProEditMode {
                confirmationCard
                    .transition(.opacity)
            }

            // Substate 2b: Pro editor (in place of the summary card)
            if confirmationHeroExited && confirmationProEditMode {
                confirmationProEditor
                    .transition(.opacity)
            }
        }
        .task {
            await runConfirmationSequence()
        }
    }

    private var confirmationProEditor: some View {
        ProPromptView(
            prompt: Binding(
                get: { draft.customPrompt ?? "" },
                set: { draft.customPrompt = $0.isEmpty ? nil : $0 }
            ),
            includes: $draft.customPromptIncludes,
            creativeSnoozes: $draft.creativeSnoozes,
            cardsVisible: confirmationCardVisible,
            generated: proPreviewScripts?.first,
            isGenerating: proPreviewIsGenerating,
            errorMessage: proPreviewError,
            onPromptChange: handleProPromptInputChange
        )
        .mask(scrollFadeMask)
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
        ScrollView {
            VStack(spacing: AppSpacing.itemGap(deviceInfo.spacingScale)) {

                // Alarm audio preview
                alarmPreviewCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: confirmationCardVisible, delay: 0, duration: 0.5)

                // Compact voice selector
                compactVoiceCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: confirmationCardVisible, delay: 0.1, duration: 0.5)

                // Name row (under voice — matches voice card dimensions)
                NameRowCard(name: committed.name, style: .clear) {
                    HapticManager.shared.softTap()
                    showNameSheet = true
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .premiumBlur(isVisible: confirmationCardVisible, delay: 0.15, duration: 0.5)

                // Customize (tone + reason + intensity + leave time + Pro)
                CustomizeCard(
                    tone: $draft.tone,
                    whyContext: $draft.whyContext,
                    intensity: $draft.intensity,
                    leaveTime: $draft.leaveTime,
                    customPromptIncludes: $draft.customPromptIncludes,
                    wakeTime: draft.wakeTime,
                    showLeaveTime: true,
                    isProOn: Binding(
                        get: { draft.alarmType == .pro },
                        set: { draft.alarmType = $0 ? .pro : .basic }
                    ),
                    showProRow: true,
                    proCustomized: draft.approvedScripts != nil,
                    onTapProRow: handleTapProRow,
                    onFlipProOn: handleFlipProOn
                )
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .premiumBlur(isVisible: confirmationCardVisible, delay: 0.2, duration: 0.5)

                // Regenerate button
                regenerateButton
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: confirmationCardVisible, delay: 0.25, duration: 0.5)

                Spacer(minLength: 0)
                    .frame(height: 20)
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .mask(scrollFadeMask)
        .sheet(isPresented: $showNameSheet) {
            NameAlarmSheet(initialName: committed.name ?? "") { newName in
                committed.name = newName.isEmpty ? nil : newName
            }
            .presentationDetents([.height(240)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(hex: "0f1a2e"))
        }
    }

    // MARK: - Confirmation: Alarm Preview Card

    private var alarmPreviewCard: some View {
        let isPlaying = voicePlayer.isPlaying

        return VStack(spacing: 14) {

            Text("ALARM PREVIEW")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Waveform
            VoiceWaveform(bands: voicePlayer.bands, isPlaying: isPlaying)
                .frame(height: 40)
                .padding(.horizontal, 8)

            // Play button
            Button {
                HapticManager.shared.buttonTap()
                toggleAlarmPreview()
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
            .disabled(committed.soundFileName == nil || isRegenerating)
            .opacity(committed.soundFileName == nil ? 0.4 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPlaying)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Confirmation: Compact Voice Card

    private var compactVoiceCard: some View {
        let voice = heroVoices[voiceIndex]

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
                Text(voice.name)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(voice.descriptor)
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
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Confirmation: Regenerate Button

    private var hasStyleChanges: Bool {
        draft.tone != committed.tone
            || draft.whyContext != committed.whyContext
            || draft.intensity != committed.intensity
            || draft.voicePersona != committed.voicePersona
    }

    private var regenerateButtonLabel: String {
        if showRegenSuccess { return "Success" }
        if isRegenerating { return "Generating..." }
        return "Regenerate"
    }

    private var regenerateButtonForeground: Color {
        if showRegenSuccess { return Color(hex: "4AFF8E") }
        let active = hasStyleChanges && draftIsReadyToGenerate && !isRegenerating
        return .white.opacity(active ? 1 : 0.35)
    }

    private var regenerateButtonBackground: Color {
        if showRegenSuccess { return Color(hex: "4AFF8E").opacity(0.15) }
        let active = hasStyleChanges && draftIsReadyToGenerate
        return .white.opacity(active ? 0.1 : 0.04)
    }

    /// Whether the draft has the fields needed to generate a new alarm.
    /// Pro alarms need approved scripts; basic alarms need tone/why/intensity
    /// so the generic Composer prompt has enough context. Matches the gate
    /// on step 2's "Create Alarm" button.
    private var draftIsReadyToGenerate: Bool {
        if draft.alarmType == .pro {
            return draft.approvedScripts?.isEmpty == false
        }
        return draft.tone != nil && draft.whyContext != nil && draft.intensity != nil
    }

    private var regenerateButton: some View {
        Button {
            HapticManager.shared.buttonTap()
            regenerateAlarm()
        } label: {
            HStack(spacing: 8) {
                if isRegenerating {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else if showRegenSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                }

                Text(regenerateButtonLabel)
                    .font(AppTypography.labelMedium)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(regenerateButtonForeground)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(regenerateButtonBackground)
            .clipShape(Capsule())
            .overlay {
                if showRegenSuccess {
                    Capsule()
                        .strokeBorder(Color(hex: "4AFF8E").opacity(0.6), lineWidth: 1)
                }
            }
            .shadow(color: showRegenSuccess ? Color(hex: "4AFF8E").opacity(0.2) : .clear, radius: 12, y: 0)
        }
        .disabled(!hasStyleChanges || !draftIsReadyToGenerate || isRegenerating || showRegenSuccess)
        .animation(.easeInOut(duration: 0.35), value: showRegenSuccess)
        .animation(.easeInOut(duration: 0.25), value: isRegenerating)
    }

    /// Promote the current draft to committed after a successful generation.
    /// The audio file on disk now matches these style fields, so it's safe
    /// to persist them if the user taps Schedule.
    private func promoteDraftToCommitted(soundFileName: String) {
        var next = draft
        next.soundFileName = soundFileName
        committed = next
    }

    private func triggerRegenSuccess() {
        regenSuccessTask?.cancel()
        showRegenSuccess = true

        regenSuccessTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            showRegenSuccess = false
        }
    }

    private func invalidateRegenSuccess() {
        if showRegenSuccess {
            regenSuccessTask?.cancel()
            regenSuccessTask = nil
            showRegenSuccess = false
        }
    }

    private func toggleAlarmPreview() {
        if voicePlayer.isPlaying {
            voicePlayer.stop()
        } else {
            guard let fileName = committed.soundFileName else { return }
            let url = alarmStore.audioFileManager.soundFileURL(named: fileName)
            voicePlayer.playFromFile(url: url, persona: committed.voicePersona)
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

                // Reconcile pro scripts against any drift (snooze count,
                // wake/leave time) introduced since the last save. Silent
                // update of `approvedScripts`. No-op for basic alarms.
                if let snapshot = lastProSnapshot, draft.alarmType == .pro {
                    let reconciler = ProScriptReconciler(composer: composerService)
                    let reconciled = try await reconciler.reconcile(from: snapshot, to: draft)
                    draft = reconciled
                    lastProSnapshot = reconciled
                }

                let newFileName = try await composerService.generateAndDownloadAudio(for: draft)
                promoteDraftToCommitted(soundFileName: newFileName)
                isRegenerating = false
                HapticManager.shared.success()
                triggerRegenSuccess()
            } catch {
                isRegenerating = false
                print("[CreateAlarmView] Regenerate failed: \(error)")
                let errorMessage = (error as? APIError)?.errorDescription
                    ?? "Please try again."
                alertManager.showModal(
                    title: "Regeneration failed",
                    message: errorMessage,
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
        cancelSkyAnimations()
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

                // Reconcile pro scripts against any step-1 drift (snooze
                // count changes, wake time changes). Silently updates
                // `approvedScripts` in place. No-op for basic alarms.
                if let snapshot = lastProSnapshot, draft.alarmType == .pro {
                    let reconciler = ProScriptReconciler(composer: composerService)
                    let reconciled = try await reconciler.reconcile(from: snapshot, to: draft)
                    draft = reconciled
                    // Refresh the snapshot so any subsequent retry uses the
                    // latest known-good baseline.
                    lastProSnapshot = reconciled
                }

                let initialFileName = try await composerService.generateAndDownloadAudio(for: draft)
                statusTask.cancel()
                statusTextVisible = false
                promoteDraftToCommitted(soundFileName: initialFileName)
                try? await Task.sleep(for: .milliseconds(300))
                generatingStatusText = "Almost ready..."
                statusTextVisible = true
                try? await Task.sleep(for: .milliseconds(600))
                transitionToPhase(.confirming)
            } catch {
                statusTask.cancel()
                statusTextVisible = false
                print("[CreateAlarmView] Composer failed: \(error)")
                generatingStatusText = ""

                let errorMessage = (error as? APIError)?.errorDescription
                    ?? "We'll investigate this issue. Please try again later."

                cancelSkyAnimations()
                alertManager.showModal(
                    title: "Something went wrong",
                    message: errorMessage,
                    primaryAction: AlertAction(label: "Continue") { [self] in
                        cancelSkyAnimations()
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
        starSpinTask?.cancel()
        starSpinTask = Task { @MainActor in
            let steps = 30
            let duration = 2.0
            let interval = duration / Double(steps)
            for i in 1...steps {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { return }
                let p = Double(i) / Double(steps)
                // Ease-out
                starSpinProgress = 1.0 - (1.0 - p) * (1.0 - p)
            }
        }
    }

    private func animateSunrise(duration: Double) {
        sunriseTask?.cancel()
        sunriseTask = Task { @MainActor in
            let steps = 60
            let interval = duration / Double(steps)
            for i in 1...steps {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { return }
                let progress = Double(i) / Double(steps)
                // Smooth ease-in-out
                sunriseProgress = progress * progress * (3.0 - 2.0 * progress)
            }
        }
    }

    private func cancelSkyAnimations() {
        sunriseTask?.cancel()
        sunriseTask = nil
        starSpinTask?.cancel()
        starSpinTask = nil
    }

    private func buildStatusMessages() -> [String] {
        var messages: [String] = []

        if let tone = draft.tone {
            messages.append(toneStatusMessage(tone))
        }
        if let why = draft.whyContext {
            messages.append(whyStatusMessage(why))
        }
        if let intensity = draft.intensity {
            messages.append(intensityStatusMessage(intensity))
        }
        if let voice = draft.voicePersona {
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
        voice.loadingMessage
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
            if confirmationProEditMode {
                // Pro editor is swapped over the confirmation card. Reuse
                // the same bottom bar the step-machine .proPrompt uses.
                proPromptBottomBar
                    .padding(.horizontal, AppButtons.horizontalPadding)
                    .premiumBlur(isVisible: confirmationCardVisible, delay: 0, duration: 0.4)
            } else {
                confirmingBottomBar
            }
        }
    }

    @ViewBuilder
    private var configuringBottomBar: some View {
        switch step {
        case .configure:
            Button {
                if isReconciling { return }
                HapticManager.shared.buttonTap()
                Task { await reconcileThenAdvanceToCustomize() }
            } label: {
                ZStack {
                    if isReconciling {
                        ProgressView().tint(.black).transition(.opacity)
                    } else {
                        Text("Next").transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isReconciling)
            }
            .primaryButton(isEnabled: !isReconciling)
            .disabled(isReconciling)
            .padding(.horizontal, AppButtons.horizontalPadding)
            .padding(.bottom, AppSpacing.screenBottom)
            .premiumBlur(isVisible: buttonVisible, delay: 0, duration: 0.4)

        case .customize:
            stepTwoBottomButton
                .padding(.horizontal, AppButtons.horizontalPadding)
                .padding(.bottom, AppSpacing.screenBottom)
                .premiumBlur(isVisible: buttonVisible, delay: 0, duration: 0.4)
        }
    }

    /// Step 2's single merged CTA. Label depends on Pro state + whether a
    /// preview exists + whether the current inputs are dirty against the
    /// snapshot that produced the preview.
    ///
    /// - Pro off: "Create Alarm" (basic path)
    /// - Pro on + no preview: "Generate Text" (kicks off `runProPreview`)
    /// - Pro on + generating: spinner
    /// - Pro on + preview exists + dirty: "Regenerate"
    /// - Pro on + preview exists + clean: "Generate Alarm" (promotes
    ///   `approvedScripts`, freezes `lastProSnapshot`, calls `startGeneration`)
    @ViewBuilder
    private var stepTwoBottomButton: some View {
        let state = stepTwoButtonState

        Button {
            guard state.enabled else { return }
            HapticManager.shared.buttonTap()
            state.action()
        } label: {
            ZStack {
                if state.showSpinner {
                    ProgressView().tint(.black).transition(.opacity)
                } else {
                    Text(state.label)
                        .contentTransition(.numericText())
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: state.showSpinner)
            .animation(.easeInOut(duration: 0.25), value: state.label)
        }
        .primaryButton(isEnabled: state.enabled)
        .disabled(!state.enabled)
    }

    private struct StepTwoButtonState {
        let label: String
        let enabled: Bool
        let showSpinner: Bool
        let action: () -> Void
    }

    private var stepTwoButtonState: StepTwoButtonState {
        let isPro = draft.alarmType == .pro
        let promptOK = !(draft.customPrompt ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasResult = !(proPreviewScripts?.isEmpty ?? true)
        let isDirty = hasResult && proPreviewSnapshot != ProPreviewInputs.from(draft)
        let basicReady = draft.tone != nil && draft.whyContext != nil && draft.intensity != nil

        if !isPro {
            return StepTwoButtonState(
                label: "Create Alarm",
                enabled: basicReady,
                showSpinner: false,
                action: { startGeneration() }
            )
        }

        if proPreviewIsGenerating {
            return StepTwoButtonState(
                label: "",
                enabled: false,
                showSpinner: true,
                action: {}
            )
        }

        if !hasResult {
            return StepTwoButtonState(
                label: "Generate Text",
                enabled: promptOK,
                showSpinner: false,
                action: { Task { await runProPreview() } }
            )
        }

        if isDirty {
            return StepTwoButtonState(
                label: "Regenerate",
                enabled: promptOK,
                showSpinner: false,
                action: { Task { await runProPreview() } }
            )
        }

        return StepTwoButtonState(
            label: "Generate Alarm",
            enabled: true,
            showSpinner: false,
            action: {
                draft.approvedScripts = proPreviewScripts
                draft.alarmType = .pro
                proSavedThisVisit = true
                lastProSnapshot = draft
                startGeneration()
            }
        )
    }

    @ViewBuilder
    private var proPromptBottomBar: some View {
        let hasResult = !(proPreviewScripts?.isEmpty ?? true)
        let promptText = draft.customPrompt ?? ""
        let canGenerate = !proPreviewIsGenerating && !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isDirty = hasResult && proPreviewSnapshot != ProPreviewInputs.from(draft)
        // If the current preview is already what's persisted on the draft
        // AND inputs haven't drifted since, there's literally nothing to
        // save — disable the button so the user just taps Back.
        let alreadyPersisted = proPreviewScripts == draft.approvedScripts
        let cleanAndPersisted = hasResult && !isDirty && alreadyPersisted
        let tappable = !proPreviewIsGenerating
            && !cleanAndPersisted
            && (isDirty || canGenerate || (hasResult && !alreadyPersisted))
        let label: String = {
            if proPreviewIsGenerating { return "" }
            if hasResult { return isDirty ? "Regenerate" : "Save" }
            return "Generate Text"
        }()

        Button {
            if !tappable { return }
            if hasResult && !isDirty && !alreadyPersisted {
                HapticManager.shared.success()
                draft.approvedScripts = proPreviewScripts
                draft.alarmType = .pro
                proSavedThisVisit = true
                // Freeze the draft so the reconciler can detect later drift.
                lastProSnapshot = draft
                if phase == .confirming {
                    // Return to the confirmation card. Do NOT regenerate
                    // audio — that's the Regenerate button's job, same as
                    // any other field change on this screen.
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        confirmationProEditMode = false
                    }
                } else {
                    transitionToStep(.customize)
                }
            } else {
                HapticManager.shared.buttonTap()
                Task { await runProPreview() }
            }
        } label: {
            ZStack {
                if proPreviewIsGenerating {
                    ProgressView()
                        .tint(.black)
                        .transition(.opacity)
                } else {
                    Text(label)
                        .contentTransition(.numericText())
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: proPreviewIsGenerating)
            .animation(.easeInOut(duration: 0.25), value: label)
        }
        .primaryButton(isEnabled: tappable)
        .disabled(!tappable)
        .padding(.top, 32)
    }

    /// True when the draft differs from the committed config in any way
    /// that affects the generated audio. Used by the Schedule Alarm button
    /// to decide whether to regenerate first. Mirrors the fields checked
    /// in EditAlarmSheetContent's hasAudioAffectingChanges.
    private var draftDiffersFromCommitted: Bool {
        draft.tone != committed.tone
            || draft.whyContext != committed.whyContext
            || draft.intensity != committed.intensity
            || draft.voicePersona != committed.voicePersona
            || draft.alarmType != committed.alarmType
            || draft.approvedScripts != committed.approvedScripts
            || draft.customPrompt != committed.customPrompt
            || draft.customPromptIncludes != committed.customPromptIncludes
            || draft.creativeSnoozes != committed.creativeSnoozes
    }

    private var scheduleButtonLabel: String {
        if isRegenerating { return "Regenerating…" }
        if draftDiffersFromCommitted { return "Regenerate & Schedule" }
        return "Schedule Alarm"
    }

    private func commitAndSchedule() {
        var configured = committed
        configured.isEnabled = true
        // Basic alarms drop any Pro-only fields left over from an
        // aborted Pro flow so they don't confuse the backend or linger
        // in persisted state.
        if configured.alarmType == .basic {
            configured.approvedScripts = nil
            configured.customPrompt = nil
            configured.customPromptIncludes = []
        }
        onCreate(configured)
        dismiss()
    }

    /// Called when the user taps Schedule but the draft has pending
    /// changes. Triggers `regenerateAlarm()` — which reconciles + re-TTSes
    /// — and then commits once `committed` reflects the new draft.
    private func scheduleAfterRegeneration() {
        regenerateAlarm()
        Task { @MainActor in
            // Wait for isRegenerating to flip false. regenerateAlarm sets
            // it on the MainActor so we can poll cheaply.
            while isRegenerating {
                try? await Task.sleep(for: .milliseconds(100))
            }
            // If committed now matches the draft, we're good. If not
            // (error path), regenerateAlarm already surfaced the alert;
            // bail silently.
            guard !draftDiffersFromCommitted else { return }
            commitAndSchedule()
        }
    }

    /// Whether the Schedule/Regen button on confirmation is tappable. If
    /// the draft is dirty it'll need to regenerate before committing, which
    /// requires the same fields step 2 checks for.
    private var canProceedFromConfirmation: Bool {
        if isRegenerating { return false }
        if draftDiffersFromCommitted { return draftIsReadyToGenerate }
        return true
    }

    private var confirmingBottomBar: some View {
        Button {
            HapticManager.shared.buttonTap()
            voicePlayer.stop()
            if draftDiffersFromCommitted {
                scheduleAfterRegeneration()
            } else {
                commitAndSchedule()
            }
        } label: {
            Text(scheduleButtonLabel)
        }
        .primaryButton(isEnabled: canProceedFromConfirmation)
        .disabled(!canProceedFromConfirmation)
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

    private func transitionToStep(_ newStep: Step) {
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

    // MARK: - Pro Prompt Helpers

    /// Snapshot of all pro-editable draft fields. Taken on entry to the
    /// Pro editor from confirmation so we can revert every change on
    /// back-without-save (mirrors the edit sheet's ProEditRestore).
    struct ProFieldsSnapshot: Equatable {
        let alarmType: AlarmType
        let approvedScripts: [String]?
        let customPrompt: String?
        let customPromptIncludes: Set<CustomPromptInclude>
        let creativeSnoozes: Bool
        let previewScripts: [String]?
        let previewSnapshot: ProPreviewInputs?
    }

    private func captureConfirmationProRestore() {
        confirmationProRestore = ProFieldsSnapshot(
            alarmType: draft.alarmType,
            approvedScripts: draft.approvedScripts,
            customPrompt: draft.customPrompt,
            customPromptIncludes: draft.customPromptIncludes,
            creativeSnoozes: draft.creativeSnoozes,
            previewScripts: proPreviewScripts,
            previewSnapshot: proPreviewSnapshot
        )
    }

    /// Tapping the Pro row (not the toggle). In the confirmation phase this
    /// still swaps the confirmation card for the full-screen Pro editor —
    /// confirmation was intentionally left on the old surface while step 2
    /// is piloted with inline Pro rows. In the configuring phase there's
    /// nowhere to navigate; the inline rows are already visible.
    private func handleTapProRow() {
        if phase == .confirming {
            captureConfirmationProRestore()
            proSavedThisVisit = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                confirmationProEditMode = true
            }
        }
    }

    /// Toggling Pro on via the switch, confirmation-phase only. Swaps the
    /// confirmation card for the full-screen Pro editor. Step 2 uses
    /// `flipPro(to:)` via `CustomizeCard.onFlipPro` instead.
    private func handleFlipProOn() {
        guard phase == .confirming else { return }
        captureConfirmationProRestore()
        proSavedThisVisit = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            confirmationProEditMode = true
        }
    }

    /// Coordinated Pro on/off transition for step 2. Uses the same
    /// `cardsVisible` → `premiumBlur` envelope that drives the initial
    /// mount: blur everything out, wait for the blur-out to complete,
    /// mutate the model and the expanded row with animations suppressed
    /// (so the card reshapes instantly behind a fully-invisible screen),
    /// then blur everything back in with the new layout.
    ///
    /// Timings match `premiumBlur`'s default ~0.4s envelope.
    private func flipPro(to newValue: Bool) {
        guard !proTransitioning else { return }
        guard phase == .configuring else {
            // Confirmation phase still uses the full-screen editor; let its
            // handler take over.
            if newValue {
                captureConfirmationProRestore()
                proSavedThisVisit = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    confirmationProEditMode = true
                }
            }
            return
        }

        proTransitioning = true

        // Step 1: blur everything out via the existing envelope.
        cardsVisible = false

        Task { @MainActor in
            // Step 2: wait for the blur-out to fully complete. premiumBlur's
            // default duration is ~0.4s; add a small buffer to be safe.
            try? await Task.sleep(for: .milliseconds(450))

            // Step 3: reshape the card with ALL implicit animations
            // disabled, so the Toggle thumb, inline-row insert/remove, and
            // any downstream onChange handlers pop instantly behind the
            // invisible blur envelope instead of animating through it.
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                draft.alarmType = newValue ? .pro : .basic
            }

            // Step 4: one layout tick so SwiftUI finishes sizing the new
            // card height before we start the blur-in.
            try? await Task.sleep(for: .milliseconds(60))

            // Step 5: blur everything back in with the new layout.
            cardsVisible = true
            proTransitioning = false
        }
    }

    private func handleProPromptInputChange() {
        // Intentionally a no-op. Editing inputs does not wipe the generated
        // preview — the CTA label swaps to "Regenerate" when the inputs
        // diverge from what produced the current result (see
        // proPreviewIsDirty). The user has to explicitly regenerate to
        // replace the text.
    }

    /// Snooze count the Pro preview should request.
    ///
    /// - Creative snoozes off → 0 (compose-alarm will reuse the main audio
    ///   file for every snooze fire, no extra scripts needed).
    /// - Unlimited snooze → 1 (a single loop snooze that plays forever).
    /// - Limited → `maxSnoozes`.
    private var proPreviewSnoozeCount: Int {
        guard draft.creativeSnoozes else { return 0 }
        return draft.unlimitedSnooze ? 1 : draft.maxSnoozes
    }

    /// Tapping Next from step 1. If the user previously saved a Pro preview,
    /// reconcile approvedScripts against any step-1 changes (snoozes, wake
    /// time, leave time) BEFORE transitioning to step 2. This way the Pro
    /// screen — if they re-enter it — already shows fresh text instead of
    /// stale text referencing the old time.
    ///
    /// Logs before/after scripts so you can eyeball what changed without
    /// generating TTS audio.
    private func reconcileThenAdvanceToCustomize() async {
        // No snapshot means no Pro save has happened yet — skip reconcile.
        guard let snapshot = lastProSnapshot, draft.alarmType == .pro else {
            transitionToStep(.customize)
            return
        }
        guard let composerService else {
            transitionToStep(.customize)
            return
        }

        isReconciling = true

        let beforeScripts = draft.approvedScripts ?? []
        print("[reconcile] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("[reconcile] Triggered from step1→step2 Next")
        print("[reconcile] Snapshot → wake=\(snapshot.wakeTime?.description ?? "nil") leave=\(snapshot.leaveTime?.description ?? "nil") maxSnoozes=\(snapshot.maxSnoozes) unlimited=\(snapshot.unlimitedSnooze) creative=\(snapshot.creativeSnoozes)")
        print("[reconcile] Current  → wake=\(draft.wakeTime?.description ?? "nil") leave=\(draft.leaveTime?.description ?? "nil") maxSnoozes=\(draft.maxSnoozes) unlimited=\(draft.unlimitedSnooze) creative=\(draft.creativeSnoozes)")
        print("[reconcile] BEFORE scripts (count=\(beforeScripts.count)):")
        for (i, s) in beforeScripts.enumerated() {
            print("[reconcile]   [\(i)] \(s)")
        }

        let reconciler = ProScriptReconciler(composer: composerService)
        do {
            let reconciled = try await reconciler.reconcile(from: snapshot, to: draft)
            draft = reconciled
            lastProSnapshot = reconciled
            // Keep the Pro screen's scratchpad in sync so if the user re-enters
            // the Pro screen via the row, they see the updated text.
            proPreviewScripts = reconciled.approvedScripts

            let afterScripts = reconciled.approvedScripts ?? []
            print("[reconcile] AFTER scripts (count=\(afterScripts.count)):")
            for (i, s) in afterScripts.enumerated() {
                print("[reconcile]   [\(i)] \(s)")
            }
            print("[reconcile] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        } catch {
            print("[reconcile] FAILED: \(error). Proceeding with stale scripts.")
        }

        isReconciling = false
        transitionToStep(.customize)
    }

    private func runProPreview() async {
        let promptText = draft.customPrompt ?? ""
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !proPreviewIsGenerating else { return }
        guard let composerService else {
            proPreviewError = "Composer service unavailable."
            HapticManager.shared.error()
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            proPreviewIsGenerating = true
            proPreviewError = nil
            proPreviewScripts = nil
        }

        do {
            let scripts = try await composerService.generateCustomAlarmText(
                draft: draft,
                prompt: promptText,
                includes: draft.customPromptIncludes,
                snoozeCount: proPreviewSnoozeCount,
                baseScript: nil
            )
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                proPreviewScripts = scripts
                proPreviewSnapshot = ProPreviewInputs.from(draft)
                proPreviewIsGenerating = false
            }
            HapticManager.shared.softTap()
        } catch {
            let description = (error as? APIError)?.errorDescription ?? "Please try again."
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                proPreviewError = description
                proPreviewIsGenerating = false
            }
            HapticManager.shared.error()
        }
    }

    // MARK: - Phase

    enum Phase: Equatable {
        case configuring
        case generating
        case confirming
    }

    enum Step: Equatable {
        case configure
        case customize

        init(legacy: Int) {
            switch legacy {
            case 1:  self = .configure
            case 2:  self = .customize
            default: self = .configure
            }
        }
    }

    // MARK: - Hero Voice Data

    private var heroVoices: [HeroVoice] { VoiceCatalog.all }

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
