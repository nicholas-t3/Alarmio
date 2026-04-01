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

    // MARK: - Auth

    private(set) var userId: String?
    private(set) var isAuthenticated = false

    // MARK: - Lifecycle

    func startOnboarding() async {
        await signInAnonymously()
    }

    // MARK: - Step Navigation

    func completeIntro() {
        HapticManager.shared.buttonTap()
        advanceToStep(.tone)
    }

    func selectTone(_ tone: AlarmTone) {
        HapticManager.shared.selection()
        configuration.tone = tone
    }

    func completeTone() {
        guard configuration.tone != nil else { return }
        HapticManager.shared.buttonTap()

        Task {
            await syncConfiguration()
            advanceToStep(.why)
        }
    }

    func selectWhy(_ why: WhyContext) {
        HapticManager.shared.selection()
        configuration.whyContext = why
    }

    func completeWhy() {
        guard configuration.whyContext != nil else { return }
        HapticManager.shared.buttonTap()

        Task {
            await syncConfiguration()
            advanceToStep(.intensity)
        }
    }

    func selectIntensity(_ intensity: AlarmIntensity) {
        HapticManager.shared.selection()
        configuration.intensity = intensity
    }

    func completeIntensity() {
        guard configuration.intensity != nil else { return }
        HapticManager.shared.buttonTap()

        Task {
            await syncConfiguration()
            advanceToStep(.difficulty)
        }
    }

    func selectDifficulty(_ difficulty: AlarmDifficulty) {
        HapticManager.shared.selection()
        configuration.difficulty = difficulty
    }

    func completeDifficulty() {
        guard configuration.difficulty != nil else { return }
        HapticManager.shared.buttonTap()

        Task {
            await syncConfiguration()
            advanceToStep(.voice)
        }
    }

    func selectVoice(_ voice: VoicePersona) {
        HapticManager.shared.selection()
        configuration.voicePersona = voice
    }

    func completeVoice() {
        guard configuration.voicePersona != nil else { return }
        HapticManager.shared.buttonTap()

        Task {
            await syncConfiguration()
            advanceToStep(.content)
        }
    }

    func toggleContentFlag(_ flag: ContentFlag) {
        HapticManager.shared.selection()
        if configuration.contentFlags.contains(flag) {
            configuration.contentFlags.removeAll { $0 == flag }
        } else {
            configuration.contentFlags.append(flag)
        }
    }

    func completeContent() {
        guard !configuration.contentFlags.isEmpty else { return }
        HapticManager.shared.buttonTap()

        Task {
            await syncConfiguration()
            advanceToStep(.leaveTime)
        }
    }

    func setLeaveTime(_ time: Date?) {
        configuration.leaveTime = time
    }

    func completeLeaveTime() {
        HapticManager.shared.buttonTap()

        Task {
            await syncConfiguration()
            advanceToStep(.wakeTime)
        }
    }

    func setWakeTime(_ time: Date) {
        configuration.wakeTime = time
    }

    func completeWakeTime() {
        guard configuration.wakeTime != nil else { return }
        HapticManager.shared.buttonTap()

        Task {
            await syncConfiguration()
            advanceToStep(.snooze)
        }
    }

    func setSnooze(count: Int, interval: Int) {
        configuration.snoozeCount = count
        configuration.snoozeInterval = interval
    }

    func completeSnooze() {
        HapticManager.shared.buttonTap()

        Task {
            await syncConfiguration()
            await completeOnboarding()
        }
    }

    // MARK: - Private — Navigation

    private func advanceToStep(_ step: OnboardingStep) {
        currentStep = step
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
