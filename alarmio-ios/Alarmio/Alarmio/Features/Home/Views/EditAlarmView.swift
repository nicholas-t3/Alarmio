//
//  EditAlarmView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/3/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct EditAlarmView: View {

    // MARK: - Environment

    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - State

    @Binding var alarm: AlarmConfiguration
    let onSave: () -> Void
    @State private var editDays: Set<Int> = []
    @State private var editTime: Date = Date()
    @State private var editSnoozeCount: Int = 3
    @State private var editSnoozeInterval: Int = 5

    // MARK: - Body

    var body: some View {
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
        .onAppear {
            editTime = alarm.wakeTime ?? Date()
            editDays = Set(alarm.repeatDays ?? [])
            editSnoozeCount = alarm.snoozeCount
            editSnoozeInterval = alarm.snoozeInterval
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
                .onChange(of: editTime) { _, newTime in
                    alarm.wakeTime = newTime
                }
        }
    }

    private var daySection: some View {
        VStack(spacing: 10) {
            Text("REPEAT")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            DayPicker(selectedDays: $editDays)
                .onChange(of: editDays) { _, newDays in
                    alarm.repeatDays = newDays.isEmpty ? nil : Array(newDays).sorted()
                }

            Text(scheduleSummary)
                .font(AppTypography.bodySmall)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var snoozeSection: some View {
        VStack(spacing: 14) {
            Text("SNOOZE")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))

            // Count
            HStack {
                Text("Times")
                    .font(AppTypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        HapticManager.shared.selection()
                        editSnoozeCount = max(0, editSnoozeCount - 1)
                        alarm.snoozeCount = editSnoozeCount
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.1))
                            .clipShape(Circle())
                    }

                    Text(editSnoozeCount == 0 ? "Off" : "\(editSnoozeCount)")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white)
                        .frame(width: 32)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editSnoozeCount)

                    Button {
                        HapticManager.shared.selection()
                        editSnoozeCount = min(10, editSnoozeCount + 1)
                        alarm.snoozeCount = editSnoozeCount
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

            // Interval
            if editSnoozeCount > 0 {
                HStack {
                    Text("Interval")
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            HapticManager.shared.selection()
                            editSnoozeInterval = max(1, editSnoozeInterval - 1)
                            alarm.snoozeInterval = editSnoozeInterval
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.white.opacity(0.1))
                                .clipShape(Circle())
                        }

                        Text("\(editSnoozeInterval)m")
                            .font(AppTypography.labelLarge)
                            .foregroundStyle(.white)
                            .frame(width: 40)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editSnoozeInterval)

                        Button {
                            HapticManager.shared.selection()
                            editSnoozeInterval = min(15, editSnoozeInterval + 1)
                            alarm.snoozeInterval = editSnoozeInterval
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
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeOut(duration: 0.25), value: editSnoozeCount)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {

            // Preview
            Button {
                HapticManager.shared.softTap()
                // TODO: Play audio preview
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                    Text("Preview")
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
                onSave()
            } label: {
                Text("Save")
            }
            .primaryButton()
        }
    }

    // MARK: - Private Methods

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
        @State private var alarm = AlarmConfiguration(
            isEnabled: true,
            wakeTime: Calendar.current.date(from: DateComponents(hour: 7, minute: 0)),
            repeatDays: [1, 2, 3, 4, 5],
            tone: .calm,
            voicePersona: .calmGuide,
            snoozeCount: 3,
            snoozeInterval: 5
        )

        var body: some View {
            ZStack {
                MorningSky(starOpacity: 0.8, showConstellations: false)

                MotionModal(isPresented: $showEdit, dismissible: true) {
                    EditAlarmView(alarm: $alarm, onSave: { showEdit = false })
                }
            }
        }
    }

    return PreviewContainer()
}

#Preview("Edit Alarm Content") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        EditAlarmView(alarm: .constant(AlarmConfiguration(
            wakeTime: Calendar.current.date(from: DateComponents(hour: 6, minute: 30)),
            repeatDays: [1, 2, 3, 4, 5],
            snoozeCount: 2,
            snoozeInterval: 10
        )), onSave: {})
    }
}
