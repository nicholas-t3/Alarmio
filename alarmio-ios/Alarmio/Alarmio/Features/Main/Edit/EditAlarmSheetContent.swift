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
    /// Set once at app launch from `DeviceInfo.screenHeight`. The detent
    /// API is static and has no access to environment, so we inject the
    /// real hardware height here.
    static var hardwareScreenHeight: CGFloat = 852

    static func height(in context: Context) -> CGFloat? {
        let screen = hardwareScreenHeight
        let max = context.maxDetentValue
        let result: CGFloat
        let bucket: String
        if screen < 750 {
            result = max
            bucket = "COMPACT (full screen)"
        } else if screen > 900 {
            result = max * 0.75
            bucket = "LARGE (0.75)"
        } else {
            result = max * 0.85
            bucket = "STANDARD (0.85)"
        }
        print("[EditSummaryDetent] screen=\(Int(screen))pt maxDetentValue=\(Int(max)) → \(bucket) → height=\(Int(result))")
        return result
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
        _editName = State(initialValue: alarm.name ?? "")
        _editAlarmType = State(initialValue: alarm.alarmType)
        _editApprovedScripts = State(initialValue: alarm.approvedScripts)
        _editCustomPrompt = State(initialValue: alarm.customPrompt ?? "")
        _editCustomPromptIncludes = State(initialValue: alarm.customPromptIncludes)
        _editCreativeSnoozes = State(initialValue: alarm.creativeSnoozes)
        _editProPreviewScripts = State(initialValue: alarm.approvedScripts)
        _editLiveActivityEnabled = State(initialValue: alarm.liveActivityEnabled)
        _editLiveActivityLeadHours = State(initialValue: alarm.liveActivityLeadHours)
        // Seed the snapshot so on-open state is considered clean (Save,
        // not Regenerate). A nil snapshot would always read as dirty vs
        // any non-nil draft snapshot.
        _editProPreviewSnapshot = State(initialValue: ProPreviewInputs(
            prompt: alarm.customPrompt ?? "",
            includes: alarm.customPromptIncludes,
            creativeSnoozes: alarm.creativeSnoozes,
            leaveTime: alarm.leaveTime,
            maxSnoozes: alarm.maxSnoozes,
            unlimitedSnooze: false,
            tone: alarm.tone,
            whyContext: alarm.whyContext,
            intensity: alarm.intensity
        ))

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
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.proLimitCounter) private var proLimitCounter

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
    @State private var editName: String
    @FocusState private var nameFieldFocused: Bool
    @State private var activePage: EditPage = .summary
    @State private var showDetail = false
    @State private var contentVisible = true
    /// Plays the generated alarm MP3 (inside `alarmPreviewCard`).
    @State private var alarmAudioPlayer = VoicePreviewPlayer()
    /// Plays the voice-persona preview (inside `CompactPlayableVoiceCard`).
    /// Separate from `alarmAudioPlayer` so one Play button doesn't bleed
    /// into the other's UI.
    @State private var voicePersonaPlayer = VoicePreviewPlayer()
    @State private var voiceIndex: Int
    @State private var isRegenerating = false
    @State private var audioRegeneratedForCurrentEdits = false
    /// Set to true while the regen-success path is writing the freshly
    /// reconciled scripts back into `editApprovedScripts`. The
    /// `invalidateRegenerationFlag` onChange handlers respect this
    /// guard so our own internal writes don't trip the "user made an
    /// edit, regeneration is now stale" path.
    @State private var suppressRegenInvalidate: Bool = false
    /// Flips true after a failed regen. Drives the style-page footer
    /// button into a red "Please try again" state. Cleared automatically
    /// on any user edit (via `invalidateRegenerationFlag`) or on the
    /// next successful regen.
    @State private var regenerationError: Bool = false
    @State private var regenerationErrorTask: Task<Void, Never>?
    /// Reconciled approvedScripts from the last regeneration. Nil means
    /// either this is a basic alarm or reconcile hasn't run yet. When
    /// non-nil, `commitSave` uses these instead of the original alarm's
    /// scripts so the persisted config matches the audio on disk.
    @State private var reconciledApprovedScripts: [String]?
    @State private var showSaveSuccess = false
    @State private var showPaywall = false
    /// Action to re-fire if the user subscribes inside the paywall sheet.
    @State private var pendingActionAfterPaywall: (() -> Void)?
    @State private var saveSuccessTask: Task<Void, Never>?

    // Pro fields — editable when the alarm is (or becomes) a pro alarm.
    @State private var editAlarmType: AlarmType
    @State private var editApprovedScripts: [String]?
    @State private var editCustomPrompt: String
    @State private var editCustomPromptIncludes: Set<CustomPromptInclude>
    @State private var editCreativeSnoozes: Bool
    /// Pro preview scratchpad — now driven inline on the style page
    /// (was previously on the separate `.proPrompt` page). Seeded with
    /// the alarm's existing approvedScripts so Pro alarms land on the
    /// style page with the preview card already populated.
    @State private var editProPreviewScripts: [String]?
    @State private var editProPreviewIsGenerating: Bool = false
    @State private var editProPreviewError: String?
    @State private var editProPreviewSnapshot: ProPreviewInputs?
    /// Guards `flipProOnStyle` against double-taps while the coordinated
    /// blur-out/swap/blur-in is in flight.
    @State private var proStyleTransitioning: Bool = false
    /// Per-card blur gate for the style page. Defaults to true (mounted
    /// visible); `flipProOnStyle` flips it to false around the Pro
    /// toggle mutation so each card's `.premiumBlur` fades out, the
    /// layout changes behind an invisible screen, then fades back in.
    @State private var styleCardsVisible: Bool = true
    /// Bumped after a successful regeneration so the style page's
    /// `ScrollViewReader` animates back to the top — so the Success
    /// flash + refreshed preview card are in view.
    @State private var styleScrollToTopToken: Int = 0

    // Live Activity settings
    @State private var editLiveActivityEnabled: Bool
    @State private var editLiveActivityLeadHours: Int

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
            || editLeaveTime != alarm.leaveTime
            || editSoundFileName != alarm.soundFileName
            || normalizedEditName != (alarm.name ?? "")
            || hasProChanges
            || editLiveActivityEnabled != alarm.liveActivityEnabled
            || editLiveActivityLeadHours != alarm.liveActivityLeadHours
    }

    private var liveActivitySummary: String {
        editLiveActivityEnabled ? "On" : "Off"
    }

    private var liveActivityDetail: String? {
        guard editLiveActivityEnabled else { return nil }
        let hours = editLiveActivityLeadHours
        return "\(hours) hour\(hours == 1 ? "" : "s") before"
    }

    private var normalizedEditName: String {
        editName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasStyleChanges: Bool {
        editVoicePersona != alarm.voicePersona
            || editTone != alarm.tone
            || editIntensity != alarm.intensity
            || editWhyContext != alarm.whyContext
            || editLeaveTime != alarm.leaveTime
    }

    private var hasTimeChanges: Bool {
        let originalTime = alarm.wakeTime ?? Date()
        let cal = Calendar.current
        return cal.component(.hour, from: editTime) != cal.component(.hour, from: originalTime)
            || cal.component(.minute, from: editTime) != cal.component(.minute, from: originalTime)
    }

    private var hasProChanges: Bool {
        editAlarmType != alarm.alarmType
            || editApprovedScripts != alarm.approvedScripts
            || editCustomPrompt != (alarm.customPrompt ?? "")
            || editCustomPromptIncludes != alarm.customPromptIncludes
            || editCreativeSnoozes != alarm.creativeSnoozes
            || hasSnoozeCountChange
    }

    // Snooze count only affects audio when the alarm actually produces
    // per-snooze files: Basic alarms always do; Pro alarms only when
    // creativeSnoozes is on. snoozeInterval never affects audio.
    private var snoozeCountAffectsAudio: Bool {
        editAlarmType == .basic || editCreativeSnoozes
    }

    // Only an INCREASE needs regeneration (missing files to generate).
    // A decrease just leaves orphaned files, which is fine — the scheduler
    // only reads the indices it needs, and commitSave persists the new cap.
    private var hasSnoozeCountChange: Bool {
        editMaxSnoozes > alarm.maxSnoozes && snoozeCountAffectsAudio
    }

    private var hasAudioAffectingChanges: Bool {
        hasTimeChanges || hasStyleChanges || hasProChanges
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

    private func detentForPage(_ page: EditPage) -> PresentationDetent {
        switch page {
        case .summary: return Self.summaryDetent
        case .name: return Self.compactDetent
        case .schedule: return Self.detailDetent
        case .snooze: return Self.compactDetent
        case .style: return Self.fullDetent
        case .liveActivity: return Self.detailDetent
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
                    case .name:
                        namePage
                    case .schedule:
                        schedulePage
                    case .snooze:
                        snoozePage
                    case .style:
                        stylePage
                    case .liveActivity:
                        liveActivityPage
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
        .onChange(of: editLeaveTime) { invalidateRegenerationFlag() }
        .onChange(of: editAlarmType) { invalidateRegenerationFlag() }
        .onChange(of: editApprovedScripts) { invalidateRegenerationFlag() }
        .onChange(of: editCustomPrompt) { invalidateRegenerationFlag() }
        .onChange(of: editCustomPromptIncludes) { invalidateRegenerationFlag() }
        .onChange(of: editCreativeSnoozes) { invalidateRegenerationFlag() }
        .onChange(of: editMaxSnoozes) { invalidateRegenerationFlag() }
        .onDisappear {
            alarmAudioPlayer.stop()
            voicePersonaPlayer.stop()
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            let action = pendingActionAfterPaywall
            pendingActionAfterPaywall = nil
            if subscriptionService.isPro, let action {
                action()
            }
        }) {
            PaywallSheet()
        }
    }

    /// Runs `action` if the user is Pro or still has free generations left.
    /// Otherwise stashes the action, shows the paywall, and re-fires on
    /// successful subscribe. Used by both `saveTapped` (when regen is
    /// pending) and `regenerateAlarm`.
    private func gateMainGeneration(action: @escaping () -> Void) {
        if proLimitCounter.canUseMain(isPro: subscriptionService.isPro) {
            action()
        } else {
            pendingActionAfterPaywall = action
            showPaywall = true
        }
    }

    private func invalidateRegenerationFlag() {
        // Internal regen writes aren't user edits — skip invalidation
        // when the regen-success path is writing freshly reconciled
        // scripts back into `editApprovedScripts`.
        guard !suppressRegenInvalidate else { return }
        if audioRegeneratedForCurrentEdits {
            audioRegeneratedForCurrentEdits = false
        }
        // Any fresh edit cancels the lingering success state immediately
        if showSaveSuccess {
            saveSuccessTask?.cancel()
            saveSuccessTask = nil
            showSaveSuccess = false
        }
        // Clear the red error state — user has made a new edit, they
        // should see the normal Regenerate affordance, not the retry.
        if regenerationError {
            regenerationErrorTask?.cancel()
            regenerationErrorTask = nil
            withAnimation(.easeOut(duration: 0.2)) {
                regenerationError = false
            }
        }
    }

    private func triggerSaveSuccess() {
        saveSuccessTask?.cancel()
        showSaveSuccess = true

        saveSuccessTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled else { return }
            showSaveSuccess = false
        }
    }

    /// Flashes the footer button into its red "Please try again" state
    /// for 2.5s, then restores it to the regular Regenerate label —
    /// same cadence as `triggerSaveSuccess`.
    private func triggerRegenerationError() {
        regenerationErrorTask?.cancel()
        regenerationError = true

        regenerationErrorTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                regenerationError = false
            }
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
        alarmAudioPlayer.stop()
        voicePersonaPlayer.stop()
        nameFieldFocused = false

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

            // Name row
            summaryRow(
                icon: "tag.fill",
                label: "Alarm Name",
                value: normalizedEditName.isEmpty ? "None" : normalizedEditName,
                detail: nil
            )
            .contentShape(Rectangle())
            .onTapGesture { navigateTo(.name) }

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

            // Live Activity row
            summaryRow(
                icon: "sparkles.rectangle.stack.fill",
                label: "Live Activity",
                value: liveActivitySummary,
                detail: liveActivityDetail
            )
            .contentShape(Rectangle())
            .onTapGesture { navigateTo(.liveActivity) }

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
            .primaryButton(isEnabled: hasChanges && !isRegenerating && !showSaveSuccess && !regenerationError)
            .disabled(!hasChanges || isRegenerating || showSaveSuccess || regenerationError)
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
                } else if regenerationError {
                    Capsule()
                        .fill(Color(hex: "FF5C5C"))
                        .overlay {
                            Capsule()
                                .strokeBorder(Color(hex: "FF5C5C").opacity(0.8), lineWidth: 1.5)
                                .blur(radius: 3)
                        }
                        .overlay {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Please try again")
                                    .font(AppTypography.button)
                                    .tracking(AppTypography.buttonTracking)
                            }
                            .foregroundStyle(.white)
                        }
                        .shadow(color: Color(hex: "FF5C5C").opacity(0.35), radius: 18, y: 0)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: showSaveSuccess)
            .animation(.easeInOut(duration: 0.35), value: regenerationError)
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

    // MARK: - Name Page

    private var namePage: some View {
        VStack(spacing: 16) {

            // Back row
            backButton

            // Name field card
            VStack(alignment: .leading, spacing: 10) {
                Text("ALARM NAME")
                    .font(AppTypography.caption)
                    .tracking(AppTypography.captionTracking)
                    .foregroundStyle(.white.opacity(0.4))

                TextField(
                    "",
                    text: $editName,
                    prompt: Text("Name this alarm").foregroundStyle(.white.opacity(0.3))
                )
                .font(AppTypography.labelLarge)
                .foregroundStyle(.white)
                .tint(.white)
                .submitLabel(.done)
                .focused($nameFieldFocused)
                .onSubmit { navigateBack() }
                .onChange(of: editName) { _, newValue in
                    if newValue.count > 40 {
                        editName = String(newValue.prefix(40))
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            nameFieldFocused = false
                            navigateBack()
                        }
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 12)
        .onAppear {
            // Auto-focus after the premium blur transition settles so the
            // keyboard animation doesn't race the sheet resize.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                nameFieldFocused = true
            }
        }
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

    // MARK: - Live Activity Page

    private var liveActivityPage: some View {
        VStack(spacing: 16) {

            // Back row
            backButton

            // Toggle card
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SHOW LIVE ACTIVITY")
                            .font(AppTypography.caption)
                            .tracking(AppTypography.captionTracking)
                            .foregroundStyle(.white.opacity(0.4))
                        Text("A countdown card on your lock screen before this alarm rings. Window may shorten for alarms set sooner than the selected lead.")
                            .font(AppTypography.caption)
                            .foregroundStyle(.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    Toggle("", isOn: $editLiveActivityEnabled)
                        .labelsHidden()
                        .tint(Color(hex: "3A6EAA"))
                        .onChange(of: editLiveActivityEnabled) { _, _ in
                            HapticManager.shared.selection()
                        }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))

            // Hours picker card — only visible when enabled
            if editLiveActivityEnabled {
                VStack(alignment: .leading, spacing: 14) {
                    Text("SHOW IT HOW FAR AHEAD")
                        .font(AppTypography.caption)
                        .tracking(AppTypography.captionTracking)
                        .foregroundStyle(.white.opacity(0.4))

                    HStack(spacing: 10) {
                        ForEach([1, 3, 6, 9], id: \.self) { hours in
                            leadHourChip(hours)
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 12)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: editLiveActivityEnabled)
    }

    private func leadHourChip(_ hours: Int) -> some View {
        let selected = editLiveActivityLeadHours == hours
        return Button {
            HapticManager.shared.selection()
            _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                editLiveActivityLeadHours = hours
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(hours)")
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(selected ? .white : .white.opacity(0.6))
                Text(hours == 1 ? "hour" : "hours")
                    .font(AppTypography.caption)
                    .foregroundStyle(.white.opacity(selected ? 0.7 : 0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(selected ? 0.12 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        selected
                            ? Color(hex: "3A6EAA").opacity(0.7)
                            : Color.white.opacity(0.05),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Style Page

    /// Anchor ID attached to the style page's back button (top of the
    /// ScrollView). Bumping `styleScrollToTopToken` animates a scroll
    /// back to this ID.
    private static let styleTopAnchor = "editStyleTop"

    private var stylePage: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {

                        // Back row — scroll-to-top anchor.
                        backButton
                            .id(Self.styleTopAnchor)

                        // Alarm audio preview — plays the committed audio.
                        alarmPreviewCard
                            .premiumBlur(isVisible: styleCardsVisible, delay: 0, duration: 0.4)

                    // Voice — always the playable compact card (basic +
                    // pro). The old non-playable compactVoiceCard was
                    // deleted because it offered no way to preview.
                    compactPlayableVoiceSection
                        .premiumBlur(isVisible: styleCardsVisible, delay: 0.05, duration: 0.4)

                    // Pro text preview card — between voice and Customize,
                    // matching the Create flow. Stays mounted across
                    // regenerations so the text swaps via .contentTransition.
                    if editAlarmType == .pro,
                       let first = editProPreviewScripts?.first {
                        proResultCard(text: first)
                            .premiumBlur(isVisible: styleCardsVisible, delay: 0.08, duration: 0.4)
                    }

                    // Pro error card — shown in place of the preview when
                    // generation failed.
                    if editAlarmType == .pro,
                       !editProPreviewIsGenerating,
                       let err = editProPreviewError {
                        proErrorCard(message: err)
                            .premiumBlur(isVisible: styleCardsVisible, delay: 0.08, duration: 0.4)
                    }

                    // Customize card — Pro row first, inline Pro rows
                    // (Guidelines / Include / Creative Snoozes) when Pro.
                    CustomizeCard(
                        tone: $editTone,
                        whyContext: $editWhyContext,
                        intensity: $editIntensity,
                        leaveTime: $editLeaveTime,
                        customPromptIncludes: $editCustomPromptIncludes,
                        customPrompt: Binding(
                            get: { editCustomPrompt },
                            set: { editCustomPrompt = $0 }
                        ),
                        creativeSnoozes: $editCreativeSnoozes,
                        wakeTime: editTime,
                        isProOn: Binding(
                            get: { editAlarmType == .pro },
                            set: { _ in /* write goes through onFlipPro */ }
                        ),
                        showProRow: true,
                        showProInlineRows: true,
                        proCustomized: (editApprovedScripts ?? []).isEmpty == false,
                        onTapProRow: nil,
                        onFlipProOn: nil,
                        onFlipPro: { newValue in flipProOnStyle(to: newValue) },
                        mode: .edit
                    )
                    .premiumBlur(isVisible: styleCardsVisible, delay: 0.1, duration: 0.4)

                        Spacer(minLength: 0)
                            .frame(height: 20)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.82), value: editProPreviewScripts)
                    .animation(.easeInOut(duration: 0.25), value: editProPreviewError)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: styleScrollToTopToken) { _, _ in
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                        proxy.scrollTo(Self.styleTopAnchor, anchor: .top)
                    }
                }
            }

            // Pinned footer — single Regenerate button shared by basic + pro.
            stylePageFooter
                .padding(.horizontal, AppButtons.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
    }

    /// Wraps the shared `CompactPlayableVoiceCard`. Used on the style
    /// page when Pro is on. Previews the voice persona, separate from
    /// the alarm-audio Play button in `alarmPreviewCard`.
    private var compactPlayableVoiceSection: some View {
        let voice = VoiceCatalog.all[voiceIndex]
        // The Play/Stop glyph reflects the player's state, not a
        // per-persona binding. Cycling voices while playing hands off
        // to the new persona immediately — the button stays "Stop"
        // until the user explicitly taps it or the clip ends naturally.
        let isPlayingThis = voicePersonaPlayer.isPlaying
        return CompactPlayableVoiceCard(
            voice: voice,
            isPlayingThis: isPlayingThis,
            onPrev: { cycleVoice(by: -1) },
            onNext: { cycleVoice(by: 1) },
            onTogglePlay: { toggleVoicePreview() },
            mode: .edit
        )
    }

    private func toggleVoicePreview() {
        if voicePersonaPlayer.isPlaying {
            voicePersonaPlayer.stop()
        } else {
            // Stop the alarm preview if it was running — simultaneous
            // audio from both Play buttons would be a mess.
            alarmAudioPlayer.stop()
            let voice = VoiceCatalog.all[voiceIndex]
            voicePersonaPlayer.play(persona: voice.persona)
        }
    }

    /// Mirror of `ProPromptView.resultCard` / CreateAlarmView.proResultCard.
    /// Inline copy so the edit sheet can show the pro text preview between
    /// voice and CustomizeCard without pulling in ProPromptView.
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
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: .edit))
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
        .modifier(CardGlassModifier(mode: .edit))
    }

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

    /// Builds a ProPreviewInputs snapshot from the current edit-state
    /// values. Used to detect dirtiness against `editProPreviewSnapshot`
    /// (set when the user last generated text).
    private func proPreviewDraftSnapshot() -> ProPreviewInputs {
        ProPreviewInputs(
            prompt: editCustomPrompt,
            includes: editCustomPromptIncludes,
            creativeSnoozes: editCreativeSnoozes,
            leaveTime: editLeaveTime,
            maxSnoozes: editMaxSnoozes,
            unlimitedSnooze: false,
            tone: editTone,
            whyContext: editWhyContext,
            intensity: editIntensity
        )
    }

    private func runEditProPreview() async {
        let promptText = editCustomPrompt
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !editProPreviewIsGenerating else { return }
        guard let composerService else {
            editProPreviewError = "Composer service unavailable."
            HapticManager.shared.error()
            return
        }

        // Build an AlarmConfiguration from the current edit state to pass
        // as the draft (the endpoint uses voice/tone/persona fields).
        var draft = alarm
        draft.wakeTime = editTime
        draft.voicePersona = editVoicePersona
        draft.tone = editTone
        draft.intensity = editIntensity
        draft.whyContext = editWhyContext
        draft.leaveTime = editLeaveTime
        draft.maxSnoozes = editMaxSnoozes
        draft.customPrompt = promptText
        draft.customPromptIncludes = editCustomPromptIncludes
        draft.creativeSnoozes = editCreativeSnoozes

        let snoozeCount: Int = {
            guard editCreativeSnoozes else { return 0 }
            // Edit sheet doesn't expose unlimitedSnooze currently; treat
            // as limited by default.
            return editMaxSnoozes
        }()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            editProPreviewIsGenerating = true
            editProPreviewError = nil
            editProPreviewScripts = nil
        }

        do {
            let scripts = try await composerService.generateCustomAlarmText(
                draft: draft,
                prompt: promptText,
                includes: editCustomPromptIncludes,
                snoozeCount: snoozeCount,
                baseScript: nil
            )
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                editProPreviewScripts = scripts
                editProPreviewSnapshot = proPreviewDraftSnapshot()
                editProPreviewIsGenerating = false
            }
            HapticManager.shared.softTap()
        } catch {
            let description = (error as? APIError)?.errorDescription ?? "Please try again."
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                editProPreviewError = description
                editProPreviewIsGenerating = false
            }
            HapticManager.shared.error()
        }
    }

    // MARK: - Style Page Footer

    /// Pinned footer on the style page. Basic mode: single "Regenerate"
    /// button. Pro mode: the 3-state machine from CreateAlarmView
    /// (Generate Text → Regenerate Text → Generate Now). No phase
    /// transitions — this is the edit sheet; `regenerateAlarm()` runs
    /// inline and the user stays on the page.
    @ViewBuilder
    private var stylePageFooter: some View {
        let state = stylePageFooterState

        Button {
            guard state.enabled, !showSaveSuccess else { return }
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
        .primaryButton(isEnabled: state.enabled && !showSaveSuccess && !regenerationError)
        .disabled(!state.enabled || showSaveSuccess || regenerationError)
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
            } else if regenerationError {
                Capsule()
                    .fill(Color(hex: "FF5C5C"))
                    .overlay {
                        Capsule()
                            .strokeBorder(Color(hex: "FF5C5C").opacity(0.8), lineWidth: 1.5)
                            .blur(radius: 3)
                    }
                    .overlay {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Please try again")
                                .font(AppTypography.button)
                                .tracking(AppTypography.buttonTracking)
                        }
                        .foregroundStyle(.white)
                    }
                    .shadow(color: Color(hex: "FF5C5C").opacity(0.35), radius: 18, y: 0)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showSaveSuccess)
        .animation(.easeInOut(duration: 0.35), value: regenerationError)
    }

    private struct StylePageFooterState {
        let label: String
        let enabled: Bool
        let showSpinner: Bool
        let action: () -> Void
    }

    /// Single "Regenerate" button for both basic and pro. Lights up when
    /// any audio-affecting field has drifted since the last regen.
    /// Tapping runs `regenerateAlarm()` which handles the full pipeline:
    /// regenerates Pro text (if pro-text inputs drifted), reconciles
    /// scripts against time/snooze drift, and regenerates audio. Mirrors
    /// the summary's "Regenerate & Save" behavior minus the save step.
    private var stylePageFooterState: StylePageFooterState {
        let basicReady = editTone != nil && editWhyContext != nil && editIntensity != nil
        let audioDirty = hasAudioAffectingChanges && !audioRegeneratedForCurrentEdits
        // Pro needs a prompt — can't generate text from an empty string.
        let proReady = editAlarmType != .pro
            || !editCustomPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if isRegenerating {
            return StylePageFooterState(
                label: "",
                enabled: false,
                showSpinner: true,
                action: {}
            )
        }

        if regenerationError {
            return StylePageFooterState(
                label: "Please try again",
                enabled: basicReady && proReady,
                showSpinner: false,
                action: { gateMainGeneration { regenerateAlarm() } }
            )
        }

        return StylePageFooterState(
            label: "Regenerate",
            enabled: audioDirty && basicReady && proReady,
            showSpinner: false,
            action: { gateMainGeneration { regenerateAlarm() } }
        )
    }

    // MARK: - Pro Flip Transition

    /// Coordinated Pro on/off transition for the style page. Mirrors
    /// CreateAlarmView's `flipPro(to:)` exactly — toggles `styleCardsVisible`
    /// to drive the per-card `premiumBlur` envelope; lets the modifier
    /// own its own animation (no `withAnimation` wrap); mutates
    /// `editAlarmType` inside a `disablesAnimations` transaction so the
    /// voice card swap + CustomizeCard row insert happen behind a
    /// fully-invisible screen.
    private func flipProOnStyle(to newValue: Bool) {
        guard !proStyleTransitioning else { return }
        proStyleTransitioning = true

        // Step 1: blur everything out via the per-card premiumBlur envelope.
        styleCardsVisible = false

        Task { @MainActor in
            // Step 2: wait for the blur-out to complete. premiumBlur's
            // default duration is ~0.4s; buffer a touch to be safe.
            try? await Task.sleep(for: .milliseconds(450))

            // Step 3: reshape the card with all implicit animations
            // disabled — Toggle thumb, inline row inserts, voice card
            // swap, onChange handlers all pop instantly behind the
            // invisible blur envelope.
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                editAlarmType = newValue ? .pro : .basic
            }

            // Step 4: one layout tick so the new height is measured
            // before we start the blur-in.
            try? await Task.sleep(for: .milliseconds(60))

            // Step 5: blur back in with the new layout.
            styleCardsVisible = true
            proStyleTransitioning = false
        }
    }

    // MARK: - Alarm Preview Card

    private var alarmPreviewCard: some View {
        let isPlaying = alarmAudioPlayer.isPlaying

        return VStack(spacing: 14) {

            Text("ALARM PREVIEW")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Waveform — bound to the alarm-audio player, so voice
            // previews can't bleed into it.
            AlarmWaveform(bands: alarmAudioPlayer.bands, isPlaying: isPlaying)
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

        // If voice preview was already playing, hand off to the new
        // persona immediately — the Play button represents "permission
        // to preview the currently-selected voice," not a per-persona
        // play/stop binding. User must tap Stop explicitly to silence.
        if voicePersonaPlayer.isPlaying {
            voicePersonaPlayer.play(persona: allVoices[newIndex])
        }
    }

    private func toggleAlarmAudioPreview() {
        if alarmAudioPlayer.isPlaying {
            alarmAudioPlayer.stop()
        } else if let fileName = editSoundFileName {
            // Stop any voice preview before kicking off the alarm audio.
            voicePersonaPlayer.stop()
            let url = alarmStore.audioFileManager.soundFileURL(named: fileName)
            alarmAudioPlayer.playFromFile(url: url, persona: editVoicePersona)
        }
    }

    private func regenerateAlarm() {
        alarmAudioPlayer.stop()
        voicePersonaPlayer.stop()
        isRegenerating = true
        print("[EditAlarm] Regenerate tapped — starting (alarmId=\(alarm.id))")

        Task { @MainActor in
            do {
                let newFileName = try await performRegeneration()
                print("[EditAlarm] Regenerate success — newFileName=\(newFileName), prev=\(editSoundFileName ?? "nil")")
                editSoundFileName = newFileName
                logFileState(for: newFileName)
                audioRegeneratedForCurrentEdits = true
                regenerationError = false
                // Sync the pro preview card's text with whatever
                // `performRegeneration` reconciled. Otherwise the card
                // keeps showing stale text after a successful regen.
                // `suppressRegenInvalidate` blocks our own writes from
                // tripping the onChange handlers that are meant to fire
                // on user edits (and would wipe the flag we just set).
                if let fresh = reconciledApprovedScripts {
                    suppressRegenInvalidate = true
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        editProPreviewScripts = fresh
                        editApprovedScripts = fresh
                    }
                    editProPreviewSnapshot = proPreviewDraftSnapshot()
                    // Flip off after one runloop so any trailing
                    // onChange firings from the writes above have
                    // already fired (and been ignored).
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(50))
                        suppressRegenInvalidate = false
                    }
                }
                // Animate the ScrollView back to the top so the new
                // preview card (and Success flash) is immediately in view.
                styleScrollToTopToken &+= 1
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
            gateMainGeneration { regenerateThenSave() }
        } else {
            HapticManager.shared.success()
            commitSave(soundFileName: editSoundFileName)
        }
    }

    private func regenerateThenSave() {
        alarmAudioPlayer.stop()
        voicePersonaPlayer.stop()
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
        if DevFlags.forceEditRegenerationError {
            // Fake a real-feeling round-trip before throwing so the UI
            // goes through the isRegenerating spinner state.
            try await Task.sleep(for: .milliseconds(800))
            throw APIError.unknown(NSError(
                domain: "DevFlags.forceEditRegenerationError",
                code: -999,
                userInfo: [NSLocalizedDescriptionKey: "Forced failure (dev flag)"]
            ))
        }

        guard let composerService else {
            throw APIError.unknown(NSError(
                domain: "ComposerService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Composer service unavailable"]
            ))
        }

        // `var config = alarm` copies every AlarmConfiguration field,
        // including the pro ones (alarmType, approvedScripts,
        // customPrompt, customPromptIncludes, creativeSnoozes). We then
        // override the fields the edit sheet lets the user mutate. Keep
        // this list in lockstep with `commitSave` — both should see the
        // same final config, otherwise reconcile sees drift that never
        // makes it onto disk (or vice versa).
        var config = alarm
        config.wakeTime = editTime
        config.voicePersona = editVoicePersona
        config.tone = editTone
        config.intensity = editIntensity
        config.whyContext = editWhyContext
        config.leaveTime = editLeaveTime
        config.snoozeInterval = editSnoozeInterval
        config.maxSnoozes = editMaxSnoozes
        // Pro fields — all mutable via the new Pro page.
        config.alarmType = editAlarmType
        config.approvedScripts = editApprovedScripts
        config.customPrompt = editCustomPrompt.isEmpty ? nil : editCustomPrompt
        config.customPromptIncludes = editCustomPromptIncludes
        config.creativeSnoozes = editCreativeSnoozes

        // Pro text refresh — the reconciler only handles time/snooze
        // drift, so if pro text-affecting inputs (prompt, includes,
        // creativeSnoozes, tone, intensity, whyContext) drifted vs the
        // committed alarm, we need a full text regenerate first.
        // Otherwise the audio would be generated using the old scripts.
        if config.alarmType == .pro {
            let proTextDrifted =
                (alarm.customPrompt ?? "") != (config.customPrompt ?? "")
                || alarm.customPromptIncludes != config.customPromptIncludes
                || alarm.creativeSnoozes != config.creativeSnoozes
                || alarm.tone != config.tone
                || alarm.intensity != config.intensity
                || alarm.whyContext != config.whyContext
                || alarm.alarmType != config.alarmType   // flipped basic→pro mid-edit
                || (config.approvedScripts ?? []).isEmpty

            if proTextDrifted {
                let snoozeCount: Int = {
                    guard config.creativeSnoozes else { return 0 }
                    return config.unlimitedSnooze ? 1 : config.maxSnoozes
                }()
                print("[EditAlarm] Pro text drifted — full regenerate (snoozes=\(snoozeCount))")
                let freshScripts = try await composerService.generateCustomAlarmText(
                    draft: config,
                    prompt: config.customPrompt ?? "",
                    includes: config.customPromptIncludes,
                    snoozeCount: snoozeCount,
                    baseScript: nil
                )
                config.approvedScripts = freshScripts
                reconciledApprovedScripts = freshScripts
            } else {
                // No text-affecting drift — let the reconciler handle
                // time/snooze drift with a surgical script update.
                let reconciler = ProScriptReconciler(composer: composerService)
                config = try await reconciler.reconcile(from: alarm, to: config)
                reconciledApprovedScripts = config.approvedScripts
            }
        }

        print("[EditAlarm] Calling composer — voice=\(editVoicePersona?.rawValue ?? "nil"), tone=\(editTone?.rawValue ?? "nil"), intensity=\(editIntensity?.rawValue ?? "nil"), why=\(editWhyContext?.rawValue ?? "nil"), time=\(config.wakeTime?.description ?? "nil"), alarmType=\(config.alarmType.rawValue), approvedCount=\(config.approvedScripts?.count ?? 0)")
        let fileName = try await composerService.generateAndDownloadAudio(for: config)
        // Free users spend one generation on successful audio production.
        // Pro subscribers never count. Single chokepoint shared by both
        // `regenerateAlarm()` and `regenerateThenSave()`.
        if !subscriptionService.isPro {
            proLimitCounter.incrementMain()
        }
        return fileName
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
        updated.name = normalizedEditName.isEmpty ? nil : normalizedEditName
        // Pro fields — persisted from the edit-state.
        updated.alarmType = editAlarmType
        updated.approvedScripts = editApprovedScripts
        updated.customPrompt = editCustomPrompt.isEmpty ? nil : editCustomPrompt
        updated.customPromptIncludes = editCustomPromptIncludes
        updated.creativeSnoozes = editCreativeSnoozes
        updated.liveActivityEnabled = editLiveActivityEnabled
        updated.liveActivityLeadHours = max(1, min(9, editLiveActivityLeadHours))
        // If the regeneration path reconciled the pro scripts (e.g. snooze
        // count changed, or wake time was rewritten), persist those new
        // scripts so the saved config matches the audio files on disk.
        if let reconciledApprovedScripts {
            updated.approvedScripts = reconciledApprovedScripts
        }
        // Basic alarms drop any Pro-only fields left over from an aborted
        // Pro flow so they don't linger in persisted state. Mirrors the
        // behavior in CreateAlarmView's commitSave.
        if updated.alarmType == .basic {
            updated.approvedScripts = nil
            updated.customPrompt = nil
            updated.customPromptIncludes = []
        }

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
        HapticManager.shared.error()
        // Flash the footer button into the "Please try again" state
        // (inline red treatment) for 2.5s — primary signal since toasts
        // can slide behind the sheet. The toast below is a backup.
        triggerRegenerationError()
        alertManager.showToast(
            message: "Something went wrong. Please try again.",
            kind: .failure,
            duration: 3.5
        )
    }

    // MARK: - Data

    private enum EditPage {
        case summary
        case name
        case schedule
        case snooze
        case style
        case liveActivity
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
                        voicePersona: .soothingSarah,
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
