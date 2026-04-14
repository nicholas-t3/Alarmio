//
//  EditAlarmSheetContent.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/10/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

// MARK: - Custom Detents

struct EditSummaryDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        context.maxDetentValue * 0.55
    }
}

struct EditDetailDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        context.maxDetentValue * 0.85
    }
}

struct EditCompactDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        context.maxDetentValue * 0.35
    }
}

struct EditFullDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        context.maxDetentValue * 1.0
    }
}

// MARK: - Edit Alarm Sheet Content

struct EditAlarmSheetContent: View {

    // MARK: - Constants

    let alarm: AlarmConfiguration
    let onSave: (AlarmConfiguration) -> Void
    var onDelete: (() -> Void)?

    // MARK: - Init

    init(
        alarm: AlarmConfiguration,
        onSave: @escaping (AlarmConfiguration) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.alarm = alarm
        self.onSave = onSave
        self.onDelete = onDelete

        // Initialize state from the alarm at construction time so the first
        // render already reflects the alarm — otherwise hasChanges briefly
        // evaluates to true (defaults differ from alarm), which flashes the
        // Save button as enabled before snapping back.
        _editTime = State(initialValue: alarm.wakeTime ?? Date())
        _editDays = State(initialValue: Set(alarm.repeatDays ?? []))
        _editSnoozeInterval = State(initialValue: alarm.snoozeInterval)
        _editMaxSnoozes = State(initialValue: alarm.maxSnoozes)
        _editVoicePersona = State(initialValue: alarm.voicePersona)
        _editTone = State(initialValue: alarm.tone)
        _editIntensity = State(initialValue: alarm.intensity)
        _editWhyContext = State(initialValue: alarm.whyContext)
        _editLeaveTime = State(initialValue: alarm.leaveTime)
        _editSoundFileName = State(initialValue: alarm.soundFileName)

        let initialIndex: Int
        if let persona = alarm.voicePersona,
           let idx = VoicePersona.allCases.firstIndex(of: persona) {
            initialIndex = idx
        } else {
            initialIndex = 0
        }
        _voiceIndex = State(initialValue: initialIndex)
    }

    // MARK: - Environment

    @Environment(\.alarmStore) private var alarmStore
    @Environment(\.composerService) private var composerService
    @Environment(\.alertManager) private var alertManager

    // MARK: - State

    @State private var selectedDetent: PresentationDetent = .custom(EditSummaryDetent.self)
    @State private var allowedDetents: Set<PresentationDetent> = [.custom(EditSummaryDetent.self)]
    @State private var editTime: Date
    @State private var editDays: Set<Int>
    @State private var editSnoozeInterval: Int
    @State private var editMaxSnoozes: Int
    @State private var editVoicePersona: VoicePersona?
    @State private var editTone: AlarmTone?
    @State private var editIntensity: AlarmIntensity?
    @State private var editWhyContext: WhyContext?
    @State private var editLeaveTime: Date?
    @State private var editSoundFileName: String?
    @State private var activePage: EditPage = .summary
    @State private var showDetail = false
    @State private var contentVisible = true
    @State private var voicePlayer = VoicePreviewPlayer()
    @State private var voiceIndex: Int
    @State private var isRegenerating = false
    @State private var audioRegeneratedForCurrentEdits = false
    @State private var showSaveSuccess = false
    @State private var saveSuccessTask: Task<Void, Never>?

    // MARK: - Detent Constants

    private static let summaryDetent: PresentationDetent = .custom(EditSummaryDetent.self)
    private static let compactDetent: PresentationDetent = .custom(EditCompactDetent.self)
    private static let detailDetent: PresentationDetent = .custom(EditDetailDetent.self)
    private static let fullDetent: PresentationDetent = .custom(EditFullDetent.self)

