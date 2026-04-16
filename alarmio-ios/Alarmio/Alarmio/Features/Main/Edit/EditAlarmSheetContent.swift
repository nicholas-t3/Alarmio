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
        context.maxDetentValue * 0.65
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
        // Seed the snapshot so on-open state is considered clean (Save,
        // not Regenerate). A nil snapshot would always read as dirty vs
        // any non-nil draft snapshot.
        _editProPreviewSnapshot = State(initialValue: ProPreviewInputs(
            prompt: alarm.customPrompt ?? "",
            includes: alarm.customPromptIncludes,
            creativeSnoozes: alarm.creativeSnoozes,
            leaveTime: alarm.leaveTime,
            maxSnoozes: alarm.maxSnoozes,
            unlimitedSnooze: false
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
    @State private var voicePlayer = VoicePreviewPlayer()
    @State private var voiceIndex: Int
    @State private var isRegenerating = false
    @State private var audioRegeneratedForCurrentEdits = false
    /// Reconciled approvedScripts from the last regeneration. Nil means
    /// either this is a basic alarm or reconcile hasn't run yet. When
    /// non-nil, `commitSave` uses these instead of the original alarm's
    /// scripts so the persisted config matches the audio on disk.
    @State private var reconciledApprovedScripts: [String]?
    @State private var showSaveSuccess = false
    @State private var saveSuccessTask: Task<Void, Never>?

    // Pro fields — editable when the alarm is (or becomes) a pro alarm.
    @State private var editAlarmType: AlarmType
    @State private var editApprovedScripts: [String]?
    @State private var editCustomPrompt: String
    @State private var editCustomPromptIncludes: Set<CustomPromptInclude>
    @State private var editCreativeSnoozes: Bool
    /// Pro preview scratchpad used while the user is on the .proPrompt
    /// page. Mirrors `proPreviewScripts` in CreateAlarmView.
    @State private var editProPreviewScripts: [String]?
    @State private var editProPreviewIsGenerating: Bool = false
    @State private var editProPreviewError: String?
    @State private var editProPreviewSnapshot: ProPreviewInputs?
    /// Tracks whether the user pressed Save during the current visit to
    /// the .proPrompt page. Reset on entry; consulted on back to decide
    /// whether to revert the pro-related edits to their pre-entry values.
    @State private var proEditDidSaveThisVisit: Bool = false
    /// Snapshot of all pro-editable fields taken on entry to the Pro page,
    /// so back-without-save can revert the lot. The Pro page edits these
    /// through bindings, so writes land immediately — the revert is how
    /// we get "back throws away changes" semantics.
    @State private var proEditRestore: ProEditRestore?

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
            || normalizedEditName != (alarm.name ?? "")
            || hasProChanges
    }

    private var normalizedEditName: String {
        editName.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private var hasProChanges: Bool {
        editAlarmType != alarm.alarmType
            || editApprovedScripts != alarm.approvedScripts
            || editCustomPrompt != (alarm.customPrompt ?? "")
            || editCustomPromptIncludes != alarm.customPromptIncludes
            || editCreativeSnoozes != alarm.creativeSnoozes
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
        case .name: return Self.compactDetent
        case .schedule: return Self.detailDetent
        case .snooze: return Self.compactDetent
        case .style: return Self.fullDetent
        case .proPrompt: return Self.fullDetent
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
                    case .proPrompt:
                        proPromptPage
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
        .onChange(of: editAlarmType) { invalidateRegenerationFlag() }
        .onChange(of: editApprovedScripts) { invalidateRegenerationFlag() }
        .onChange(of: editCustomPrompt) { invalidateRegenerationFlag() }
        .onChange(of: editCustomPromptIncludes) { invalidateRegenerationFlag() }
        .onChange(of: editCreativeSnoozes) { invalidateRegenerationFlag() }
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
                label: "Name",
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

                // Customize card (tone / reason / intensity / Pro)
                CustomizeCard(
                    tone: $editTone,
                    whyContext: $editWhyContext,
                    intensity: $editIntensity,
                    isProOn: Binding(
                        get: { editAlarmType == .pro },
                        set: { newValue in
                            editAlarmType = newValue ? .pro : .basic
                        }
                    ),
                    showProRow: true,
                    proCustomized: (editApprovedScripts ?? []).isEmpty == false,
                    onTapProRow: handleEditTapProRow,
                    onFlipProOn: handleEditFlipProOn,
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

    // MARK: - Pro Prompt Page

    private var proPromptPage: some View {
        VStack(spacing: 0) {

            // Back row — reverts editAlarmType if not saved, then returns
            // to the style page (not the summary).
            HStack {
                Button {
                    if !proEditDidSaveThisVisit {
                        editAlarmType = proEditOriginalAlarmType
                    }
                    navigateTo(.style)
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
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 12)

            // Pro editor — reuses the same component as CreateAlarmView's
            // .proPrompt step. Hardcoded cardsVisible=true because the edit
            // sheet's blur system runs at the page level, not per card.
            ProPromptView(
                prompt: Binding(
                    get: { editCustomPrompt },
                    set: { editCustomPrompt = $0 }
                ),
                includes: $editCustomPromptIncludes,
                leaveTime: $editLeaveTime,
                creativeSnoozes: $editCreativeSnoozes,
                wakeTime: editTime,
                cardsVisible: true,
                generated: editProPreviewScripts?.first,
                isGenerating: editProPreviewIsGenerating,
                errorMessage: editProPreviewError,
                onPromptChange: { /* dirty-check handled by the Save button */ }
            )

            // Bottom bar — Generate Text / spinner / Save, same 3-state
            // pattern as CreateAlarmView's proPromptBottomBar.
            proPromptBottomBar
                .padding(.horizontal, AppButtons.horizontalPadding)
                .padding(.bottom, AppSpacing.screenBottom)
        }
    }

    @ViewBuilder
    private var proPromptBottomBar: some View {
        let hasResult = !(editProPreviewScripts?.isEmpty ?? true)
        let promptText = editCustomPrompt
        let canGenerate = !editProPreviewIsGenerating
            && !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let draftSnapshot = proPreviewDraftSnapshot()
        let isDirty = hasResult && editProPreviewSnapshot != draftSnapshot
        let label: String = {
            if editProPreviewIsGenerating { return "" }
            if hasResult { return isDirty ? "Regenerate" : "Save" }
            return "Generate Text"
        }()

        // Is the current preview already saved to the alarm config? If
        // yes AND inputs are clean, there's nothing to do — disable the
        // button so the user just taps Back.
        let alreadyPersisted = editProPreviewScripts == editApprovedScripts
        let cleanAndPersisted = hasResult && !isDirty && alreadyPersisted
        // Tappable only when there's actual work: dirty inputs mean
        // regenerate, clean-but-unsaved means commit the new scripts.
        let tappable = !editProPreviewIsGenerating
            && !cleanAndPersisted
            && (isDirty || canGenerate || (hasResult && !alreadyPersisted))

        Button {
            if !tappable { return }
            if hasResult && !isDirty && !alreadyPersisted {
                HapticManager.shared.success()
                editApprovedScripts = editProPreviewScripts
                editAlarmType = .pro
                proEditDidSaveThisVisit = true
                invalidateRegenerationFlag()
                navigateTo(.style)
            } else {
                HapticManager.shared.buttonTap()
                Task { await runEditProPreview() }
            }
        } label: {
            ZStack {
                if editProPreviewIsGenerating {
                    ProgressView().tint(.black).transition(.opacity)
                } else {
                    Text(label).contentTransition(.numericText()).transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: editProPreviewIsGenerating)
            .animation(.easeInOut(duration: 0.25), value: label)
        }
        .primaryButton(isEnabled: tappable)
        .disabled(!tappable)
    }

    /// Builds a CreateAlarmView.ProPreviewInputs snapshot from the current
    /// edit-state values. Used to detect dirtiness against
    /// `editProPreviewSnapshot` (set when the user last generated).
    private func proPreviewDraftSnapshot() -> ProPreviewInputs {
        ProPreviewInputs(
            prompt: editCustomPrompt,
            includes: editCustomPromptIncludes,
            creativeSnoozes: editCreativeSnoozes,
            leaveTime: editLeaveTime,
            maxSnoozes: editMaxSnoozes,
            unlimitedSnooze: false
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

    // MARK: - Pro Row Handlers

    /// Tapping the Pro row (not the toggle). Only navigates when Pro is
    /// already on — same contract as CreateAlarmView.
    private func handleEditTapProRow() {
        proEditDidSaveThisVisit = true
        proEditOriginalAlarmType = editAlarmType
        navigateTo(.proPrompt)
    }

    /// Toggling Pro on via the switch. Auto-navigates to the Pro page so
    /// the user can fill out their prompt without a second tap.
    private func handleEditFlipProOn() {
        proEditDidSaveThisVisit = false
        proEditOriginalAlarmType = .basic  // we know they just flipped from basic → pro
        navigateTo(.proPrompt)
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

        // Reconcile pro scripts against any edit-sheet drift (snooze count,
        // wake/leave time). Silent update of `approvedScripts`. No-op for
        // basic alarms. Stash the result so `commitSave` persists the same
        // scripts that produced the audio we're about to generate.
        if config.alarmType == .pro {
            let reconciler = ProScriptReconciler(composer: composerService)
            config = try await reconciler.reconcile(from: alarm, to: config)
            reconciledApprovedScripts = config.approvedScripts
        }

        print("[EditAlarm] Calling composer — voice=\(editVoicePersona?.rawValue ?? "nil"), tone=\(editTone?.rawValue ?? "nil"), intensity=\(editIntensity?.rawValue ?? "nil"), why=\(editWhyContext?.rawValue ?? "nil"), time=\(config.wakeTime?.description ?? "nil"), alarmType=\(config.alarmType.rawValue), approvedCount=\(config.approvedScripts?.count ?? 0)")
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
        updated.name = normalizedEditName.isEmpty ? nil : normalizedEditName
        // Pro fields — persisted from the edit-state.
        updated.alarmType = editAlarmType
        updated.approvedScripts = editApprovedScripts
        updated.customPrompt = editCustomPrompt.isEmpty ? nil : editCustomPrompt
        updated.customPromptIncludes = editCustomPromptIncludes
        updated.creativeSnoozes = editCreativeSnoozes
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
        case name
        case schedule
        case snooze
        case style
        case proPrompt
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
