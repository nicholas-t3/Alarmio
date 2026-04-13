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
        WakeTimeCard(wakeTime: Binding(
            get: { alarm.wakeTime ?? Date() },
            set: { alarm.wakeTime = $0 }
        ))
    }

    private var scheduleCard: some View {
        RepeatCard(selectedDays: $selectedDays)
            .onChange(of: selectedDays) { _, newDays in
                alarm.repeatDays = newDays.isEmpty ? nil : Array(newDays).sorted()
            }
    }

    private var snoozeCard: some View {
        SnoozeCard(
            maxSnoozes: $alarm.maxSnoozes,
            snoozeInterval: $alarm.snoozeInterval,
            unlimitedSnooze: $alarm.unlimitedSnooze,
            allowUnlimited: true
        )
    }

    // MARK: - Step 2: Style

    private var stepTwo: some View {
        ScrollView {
            VStack(spacing: AppSpacing.itemGap(deviceInfo.spacingScale)) {

                // Voice (hero)
                voiceHeroCard
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .premiumBlur(isVisible: cardsVisible, delay: 0, duration: 0.4)

                // Customize (tone + reason + intensity + leave time)
                CustomizeCard(
                    tone: $alarm.tone,
                    whyContext: $alarm.whyContext,
                    intensity: $alarm.intensity,
                    leaveTime: $alarm.leaveTime,
                    wakeTime: alarm.wakeTime,
                    showLeaveTime: true
                )
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
                print("[CreateAlarmView] Composer failed: \(error)")
                generatingStatusText = ""

                let errorMessage = (error as? APIError)?.errorDescription
                    ?? "We'll investigate this issue. Please try again later."

                alertManager.showModal(
                    title: "Something went wrong",
                    message: errorMessage,
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
