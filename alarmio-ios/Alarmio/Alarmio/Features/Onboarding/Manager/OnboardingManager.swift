//
//  OnboardingManager.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

@Observable
@MainActor
final class OnboardingManager {

    // MARK: - State

    var currentStep: OnboardingStep = .intro
    var phase: OnboardingPhase = .splash
    var configuration = AlarmConfiguration()
    var isCompleted = false
    var isSyncing = false
    var syncError: String?
    var alarmPermissionGranted = false
    var alarmPermissionDenied = false

    var canContinue: Bool {
        guard !isSyncing else { return false }
        switch currentStep {
        case .intro: return true
        case .tone: return configuration.tone != nil
        case .why: return configuration.whyContext != nil
        case .intensity: return configuration.intensity != nil
        case .difficulty: return configuration.difficulty != nil
        case .voice: return configuration.voicePersona != nil
        case .time: return configuration.wakeTime != nil
        case .snooze: return true
        // case .permission: return alarmPermissionGranted
        case .generating: return false
        case .confirmation: return true
        }
    }

    /// Steps that show a continue button (not intro)
    var showsContinueButton: Bool {
        currentStep != .intro
    }

    /// Progress as step index (1-indexed, excluding intro)
    var progressStep: Int {
        max(0, currentStep.rawValue - 1)
    }

    static let interactiveStepCount = OnboardingStep.allCases.count - 1 // exclude intro

    // MARK: - Auth

    private(set) var userId: String?
    private(set) var isAuthenticated = false

    // MARK: - Lifecycle

    func startOnboarding() async {
        await signInAnonymously()
    }

    // MARK: - Selection Actions

    func selectTone(_ tone: AlarmTone) {
        HapticManager.shared.selection()
        configuration.tone = configuration.tone == tone ? nil : tone
    }

    func selectWhy(_ why: WhyContext) {
        HapticManager.shared.selection()
        configuration.whyContext = configuration.whyContext == why ? nil : why
    }

    func selectIntensity(_ intensity: AlarmIntensity) {
        HapticManager.shared.selection()
        configuration.intensity = configuration.intensity == intensity ? nil : intensity
    }

    func selectDifficulty(_ difficulty: AlarmDifficulty) {
        HapticManager.shared.selection()
        configuration.difficulty = configuration.difficulty == difficulty ? nil : difficulty
    }

    func selectVoice(_ voice: VoicePersona) {
        HapticManager.shared.selection()
        configuration.voicePersona = configuration.voicePersona == voice ? nil : voice
    }

    func setWakeTime(_ time: Date) {
        HapticManager.shared.selection()
        configuration.wakeTime = time
    }

    func setLeaveTime(_ time: Date?) {
        HapticManager.shared.selection()
        configuration.leaveTime = time
    }

    func setSnoozeCount(_ count: Int) {
        HapticManager.shared.selection()
        configuration.snoozeCount = count
    }

    func setSnoozeInterval(_ interval: Int) {
        HapticManager.shared.selection()
        configuration.snoozeInterval = interval
    }

    func requestAlarmPermission() async {
        // TODO: Replace with real AlarmKit authorization
        // let state = try await AlarmManager().requestAuthorization()
        // alarmPermissionGranted = state == .authorized
        // alarmPermissionDenied = state == .denied

        // Stub: simulate permission grant
        try? await Task.sleep(for: .milliseconds(500))
        alarmPermissionGranted = true
        alarmPermissionDenied = false
        HapticManager.shared.success()
    }

    var canGoBack: Bool {
        currentStep.rawValue > OnboardingStep.intro.rawValue
    }

    func goBack() {
        let all = OnboardingStep.allCases
        guard let index = all.firstIndex(of: currentStep),
              index > 0 else { return }
        HapticManager.shared.lightTap()
        currentStep = all[index - 1]
    }

    // MARK: - Continue (called by container)

    /// Advance to next step synchronously. Sync happens in background.
    func advanceToNextStep() {
        guard canContinue else { return }
        HapticManager.shared.buttonTap()

        if let next = nextStep(after: currentStep) {
            currentStep = next
        } else {
            Task { await completeOnboarding() }
        }

        // Background sync — doesn't block navigation
        Task {
            isSyncing = true
            await syncConfiguration()
            isSyncing = false
        }
    }

    // MARK: - Private — Navigation

    private func nextStep(after step: OnboardingStep) -> OnboardingStep? {
        let all = OnboardingStep.allCases
        guard let index = all.firstIndex(of: step),
              index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    // MARK: - Private — Supabase Stubs

    private func signInAnonymously() async {
        // TODO: Supabase signInAnonymously()
        // Creates anonymous JWT, assigns user_id
        // userId = supabase.auth.currentUser?.id
        userId = UUID().uuidString
        isAuthenticated = true
    }

    private func syncConfiguration() async {
        guard isAuthenticated, let userId else { return }

        // TODO: Supabase upsert to alarms table
        // try await supabase
        //     .from("alarms")
        //     .upsert(configuration, onConflict: "id")
        //     .eq("user_id", userId)
        //     .execute()

        print("[OnboardingManager] Synced config for user \(userId): tone=\(configuration.tone?.rawValue ?? "nil")")
    }

    private func completeOnboarding() async {
        guard isAuthenticated else { return }

        // TODO: Mark onboarding complete in user metadata
        // TODO: Trigger Composer to generate initial audio
        // try await supabase.functions.invoke("composer/generate", body: configuration)

        isCompleted = true
        HapticManager.shared.success()

        print("[OnboardingManager] Onboarding complete — ready to call Composer")
    }
}
