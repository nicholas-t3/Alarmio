//
//  OnboardingContainerView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import AlarmKit
import SwiftUI
import UIKit

enum OnboardingPhase {
    case splash
    case steps
}

enum OnboardingStep: Int, CaseIterable {
    case intro = 0
    case tone
    case why
    case intensity
    case difficulty
    case voice
    case time
    case snooze
    case permission
    case generating
    case confirmation
}

struct OnboardingContainerView: View {

    // MARK: - State

    @Environment(\.previewStep) private var previewStep
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @Environment(\.composerService) private var composerService
    @Environment(\.alarmStore) private var alarmStore
    @Environment(\.alertManager) private var alertManager
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.proLimitCounter) private var proLimitCounter
    @State private var manager = OnboardingManager()
    @State private var deviceInfo = DeviceInfo()
    @State private var splashVisible = true
    @State private var contentVisible = true
    @State private var buttonVisible = false
    @State private var backVisible = false
    @State private var buttonLabel = "Get Started"
    @State private var isTransitioning = false
    @State private var customBackground: [Color]? = nil
    @State private var starOpacity: Double = 1.0
    @State private var voiceVisualizerPalette: VisualizerPalette = .blue
    @State private var voiceVisualizerPlaying = false
    @State private var voiceVisualizerVisible = false
    @State private var sunriseProgress: Double = 0
    @State private var starSpinProgress: Double = 0
    /// Status text rotated through the generating phase. Driven by the
    /// container while the Composer call is in flight — leaf view just
    /// renders it. Mirrors CreateAlarmView.generatingStatusText.
    @State private var generatingStatusText = ""
    @State private var generatingStatusVisible = false
    @State private var sunriseTask: Task<Void, Never>?
    @State private var starSpinTask: Task<Void, Never>?
    @State private var statusCycleTask: Task<Void, Never>?
    @State private var isScheduling = false
    /// Regeneration state for the onboarding confirmation screen. When
    /// the user cycles voice (or otherwise drifts from the committed
    /// snapshot), the bottom button flips to "Regenerate". After a
    /// successful re-run we bump `regenerationNonce` so the confirmation
    /// view knows to pulse its Play button.
    @State private var isRegeneratingAudio = false
    @State private var regenerationNonce: Int = 0
    /// Cached AlarmKit authorization state. Refreshed on entry to the
    /// permission step, after requestAuthorization returns, and whenever
    /// the scene returns to active (handles the Settings round-trip).
    @State private var authorizationState: AlarmManager.AuthorizationState = .notDetermined
    @State private var isRequestingPermission = false
    @State private var showPaywall = false
    /// Action to re-fire if the user subscribes inside the paywall sheet.
    @State private var pendingActionAfterPaywall: (() -> Void)?
    /// Action to fire when the paywall dismisses for ANY reason (subscribe
    /// OR close). Used by the final Schedule Alarm step — we show the
    /// paywall as a last conversion nudge but never block scheduling.
    @State private var pendingUnconditionalAfterPaywall: (() -> Void)?

    // MARK: - Body

    var body: some View {
        ZStack {

            // Shared night sky background — gradient is unaffected, only stars dim
            // Sunrise intensifies during generating step
            MorningSky(starOpacity: starOpacity, sunriseProgress: sunriseProgress, starSpinProgress: starSpinProgress)

            // Dynamic voice background (covers starfield when active)
            if let colors = customBackground {
                ZStack {
                    Color(hex: "020810")

                    LinearGradient(
                        stops: [
                            .init(color: colors[0].opacity(0.5), location: 0.2),
                            .init(color: colors[1].opacity(0.4), location: 0.5),
                            .init(color: colors[2].opacity(0.3), location: 0.8),
                            .init(color: Color(hex: "020810"), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.6), value: colors.map { $0.description })
            }

            // Voice visualizer background — always in hierarchy, faded via opacity
            VoiceVisualizer(palette: voiceVisualizerPalette, isPlaying: voiceVisualizerPlaying)
                .overlay(alignment: .top) {
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "020810"), location: 0),
                            .init(color: Color(hex: "020810").opacity(0.8), location: 0.4),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 180)
                    .allowsHitTesting(false)
                }
                .opacity(voiceVisualizerVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.5), value: voiceVisualizerVisible)
                .allowsHitTesting(false)

            // Current phase
            switch manager.phase {
            case .splash:
                SplashContentView(onFinished: {
                    transitionToSteps()
                })
                .premiumBlur(isVisible: splashVisible, duration: 0.5)

            case .steps:
                VStack(spacing: 0) {

                    // Nav bar
                    HStack {
                        Button {
                            goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .opacity(backVisible ? 1 : 0)
                        .blur(radius: backVisible ? 0 : 8)
                        .animation(.easeOut(duration: 0.3), value: backVisible)
                        .disabled(!backVisible)

                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal - 8)
                    .frame(height: 44)

                    // Step content — blur controlled for exit, each step handles entry
                    stepContent
                        .frame(maxHeight: .infinity)
                        .opacity(contentVisible ? 1 : 0)
                        .blur(radius: contentVisible ? 0 : 10)
                        .animation(.easeOut(duration: 0.3), value: contentVisible)

                    // Bottom bar
                    bottomBar
                }
            }
        }
        .environment(manager)
        .environment(\.deviceInfo, deviceInfo)
        .sheet(isPresented: $showPaywall, onDismiss: {
            let gatedAction = pendingActionAfterPaywall
            let unconditional = pendingUnconditionalAfterPaywall
            pendingActionAfterPaywall = nil
            pendingUnconditionalAfterPaywall = nil
            if subscriptionService.isPro, let gatedAction {
                gatedAction()
            }
            unconditional?()
        }) {
            PaywallSheet()
        }
        // Pick up auth changes on return from Settings. If the user
        // granted permission over there, push them forward immediately.
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            let wasAuthorized = authorizationState == .authorized
            refreshAuthorizationState()
            if manager.currentStep == .permission,
               !wasAuthorized,
               authorizationState == .authorized {
                advanceFromPermissionToGenerating()
            }
        }
        .task {
            refreshAuthorizationState()
            await manager.startOnboarding()

            // DEV: Skip to a specific step on launch. Comment out for production.
            // let devStartStep: OnboardingStep? = .snooze
            let devStartStep: OnboardingStep? = nil

            if let step = devStartStep ?? previewStep {
                manager.phase = .steps
                manager.currentStep = step
                contentVisible = true
                backVisible = manager.canGoBack

                // Set up backgrounds/opacity for specific steps in preview
                starOpacity = starOpacityForStep(step)
                if step == .generating {
                    sunriseProgress = 0
                    // Seed example selections so personalized messages appear
                    manager.configuration.tone = .fun
                    manager.configuration.whyContext = .gym
                    manager.configuration.intensity = .intense
                    manager.configuration.voicePersona = .drillSergeant
                    startGeneration()
                }
                if step == .voice {
                    voiceVisualizerPalette = .blue
                    voiceVisualizerVisible = true
                }
                if step == .confirmation {
                    buttonLabel = "Schedule Alarm"
                    // Dev seed so the confirmation cards render with real data
                    // even when jumped into directly from a preview.
                    manager.configuration.tone = .fun
                    manager.configuration.whyContext = .gym
                    manager.configuration.intensity = .balanced
                    manager.configuration.voicePersona = .soothingSarah
                    manager.configuration.wakeTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0))
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        buttonVisible = true
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var stepContent: some View {
        switch manager.currentStep {
        case .intro:
            OnboardingIntroView(onTitleComplete: {
                showButton()
            })

        case .tone:
            OnboardingToneView(onReadyForButton: { showButton() })

        case .why:
            OnboardingWhyView(onReadyForButton: { showButton() })

        case .intensity:
            OnboardingIntensityView(onReadyForButton: { showButton() })

        case .difficulty:
            OnboardingDifficultyView(onReadyForButton: { showButton() })

        case .voice:
            OnboardingVoiceView(
                onReadyForButton: { showButton() },
                onPaletteChange: { palette in
                    voiceVisualizerPalette = palette
                },
                onPlayingChange: { playing in
                    voiceVisualizerPlaying = playing
                }
            )

        case .time:
            OnboardingTimeView(onReadyForButton: { showButton() })

        case .snooze:
            OnboardingSnoozeView(onReadyForButton: { showButton() })

        case .permission:
            OnboardingPermissionView(authorizationState: authorizationState)

        case .generating:
            OnboardingGeneratingView(statusText: generatingStatusText, isVisible: generatingStatusVisible)

        case .confirmation:
            OnboardingConfirmationView(
                onSchedule: { scheduleAlarm() },
                isScheduling: isScheduling,
                isRegenerating: isRegeneratingAudio,
                regenerationNonce: regenerationNonce
            )
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {

            // Continue / Get Started / permission button — label and
            // action swap per-step so the permission screen can show
            // "Allow Alarms" or "Open Settings" without needing its own
            // bottom bar.
            Button {
                guard !isTransitioning else { return }
                handleBottomButtonTap()
            } label: {
                if manager.isSyncing || isRequestingPermission || isRegeneratingAudio {
                    ProgressView()
                        .tint(.black)
                } else {
                    HStack(spacing: 8) {
                        Text(resolvedButtonLabel)
                            .contentTransition(.numericText())
                        if showsScheduleArrow {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .transition(.opacity)
                        }
                    }
                }
            }
            .primaryButton(isEnabled: isBottomButtonEnabled)
            .disabled(!isBottomButtonEnabled)
            .padding(.horizontal, AppButtons.horizontalPadding)
            .opacity(buttonVisible ? 1 : 0)
            .blur(radius: buttonVisible ? 0 : 8)
            .animation(.easeOut(duration: 0.35), value: buttonVisible)
            // Dev: 3-second hold on the intro's Get Started button skips
            // onboarding entirely. Intentionally long so a normal tap can
            // never trigger it. Blurs onboarding out before flipping the
            // flag so RootView's .premiumBlur transition has something to
            // cross-dissolve against.
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 3.0)
                    .onEnded { _ in
                        guard manager.currentStep == .intro, !isTransitioning else { return }
                        devSkipOnboarding()
                    }
            )
        }
        .padding(.bottom, AppSpacing.screenBottom)
    }

    // MARK: - Private Methods

    private func showButton() {
        buttonVisible = true
    }

    private func starOpacityForStep(_ step: OnboardingStep) -> Double {
        switch step {
        case .intro: return 1.0
        case .confirmation: return 0.35
        default: return 0.5
        }
    }

    // MARK: - Bottom Button Routing

    /// Label for the shared primary button, resolved against the current
    /// step and (on permission) the auth state. `buttonLabel` is the
    /// legacy "Continue"/"Get Started"/"Schedule Alarm" driver — this
    /// layers the permission-specific copy on top without disturbing it.
    private var resolvedButtonLabel: String {
        if manager.currentStep == .permission {
            switch authorizationState {
            case .notDetermined: return "Allow Alarms"
            case .denied:        return "Open Settings"
            case .authorized:    return "Continue"
            @unknown default:    return "Allow Alarms"
            }
        }
        if manager.currentStep == .confirmation {
            if isRegeneratingAudio { return "Regenerating…" }
            if isConfirmationDirty { return "Regenerate" }
        }
        return buttonLabel
    }

    /// True when the confirmation screen has drift against the audio that
    /// was generated — typically from cycling voice. Flips the bottom
    /// button to "Regenerate" until re-run.
    private var isConfirmationDirty: Bool {
        guard let committed = manager.committedConfiguration else { return false }
        return manager.configuration != committed
    }

    /// Show the up-right arrow next to the button label only when the
    /// user is about to schedule (matches AlarmReadyView's affordance).
    /// Hidden during Regenerate / Regenerating… on the confirmation step
    /// and for all other steps (Continue / Get Started / etc.).
    private var showsScheduleArrow: Bool {
        guard manager.currentStep == .confirmation else { return false }
        if isRegeneratingAudio { return false }
        return !isConfirmationDirty
    }

    /// Enabled state for the shared primary button. Permission step is
    /// always tappable (request / settings / advance all valid); other
    /// steps defer to the manager's `canContinue` gate.
    private var isBottomButtonEnabled: Bool {
        if isTransitioning { return false }
        if isRequestingPermission { return false }
        if isRegeneratingAudio { return false }
        if manager.currentStep == .permission { return true }
        return manager.canContinue && !manager.isSyncing
    }

    /// Dispatches the button tap. Permission step branches three ways;
    /// every other step falls through to `navigateForward()`.
    private func handleBottomButtonTap() {
        if manager.currentStep == .permission {
            switch authorizationState {
            case .notDetermined: requestAlarmAuthorization()
            case .denied:        openAppSettings()
            case .authorized:    navigateForward()
            @unknown default:    requestAlarmAuthorization()
            }
            return
        }
        if manager.currentStep == .confirmation, isConfirmationDirty {
            regenerateConfirmationAlarm()
            return
        }
        navigateForward()
    }

    /// Re-runs the Composer audio call with the current (dirty) manager
    /// configuration and promotes it into `committedConfiguration`.
    /// Bumps `regenerationNonce` so the confirmation view pulses its
    /// alarm-preview Play button.
    private func regenerateConfirmationAlarm() {
        guard !isRegeneratingAudio else { return }

        // Free users capped at 10 onboarding generations. Paywall up if
        // exhausted; re-fire on subscribe.
        if !proLimitCounter.canUseOnboarding(isPro: subscriptionService.isPro) {
            pendingActionAfterPaywall = { regenerateConfirmationAlarm() }
            showPaywall = true
            return
        }

        isRegeneratingAudio = true
        HapticManager.shared.buttonTap()

        Task { @MainActor in
            do {
                guard let composerService else {
                    throw NSError(
                        domain: "ComposerService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Composer service unavailable"]
                    )
                }
                let newFileName = try await composerService.generateAndDownloadAudio(
                    for: manager.configuration
                )
                if !subscriptionService.isPro {
                    proLimitCounter.incrementOnboarding()
                }
                manager.configuration.soundFileName = newFileName
                manager.committedConfiguration = manager.configuration
                regenerationNonce &+= 1
                isRegeneratingAudio = false
                HapticManager.shared.success()
            } catch {
                isRegeneratingAudio = false
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

    // MARK: - Authorization

    /// Pulls the latest AlarmKit auth state into local `@State`. Called on
    /// entering the permission step, after `requestAuthorization` returns,
    /// and every time the scene returns to `.active` (so return-from-
    /// Settings is picked up).
    private func refreshAuthorizationState() {
        authorizationState = AlarmManager.shared.authorizationState
        manager.alarmPermissionGranted = authorizationState == .authorized
        manager.alarmPermissionDenied = authorizationState == .denied
    }

    private func requestAlarmAuthorization() {
        guard !isRequestingPermission else { return }
        HapticManager.shared.buttonTap()
        isRequestingPermission = true

        Task { @MainActor in
            _ = await alarmStore.scheduler.requestAuthorization()
            refreshAuthorizationState()
            isRequestingPermission = false

            // If granted, blur out and jump straight to generating — no
            // need to make the user tap Continue a second time.
            if authorizationState == .authorized {
                advanceFromPermissionToGenerating()
            }
        }
    }

    private func openAppSettings() {
        HapticManager.shared.buttonTap()
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// Called when the user returns to the app with auth granted, or right
    /// after the system prompt grants it. Mirrors navigateForward's blur
    /// sequence but always targets `.generating`.
    private func advanceFromPermissionToGenerating() {
        guard manager.currentStep == .permission, !isTransitioning else { return }
        isTransitioning = true
        contentVisible = false
        buttonVisible = false
        backVisible = false

        Task {
            try? await Task.sleep(for: .milliseconds(400))
            manager.currentStep = .generating
            sunriseProgress = 0
            starSpinProgress = 0
            withAnimation(.easeInOut(duration: 0.5)) {
                starOpacity = starOpacityForStep(.generating)
            }
            contentVisible = true
            backVisible = false
            buttonVisible = false
            isTransitioning = false
            startGeneration()
        }
    }

    /// Dev-only: skip directly to HomeView from the intro. Triggered by a
    /// 3-second long-press on the Get Started button. Follows the standard
    /// blur-out → flip-flag sequence so RootView's .premiumBlur transition
    /// has something to cross-dissolve against.
    private func devSkipOnboarding() {
        isTransitioning = true
        HapticManager.shared.success()

        contentVisible = false
        buttonVisible = false
        backVisible = false
        voiceVisualizerVisible = false

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            appState.completeOnboarding()
        }
    }

    private func transitionToHome() {
        isTransitioning = true
        HapticManager.shared.success()

        // Blur out everything
        contentVisible = false
        buttonVisible = false
        backVisible = false

        Task {
            // Hold onboarding on screen during its own blur-out, then flip
            // the persisted flag. RootView's @AppStorage observes the key
            // and swaps to HomeView with a .premiumBlur transition.
            try? await Task.sleep(for: .milliseconds(500))
            appState.completeOnboarding()
        }
    }

    private func transitionToSteps() {
        HapticManager.shared.softTap()
        splashVisible = false

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            manager.phase = .steps
            buttonLabel = "Get Started"
            contentVisible = true
        }
    }

    private func navigateForward() {
        // On confirmation step, commit the alarm and transition home.
        if manager.currentStep == .confirmation {
            scheduleAlarm()
            return
        }

        isTransitioning = true

        // Blur out content + button + back + backgrounds
        contentVisible = false
        buttonVisible = false
        backVisible = false
        voiceVisualizerVisible = false
        withAnimation(.easeOut(duration: 0.4)) {
            customBackground = nil
        }

        Task {
            // Wait for blur-out
            try? await Task.sleep(for: .milliseconds(400))

            // Advance step (synchronous)
            manager.advanceToNextStep()
            buttonLabel = "Continue"

            // Skip the permission step entirely when AlarmKit has already
            // granted authorization — no point making the user re-confirm.
            if manager.currentStep == .permission {
                refreshAuthorizationState()
                if authorizationState == .authorized {
                    manager.currentStep = .generating
                }
            }

            // Star opacity per step
            withAnimation(.easeInOut(duration: 0.5)) {
                starOpacity = starOpacityForStep(manager.currentStep)
            }

            // Show/hide special backgrounds
            voiceVisualizerVisible = manager.currentStep == .voice

            // Reset sunrise + star spin if entering generating step — the
            // container drives both from here.
            if manager.currentStep == .generating {
                sunriseProgress = 0
                starSpinProgress = 0
                startGeneration()
            }

            // Show content — the new step's .task handles its own staggered entry
            contentVisible = true

            // Hide back/button on generating and confirmation. Permission
            // step auto-shows its button (it drives Allow / Open Settings
            // rather than waiting for a child view's readiness signal).
            let isAutoStep = manager.currentStep == .generating || manager.currentStep == .confirmation
            backVisible = !isAutoStep && manager.canGoBack
            if isAutoStep {
                buttonVisible = false
            }
            if manager.currentStep == .permission {
                buttonVisible = true
            }

            isTransitioning = false
        }
    }

    /// Kick off the real Composer call. Mirrors CreateAlarmView.startGeneration.
    /// Runs the sky animation + status cycle while awaiting the audio file,
    /// then routes to the paywall (non-pro) or straight to confirmation (pro).
    /// On failure surfaces an alert and falls back to the snooze step.
    private func startGeneration() {
        // Cancel any prior run (dev re-entry, back-and-forth, etc.)
        sunriseTask?.cancel()
        starSpinTask?.cancel()
        statusCycleTask?.cancel()

        // Free users capped at 10 onboarding generations. If exhausted,
        // show the paywall and bounce the user back to the snooze step so
        // they can resume from a safe place. If they subscribe inside the
        // paywall, re-fire startGeneration automatically.
        if !proLimitCounter.canUseOnboarding(isPro: subscriptionService.isPro) {
            pendingActionAfterPaywall = { startGeneration() }
            manager.currentStep = .snooze
            // Restore the snooze step chrome — navigateForward hid the
            // Continue button before we routed here, and nothing else will
            // bring it back if the user dismisses the paywall without
            // subscribing.
            contentVisible = true
            backVisible = manager.canGoBack
            buttonVisible = true
            buttonLabel = "Continue"
            showPaywall = true
            return
        }

        animateSunrise(duration: 8.0)
        animateStarSpin()

        // Cycle personalized status text with blur-in / blur-out.
        let messages = buildStatusMessages()
        statusCycleTask = Task { @MainActor in
            var i = 0
            while !Task.isCancelled {
                generatingStatusText = messages[i % messages.count]
                generatingStatusVisible = true
                try? await Task.sleep(for: .seconds(2.0))
                guard !Task.isCancelled else { break }
                generatingStatusVisible = false
                try? await Task.sleep(for: .milliseconds(400))
                i += 1
            }
        }

        Task { @MainActor in
            do {
                guard let composerService else {
                    throw NSError(
                        domain: "ComposerService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Composer service unavailable"]
                    )
                }

                let fileName = try await composerService.generateAndDownloadAudio(
                    for: manager.configuration
                )
                if !subscriptionService.isPro {
                    proLimitCounter.incrementOnboarding()
                }
                manager.configuration.soundFileName = fileName
                // Freeze the committed snapshot so the confirmation screen
                // can compare against it to detect dirty state.
                manager.committedConfiguration = manager.configuration

                statusCycleTask?.cancel()
                generatingStatusVisible = false
                try? await Task.sleep(for: .milliseconds(300))
                generatingStatusText = "Almost ready..."
                generatingStatusVisible = true
                try? await Task.sleep(for: .milliseconds(600))

                advanceToConfirmation()
            } catch {
                statusCycleTask?.cancel()
                generatingStatusVisible = false
                print("[OnboardingContainerView] Composer failed: \(error)")

                let errorMessage = (error as? APIError)?.errorDescription
                    ?? "We'll investigate this issue. Please try again later."

                cancelSkyAnimations()
                alertManager.showModal(
                    title: "Something went wrong",
                    message: errorMessage,
                    primaryAction: AlertAction(label: "Try Again") { [self] in
                        // Drop the user back on the snooze step and let them
                        // hit Continue again to retry.
                        withAnimation(.easeOut(duration: 0.6)) {
                            sunriseProgress = 0
                            starSpinProgress = 0
                        }
                        manager.currentStep = .snooze
                        contentVisible = true
                        backVisible = manager.canGoBack
                        buttonVisible = true
                        buttonLabel = "Continue"
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
        // Always lead with the generic "Creating your alarm" message so the
        // user sees a clear framing beat before the personalized lines start
        // rolling. The rest cycle per their configuration choices.
        var messages: [String] = ["Creating your alarm"]
        let config = manager.configuration

        if let tone = config.tone {
            messages.append(toneStatusMessage(tone))
        }
        if let why = config.whyContext {
            messages.append(whyStatusMessage(why))
        }
        if let intensity = config.intensity {
            messages.append(intensityStatusMessage(intensity))
        }
        if let voice = config.voicePersona {
            messages.append(voiceStatusMessage(voice))
        }
        messages.append("Writing your wake-up call")

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

    /// Persist the configured alarm and finish onboarding. Runs when the
    /// user taps Schedule Alarm on the confirmation screen.
    ///
    /// Sequence: blur-out onboarding content → persist alarm → flip the
    /// completion flag (RootView reacts with a .premiumBlur transition
    /// into HomeView, which blurs in). Never snap.
    private func scheduleAlarm() {
        guard !isScheduling else { return }

        // Last-chance paywall nudge. If the user is already Pro we skip it;
        // otherwise we show the paywall and continue scheduling when it
        // dismisses — whether they subscribed or closed it.
        if !subscriptionService.isPro {
            pendingUnconditionalAfterPaywall = { performScheduleAlarm() }
            showPaywall = true
            return
        }

        performScheduleAlarm()
    }

    private func performScheduleAlarm() {
        guard !isScheduling else { return }
        isScheduling = true
        HapticManager.shared.success()

        var config = manager.configuration
        config.isEnabled = true
        // Onboarding never uses Pro — strip any lingering fields so nothing
        // stale gets persisted.
        config.alarmType = .basic
        config.approvedScripts = nil
        config.customPrompt = nil
        config.customPromptIncludes = []

        // Blur out every layer of onboarding first so the user sees a
        // proper exit animation before HomeView blurs in.
        contentVisible = false
        buttonVisible = false
        backVisible = false
        voiceVisualizerVisible = false

        Task { @MainActor in
            // Persist in parallel with the blur-out so scheduling latency
            // doesn't show up as a delay between gestures and animation.
            async let persist: Void = alarmStore.addAlarm(config)

            // Let the premium blur-out run to completion before swapping
            // the root view. 500ms matches transitionToHome's original
            // timing and the premium profile's duration.
            try? await Task.sleep(for: .milliseconds(500))
            _ = await persist

            isScheduling = false
            appState.completeOnboarding()
        }
    }

    private func advanceToConfirmation() {
        isTransitioning = true
        contentVisible = false

        Task {
            try? await Task.sleep(for: .milliseconds(500))

            // Set step directly — bypass canContinue which returns false for .generating
            manager.currentStep = .confirmation
            buttonLabel = "Schedule Alarm"

            // Fade sunrise and star spin back down for confirmation screen
            withAnimation(.easeOut(duration: 1.0)) {
                sunriseProgress = 0
                starSpinProgress = 0
            }

            // Dim stars heavily for confirmation screen
            withAnimation(.easeInOut(duration: 0.5)) {
                starOpacity = 0.2
            }

            contentVisible = true
            backVisible = true

            isTransitioning = false

            // Show the Schedule Alarm button after the hero + card sequence (~3s)
            try? await Task.sleep(for: .seconds(3))
            buttonVisible = true
        }
    }

    private func goBack() {
        guard !isTransitioning else { return }
        isTransitioning = true

        // Blur out content + button + back + custom background
        contentVisible = false
        buttonVisible = false
        backVisible = false
        voiceVisualizerVisible = false
        withAnimation(.easeOut(duration: 0.4)) {
            customBackground = nil
        }

        Task {
            // Wait for blur-out
            try? await Task.sleep(for: .milliseconds(400))

            // Go back — skip .generating (not user-navigable) and .permission
            // (auto-handled; if the user is authorized it'd be weird to land
            // them there on a back tap).
            manager.goBack()
            if manager.currentStep == .generating {
                manager.goBack()
            }
            if manager.currentStep == .permission, authorizationState == .authorized {
                manager.goBack()
            }
            buttonLabel = manager.currentStep == .intro ? "Get Started" : "Continue"

            // Restore star opacity for the new step
            withAnimation(.easeInOut(duration: 0.5)) {
                starOpacity = starOpacityForStep(manager.currentStep)
            }

            // Show/hide special backgrounds
            voiceVisualizerVisible = manager.currentStep == .voice

            // Reset sunrise + star spin when navigating away
            withAnimation(.easeOut(duration: 0.3)) {
                sunriseProgress = 0
                starSpinProgress = 0
            }

            // Show content
            contentVisible = true
            backVisible = manager.canGoBack

            isTransitioning = false
        }
    }
}

// MARK: - Preview Helper

struct OnboardingStepPreview: View {
    let step: OnboardingStep

    var body: some View {
        OnboardingContainerView()
            .onAppear {
                // Handled via the startStep environment key
            }
    }
}

extension OnboardingContainerView {
    @MainActor
    static func preview(step: OnboardingStep) -> some View {
        OnboardingContainerView()
            .environment(\.previewStep, step)
            .environment(AppState())
    }
}

private struct PreviewStepKey: EnvironmentKey {
    static let defaultValue: OnboardingStep? = nil
}

extension EnvironmentValues {
    var previewStep: OnboardingStep? {
        get { self[PreviewStepKey.self] }
        set { self[PreviewStepKey.self] = newValue }
    }
}

#Preview {
    OnboardingContainerView()
        .environment(AppState())
}
