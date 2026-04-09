//
//  EditAlarmView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/3/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import AVFoundation
import SwiftUI

struct EditAlarmView: View {

    // MARK: - Environment

    @Environment(\.deviceInfo) private var deviceInfo
    @Environment(\.alarmStore) private var alarmStore

    // MARK: - Constants

    let alarm: AlarmConfiguration
    let onSave: (AlarmConfiguration) -> Void
    var onDelete: (() -> Void)?

    // MARK: - State

    @State private var editDays: Set<Int> = []
    @State private var editTime: Date = Date()
    @State private var editSnoozeInterval: Int = 5
    @State private var editMaxSnoozes: Int = 3
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPreviewPlaying = false

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {

                // Time picker
                timeSection

            // Day picker
            daySection
                .padding(.bottom, 24)

            // Snooze
            snoozeSection
                .padding(.bottom, 28)

            // Action buttons
            actionButtons
                .padding(.bottom, 8)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, 20)

            // Delete button — floats at top-right, level with drag handle
            if onDelete != nil {
                Button {
                    HapticManager.shared.warning()
                    onDelete?()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.red.opacity(0.6))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .padding(.top, -8)
                .padding(.trailing, 8)
            }
        }
        .onAppear {
            editTime = alarm.wakeTime ?? Date()
            editDays = Set(alarm.repeatDays ?? [])
            editSnoozeInterval = alarm.snoozeInterval
            editMaxSnoozes = alarm.maxSnoozes
        }
    }

    // MARK: - Subviews

    private var timeSection: some View {
        VStack(spacing: 0) {
            Text("WAKE TIME")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            DatePicker("", selection: $editTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
        }
    }

    private var daySection: some View {
        VStack(spacing: 10) {
            Text("REPEAT")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            DayPicker(selectedDays: $editDays)

            Text(scheduleSummary)
                .font(AppTypography.bodySmall)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var snoozeSection: some View {
        VStack(spacing: 14) {

            // Section label
            Text("SNOOZE")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Snooze count stepper — always visible
            snoozeCountRow

            // Interval stepper — only when count > 0
            if editMaxSnoozes > 0 {
                snoozeIntervalRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: editMaxSnoozes)
    }

    private var snoozeCountRow: some View {
        HStack(spacing: 16) {
            Button {
                HapticManager.shared.selection()
                editMaxSnoozes = max(0, editMaxSnoozes - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }

            HStack(spacing: 6) {
                if editMaxSnoozes == 0 {
                    Text("No snooze")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.numericText())
                } else {
                    Text("\(editMaxSnoozes)")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(editMaxSnoozes == 1 ? "snooze" : "snoozes")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white.opacity(0.7))
                        .contentTransition(.numericText())
                }
            }
            .frame(width: Self.snoozeStepperLabelWidth)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editMaxSnoozes)

            Button {
                HapticManager.shared.selection()
                editMaxSnoozes = min(3, editMaxSnoozes + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    private var snoozeIntervalRow: some View {
        HStack(spacing: 16) {
            Button {
                HapticManager.shared.selection()
                editSnoozeInterval = max(1, editSnoozeInterval - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }

            HStack(spacing: 6) {
                Text("\(editSnoozeInterval)")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(editSnoozeInterval == 1 ? "minute" : "minutes")
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.7))
                    .contentTransition(.numericText())
            }
            .frame(width: Self.snoozeStepperLabelWidth)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editSnoozeInterval)

            Button {
                HapticManager.shared.selection()
                editSnoozeInterval = min(15, editSnoozeInterval + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    /// Fixed width for the center label of both snooze stepper rows, so the
    /// plus/minus buttons align vertically across rows regardless of which
    /// text ("No snooze" vs "15 minutes") is currently showing.
    private static let snoozeStepperLabelWidth: CGFloat = 110

    private var actionButtons: some View {
        VStack(spacing: 10) {

            // Preview
            Button {
                HapticManager.shared.softTap()
                togglePreview()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isPreviewPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 14))
                        .contentTransition(.symbolEffect(.replace))
                    Text(isPreviewPlaying ? "Stop" : "Preview")
                        .font(.system(size: 15, weight: .semibold))
                        .tracking(0.3)
                }
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(.white.opacity(0.08))
                .clipShape(Capsule())
            }

            // Save
            Button {
                HapticManager.shared.success()
                var updated = alarm
                updated.wakeTime = editTime
                updated.repeatDays = editDays.isEmpty ? nil : Array(editDays).sorted()
                updated.snoozeInterval = editSnoozeInterval
                updated.maxSnoozes = editMaxSnoozes
                onSave(updated)
            } label: {
                Text("Save")
            }
            .primaryButton()
        }
    }

    // MARK: - Private Methods

    private func togglePreview() {
        if isPreviewPlaying {
            audioPlayer?.stop()
            isPreviewPlaying = false
            return
        }

        let audioManager = alarmStore.audioFileManager

        // Only preview if this alarm has a custom sound file
        guard audioManager.hasCustomSound(for: alarm.id) || alarm.soundFileName != nil else {
            // No custom sound — this alarm uses the system default, nothing to preview
            HapticManager.shared.warning()
            return
        }

        let soundName = audioManager.soundFileName(for: alarm.id, configured: alarm.soundFileName)
        let soundsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds")
        let fileURL = soundsDir.appendingPathComponent(soundName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.play()
            audioPlayer = player
            isPreviewPlaying = true

            Task {
                try? await Task.sleep(for: .seconds(player.duration + 0.1))
                if isPreviewPlaying {
                    isPreviewPlaying = false
                }
            }
        } catch {
            print("[EditAlarmView] Playback error: \(error)")
        }
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
            return "\(editDays.count) days per week"
        }
    }
}

// MARK: - Previews

#Preview("Edit Alarm Modal") {
    struct PreviewContainer: View {
        @State private var showEdit = true

        var body: some View {
            ZStack {
                MorningSky(starOpacity: 0.8, showConstellations: false)

                MotionModal(isPresented: $showEdit, dismissible: true) {
                    EditAlarmView(
                        alarm: AlarmConfiguration(
                            isEnabled: true,
                            wakeTime: Calendar.current.date(from: DateComponents(hour: 7, minute: 0)),
                            repeatDays: [1, 2, 3, 4, 5],
                            tone: .calm,
                            voicePersona: .calmGuide,
                            snoozeInterval: 5
                        ),
                        onSave: { _ in showEdit = false }
                    )
                }
            }
        }
    }

    return PreviewContainer()
}

#Preview("Edit Alarm Content") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        EditAlarmView(
            alarm: AlarmConfiguration(
                wakeTime: Calendar.current.date(from: DateComponents(hour: 6, minute: 30)),
                repeatDays: [1, 2, 3, 4, 5],
                snoozeInterval: 10
            ),
            onSave: { _ in }
        )
    }
}
