//
//  LeaveTimePicker.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/16/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct LeaveTimePicker: View {

    // MARK: - Bindings

    @Binding var leaveTime: Date?

    // MARK: - Constants

    let wakeTime: Date?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {

            // Help text
            Text("Your alarm will use this to let you know how much time you have before you need to leave.")
                .font(AppTypography.labelSmall)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            // Stepper
            HStack(spacing: 16) {
                Button {
                    HapticManager.shared.selection()
                    adjustLeaveTime(minutes: -5)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }

                HStack(spacing: 6) {
                    Text(clockString)
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    if let period = periodString {
                        Text(period)
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(.white.opacity(0.7))
                            .contentTransition(.numericText())
                    }
                }
                .frame(width: 110)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: leaveTime)

                Button {
                    HapticManager.shared.selection()
                    adjustLeaveTime(minutes: 5)
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
    }

    // MARK: - Private Methods

    private var clockString: String {
        let date = leaveTime ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("jm")
        let full = formatter.string(from: date)
        let am = formatter.amSymbol ?? ""
        let pm = formatter.pmSymbol ?? ""
        return full
            .replacingOccurrences(of: am, with: "")
            .replacingOccurrences(of: pm, with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private var periodString: String? {
        let date = leaveTime ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("jm")
        let full = formatter.string(from: date)
        let am = formatter.amSymbol ?? ""
        let pm = formatter.pmSymbol ?? ""
        if !am.isEmpty, full.contains(am) { return am }
        if !pm.isEmpty, full.contains(pm) { return pm }
        return nil
    }

    private func adjustLeaveTime(minutes: Int) {
        guard let current = leaveTime else { return }
        guard let wake = wakeTime else {
            leaveTime = current.addingTimeInterval(TimeInterval(minutes * 60))
            return
        }
        let proposed = current.addingTimeInterval(TimeInterval(minutes * 60))
        let minAllowed = wake
        let maxAllowed = wake.addingTimeInterval(60 * 60 * 12)
        leaveTime = min(max(proposed, minAllowed), maxAllowed)
    }

    // MARK: - Static Helpers

    static func defaultLeaveTime(wakeTime: Date?) -> Date {
        let base = wakeTime ?? Date()
        let oneHourLater = base.addingTimeInterval(60 * 60)
        return roundToFiveMinutes(oneHourLater)
    }

    private static func roundToFiveMinutes(_ date: Date) -> Date {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        let rounded = Int((Double(minute) / 5.0).rounded()) * 5
        let delta = rounded - minute
        return calendar.date(byAdding: .minute, value: delta, to: date) ?? date
    }
}

// MARK: - Previews

#Preview {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        LeaveTimePicker(
            leaveTime: .constant(Calendar.current.date(from: DateComponents(hour: 8, minute: 30))),
            wakeTime: Calendar.current.date(from: DateComponents(hour: 7, minute: 0))
        )
        .padding(24)
    }
}