    // MARK: - Computed Properties

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: editTime)
    }

    private var scheduleSummary: String {
        if editDays.isEmpty {
            return "One-time alarm"
        } else if editDays == Set([1, 2, 3, 4, 5]) {
            return "Weekdays"
        } else if editDays == Set([0, 6]) {
            return "Weekends"
        } else if editDays.count == 7 {
            return "Every day"
        } else {
            let labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return Array(editDays).sorted().compactMap { $0 < labels.count ? labels[$0] : nil }.joined(separator: ", ")
        }
    }

    private var snoozeSummary: String {
        if editMaxSnoozes == 0 {
            return "Off"
        } else {
            return "\(editMaxSnoozes) × \(editSnoozeInterval) min"
        }
    }

    private var snoozeDetail: String? {
        if editMaxSnoozes == 0 { return nil }
        let total = editMaxSnoozes * editSnoozeInterval
        return "\(total) min total"
    }

    private var styleSummary: String {
        editVoicePersona?.descriptor ?? "Not configured"
    }

    private var hasChanges: Bool {
        let originalTime = alarm.wakeTime ?? Date()
        let originalDays = Set(alarm.repeatDays ?? [])
        let cal = Calendar.current
        let timeChanged = cal.component(.hour, from: editTime) != cal.component(.hour, from: originalTime)
            || cal.component(.minute, from: editTime) != cal.component(.minute, from: originalTime)

        return timeChanged
            || editDays != originalDays
            || editSnoozeInterval != alarm.snoozeInterval
            || editMaxSnoozes != alarm.maxSnoozes
            || editVoicePersona != alarm.voicePersona
            || editTone != alarm.tone
            || editIntensity != alarm.intensity
            || editWhyContext != alarm.whyContext
            || editSoundFileName != alarm.soundFileName
    }

    private var hasStyleChanges: Bool {
        editVoicePersona != alarm.voicePersona
            || editTone != alarm.tone
            || editIntensity != alarm.intensity
            || editWhyContext != alarm.whyContext
    }

    private var hasTimeChanges: Bool {
        let originalTime = alarm.wakeTime ?? Date()
        let cal = Calendar.current
        return cal.component(.hour, from: editTime) != cal.component(.hour, from: originalTime)
            || cal.component(.minute, from: editTime) != cal.component(.minute, from: originalTime)
    }

    private var hasAudioAffectingChanges: Bool {
        hasTimeChanges || hasStyleChanges
    }

    private var needsRegeneration: Bool {
        hasAudioAffectingChanges && !audioRegeneratedForCurrentEdits
    }

    private var saveButtonLabel: String {
        if showSaveSuccess { return "Success" }
        if isRegenerating { return "Regenerating..." }
        if needsRegeneration { return "Regenerate & Save" }
        return "Save"
    }

    private var regenerateButtonLabel: String {
        if showSaveSuccess { return "Success" }
        if isRegenerating { return "Generating..." }
        return "Regenerate"
    }

    private var regenerateButtonForeground: Color {
        if showSaveSuccess { return Color(hex: "4AFF8E") }
        let active = hasStyleChanges && !isRegenerating
        return .white.opacity(active ? 1 : 0.35)
    }

    private var regenerateButtonBackground: Color {
        if showSaveSuccess { return Color(hex: "4AFF8E").opacity(0.15) }
        return .white.opacity(hasStyleChanges ? 0.1 : 0.04)
    }

    private func detentForPage(_ page: EditPage) -> PresentationDetent {
        switch page {
        case .summary: return Self.summaryDetent
        case .schedule: return Self.detailDetent
        case .snooze: return Self.compactDetent
        case .style: return Self.fullDetent
        }
    }

    private var currentDetent: PresentationDetent {
        showDetail ? detentForPage(activePage) : Self.summaryDetent
    }

    private static let allDetents: Set<PresentationDetent> = [
        .custom(EditSummaryDetent.self),
        .custom(EditCompactDetent.self),
        .custom(EditDetailDetent.self),
        .custom(EditFullDetent.self)
    ]

    // MARK: - Body

    var body: some View {
        ZStack {

            // Summary page
            if !showDetail {
                summaryPage
                    .premiumBlur(
                        isVisible: contentVisible,
                        duration: 0.25,
                        disableScale: true,
                        disableOffset: true
                    )
            }

            // Detail pages
            if showDetail {
                Group {
                    switch activePage {
                    case .schedule:
                        schedulePage
                    case .snooze:
                        snoozePage
                    case .style:
                        stylePage
                    default:
                        EmptyView()
                    }
                }
                .premiumBlur(
                    isVisible: contentVisible,
                    duration: 0.25,
                    disableScale: true,
                    disableOffset: true
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents(allowedDetents, selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(hex: "0f1a2e"))
        .interactiveDismissDisabled(isRegenerating)
        .onChange(of: editTime) { invalidateRegenerationFlag() }
        .onChange(of: editVoicePersona) { invalidateRegenerationFlag() }
        .onChange(of: editTone) { invalidateRegenerationFlag() }
        .onChange(of: editIntensity) { invalidateRegenerationFlag() }
        .onChange(of: editWhyContext) { invalidateRegenerationFlag() }
        .onDisappear {
            voicePlayer.stop()
        }
    }

    private func invalidateRegenerationFlag() {
        if audioRegeneratedForCurrentEdits {
            audioRegeneratedForCurrentEdits = false
        }
        // Any fresh edit cancels the lingering success state immediately
        if showSaveSuccess {
            saveSuccessTask?.cancel()
            saveSuccessTask = nil
            showSaveSuccess = false
        }
    }

    private func triggerSaveSuccess() {
        saveSuccessTask?.cancel()
        showSaveSuccess = true

        saveSuccessTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            showSaveSuccess = false
        }
    }

    // MARK: - Navigation

    private func navigateTo(_ page: EditPage) {
        HapticManager.shared.softTap()

        // Phase 1: blur out current content
        contentVisible = false

        // Phase 2: open the detent gate, swap page, animate resize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            allowedDetents = Self.allDetents
            activePage = page
            showDetail = true
            _ = withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                selectedDetent = detentForPage(page)
            }
        }

        // Phase 3: blur in new content after resize settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            contentVisible = true
        }

        // Phase 4: collapse the detent set to only the destination so the
        // user can't drag away from the current page's height.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            allowedDetents = [detentForPage(page)]
        }
    }

    private func navigateBack() {
        voicePlayer.stop()

        // Phase 1: blur out current content
        contentVisible = false

        // Phase 2: open the detent gate, swap back, animate resize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            allowedDetents = Self.allDetents
            showDetail = false
            _ = withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                selectedDetent = Self.summaryDetent
            }
        }

        // Phase 3: blur in summary after resize settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            contentVisible = true
        }

        // Phase 4: collapse to summary-only so user can't drag away
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            allowedDetents = [Self.summaryDetent]
        }
    }

    // MARK: - Summary Page

    private var summaryPage: some View {
        VStack(spacing: 12) {

            // Schedule row
            summaryRow(
                icon: "clock.fill",
                label: "Schedule",
                value: timeString,
                detail: scheduleSummary
            )
            .contentShape(Rectangle())
            .onTapGesture { navigateTo(.schedule) }

            // Snooze row
            summaryRow(
                icon: "zzz",
                label: "Snooze",
                value: snoozeSummary,
                detail: snoozeDetail
            )
            .contentShape(Rectangle())
            .onTapGesture { navigateTo(.snooze) }

            // Voice & Style row
            summaryRow(
                icon: "waveform",
                label: "Voice & Style",
                value: editVoicePersona?.displayName ?? "Not set",
                detail: styleSummary
            )
            .contentShape(Rectangle())
            .onTapGesture { navigateTo(.style) }

            // Save button
            Button {
                saveTapped()
            } label: {
                HStack(spacing: 8) {
                    if isRegenerating {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else if showSaveSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(saveButtonLabel)
                        .contentTransition(.numericText())
                }
            }
            .primaryButton(isEnabled: hasChanges && !isRegenerating && !showSaveSuccess)
            .disabled(!hasChanges || isRegenerating || showSaveSuccess)
            .overlay {
                if showSaveSuccess {
                    Capsule()
                        .fill(Color(hex: "4AFF8E"))
                        .overlay {
                            Capsule()
                                .strokeBorder(Color(hex: "4AFF8E").opacity(0.8), lineWidth: 1.5)
                                .blur(radius: 3)
                        }
                        .overlay {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Success")
                                    .font(AppTypography.button)
                                    .tracking(AppTypography.buttonTracking)
                            }
                            .foregroundStyle(.black)
                        }
                        .shadow(color: Color(hex: "4AFF8E").opacity(0.35), radius: 18, y: 0)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: showSaveSuccess)
            .padding(.top, 8)

            // Delete
            if onDelete != nil {
                Button {
                    HapticManager.shared.warning()
                    onDelete?()
                } label: {
                    Text("Delete")
                        .font(AppTypography.button)
                        .tracking(AppTypography.buttonTracking)
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 16)
    }

    // MARK: - Schedule Page

    private var schedulePage: some View {
        VStack(spacing: 16) {

            // Back row
            backButton

            // Time picker
            WakeTimeCard(wakeTime: $editTime, mode: .edit)

            // Regen notice
            if hasTimeChanges && !audioRegeneratedForCurrentEdits {
                Text("Changing the time will regenerate your alarm.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)
                    .premiumBlur(.in, profile: .gentle)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Day picker
            RepeatCard(selectedDays: $editDays, mode: .edit)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 12)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: hasTimeChanges)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: audioRegeneratedForCurrentEdits)
    }

    // MARK: - Snooze Page

    private var snoozePage: some View {
        VStack(spacing: 16) {

            // Back row
            backButton

            // Snooze controls
            SnoozeCard(
                maxSnoozes: $editMaxSnoozes,
                snoozeInterval: $editSnoozeInterval,
                mode: .edit
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 12)
    }

    // MARK: - Style Page

    private var stylePage: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Back row
                backButton

                // Alarm audio preview
                alarmPreviewCard

                // Compact voice selector
                compactVoiceCard

                // Customize card
                CustomizeCard(
                    tone: $editTone,
                    whyContext: $editWhyContext,
                    intensity: $editIntensity,
                    mode: .edit
                )

                // Regenerate button
                Button {
                    HapticManager.shared.buttonTap()
                    regenerateAlarm()
                } label: {
                    HStack(spacing: 8) {
                        if isRegenerating {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else if showSaveSuccess {
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
                        if showSaveSuccess {
                            Capsule()
                                .strokeBorder(Color(hex: "4AFF8E").opacity(0.6), lineWidth: 1)
                        }
                    }
                    .shadow(color: showSaveSuccess ? Color(hex: "4AFF8E").opacity(0.2) : .clear, radius: 12, y: 0)
                }
                .disabled(!hasStyleChanges || isRegenerating || showSaveSuccess)
                .animation(.easeInOut(duration: 0.35), value: showSaveSuccess)
                .animation(.easeInOut(duration: 0.25), value: isRegenerating)

                Spacer(minLength: 0)
                    .frame(height: 20)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Alarm Preview Card

    private var alarmPreviewCard: some View {
        let isPlaying = voicePlayer.isPlaying

        return VStack(spacing: 14) {

            Text("ALARM PREVIEW")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Waveform
            AlarmWaveform(bands: voicePlayer.bands, isPlaying: isPlaying)
                .frame(height: 40)
                .padding(.horizontal, 8)

            // Play button
            Button {
                HapticManager.shared.buttonTap()
                toggleAlarmAudioPreview()
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
            .disabled(editSoundFileName == nil)
            .opacity(editSoundFileName == nil ? 0.4 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPlaying)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Compact Voice Card

    private var compactVoiceCard: some View {
        let voice = VoicePersona.allCases[voiceIndex]

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
                Text(voice.displayName)
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
        .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Subviews

    private var backButton: some View {
        HStack {
            Button {
                navigateBack()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(AppTypography.labelMedium)
                }
                .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
    }

    private func summaryRow(
        icon: String,
        label: String,
        value: String,
        detail: String?
    ) -> some View {
        HStack(spacing: 14) {

            // Icon
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 24)

            // Labels
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.5))

                Text(value)
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white)

                if let detail {
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            Spacer(minLength: 0)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Voice Actions

    private func cycleVoice(by delta: Int) {
        let allVoices = VoicePersona.allCases
        let newIndex = (voiceIndex + delta + allVoices.count) % allVoices.count
        voiceIndex = newIndex
        editVoicePersona = allVoices[newIndex]
    }

    private func toggleAlarmAudioPreview() {
        if voicePlayer.isPlaying {
            voicePlayer.stop()
        } else if let fileName = editSoundFileName {
            let url = alarmStore.audioFileManager.soundFileURL(named: fileName)
            voicePlayer.playFromFile(url: url, persona: editVoicePersona)
        }
    }

    private func regenerateAlarm() {
        voicePlayer.stop()
        isRegenerating = true
        print("[EditAlarm] Regenerate tapped — starting (alarmId=\(alarm.id))")

        Task { @MainActor in
            do {
                let newFileName = try await performRegeneration()
                print("[EditAlarm] Regenerate success — newFileName=\(newFileName), prev=\(editSoundFileName ?? "nil")")
                editSoundFileName = newFileName
                logFileState(for: newFileName)
                audioRegeneratedForCurrentEdits = true
                isRegenerating = false
                HapticManager.shared.success()
                triggerSaveSuccess()
            } catch {
                isRegenerating = false
                showRegenerationError(error)
            }
        }
    }

    private func saveTapped() {
        if needsRegeneration {
            regenerateThenSave()
        } else {
            HapticManager.shared.success()
            commitSave(soundFileName: editSoundFileName)
        }
    }

    private func regenerateThenSave() {
        voicePlayer.stop()
        isRegenerating = true
        print("[EditAlarm] Save tapped with pending regen — starting (alarmId=\(alarm.id))")

        Task { @MainActor in
            do {
                let newFileName = try await performRegeneration()
                print("[EditAlarm] Save-regen success — newFileName=\(newFileName)")
                editSoundFileName = newFileName
                logFileState(for: newFileName)
                audioRegeneratedForCurrentEdits = true
                isRegenerating = false
                HapticManager.shared.success()
                showSaveSuccess = true
                try? await Task.sleep(for: .milliseconds(1000))
                commitSave(soundFileName: newFileName)
            } catch {
                isRegenerating = false
                showRegenerationError(error)
            }
        }
    }

    private func performRegeneration() async throws -> String {
        guard let composerService else {
            throw APIError.unknown(NSError(
                domain: "ComposerService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Composer service unavailable"]
            ))
        }

        var config = alarm
        config.wakeTime = editTime
        config.voicePersona = editVoicePersona
        config.tone = editTone
        config.intensity = editIntensity
        config.whyContext = editWhyContext

        print("[EditAlarm] Calling composer — voice=\(editVoicePersona?.rawValue ?? "nil"), tone=\(editTone?.rawValue ?? "nil"), intensity=\(editIntensity?.rawValue ?? "nil"), why=\(editWhyContext?.rawValue ?? "nil"), time=\(config.wakeTime?.description ?? "nil")")
        return try await composerService.generateAndDownloadAudio(for: config)
    }

    private func logFileState(for fileName: String) {
        let url = alarmStore.audioFileManager.soundFileURL(named: fileName)
        let exists = FileManager.default.fileExists(atPath: url.path)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        print("[EditAlarm] File state — name=\(fileName), exists=\(exists), size=\(size)B, path=\(url.path)")
    }

    private func commitSave(soundFileName: String?) {
        var updated = alarm
        updated.wakeTime = editTime
        updated.repeatDays = editDays.isEmpty ? nil : Array(editDays).sorted()
        updated.snoozeInterval = editSnoozeInterval
        updated.maxSnoozes = editMaxSnoozes
        updated.voicePersona = editVoicePersona
        updated.tone = editTone
        updated.intensity = editIntensity
        updated.whyContext = editWhyContext
        updated.leaveTime = editLeaveTime
        updated.soundFileName = soundFileName

        // Clean up orphaned nonce files from abandoned regenerations, but
        // preserve the nonce we're committing. Only runs when a new
        // nonce-suffixed filename is being persisted.
        if let soundFileName, soundFileName != alarm.soundFileName {
            let nonce = soundFileName
                .components(separatedBy: ".").first?
                .components(separatedBy: "_").last
            alarmStore.audioFileManager.purgeIndexedSounds(
                for: alarm.id,
                keepingNonce: nonce
            )
        }

        onSave(updated)
    }

    private func showRegenerationError(_ error: Error) {
        print("[EditAlarm] Regenerate failed: \(error)")
        let code: String
        if let apiError = error as? APIError {
            code = apiError.errorDescription ?? String(describing: apiError)
        } else {
            code = (error as NSError).domain + ":\((error as NSError).code)"
        }
        HapticManager.shared.error()
        alertManager.showToast(
            message: "Something went wrong. Please try again. (\(code))",
            kind: .failure,
            duration: 3.5
        )
    }

    // MARK: - Data

    private enum EditPage {
        case summary
        case schedule
        case snooze
        case style
    }
}

// MARK: - Alarm Waveform

private struct AlarmWaveform: View {

    let bands: [CGFloat]
    let isPlaying: Bool

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 4
    private let minBarHeight: CGFloat = 3
    private let restingHeights: [CGFloat] = (0..<24).map { i in
        let t = CGFloat(i) / 23.0
        let hump = sin(t * .pi)
        return 0.2 + hump * 0.3
    }

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

#Preview("Edit Summary") {
    struct PreviewContainer: View {
        @State private var showSheet = true

        var body: some View {
            ZStack {
                MorningSky(starOpacity: 0.8, showConstellations: false)
            }
            .sheet(isPresented: $showSheet) {
                EditAlarmSheetContent(
                    alarm: AlarmConfiguration(
                        isEnabled: true,
                        wakeTime: Calendar.current.date(from: DateComponents(hour: 7, minute: 0)),
                        repeatDays: [1, 2, 3, 4, 5],
                        tone: .calm,
                        intensity: .gentle,
                        voicePersona: .calmGuide,
                        snoozeInterval: 5,
                        maxSnoozes: 2
                    ),
                    onSave: { _ in },
                    onDelete: {}
                )
            }
        }
    }

    return PreviewContainer()
}
