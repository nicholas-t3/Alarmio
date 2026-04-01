//
//  OnboardingTimeView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct OnboardingTimeView: View {

    // MARK: - Environment

    @Environment(OnboardingManager.self) private var manager
    @Environment(\.deviceInfo) private var deviceInfo

    // MARK: - State

    @State private var contentVisible = false
    @State private var wakeTime: Date = {
        var components = DateComponents()
        components.hour = 7
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()

    // MARK: - Constants

    let onReadyForButton: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            Spacer()
                .frame(height: AppSpacing.itemGap(deviceInfo.spacingScale))

            // Header
            Text("When should we\nwake you up?")
                .font(AppTypography.headlineLarge)
                .tracking(AppTypography.headlineLargeTracking)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .premiumBlur(isVisible: contentVisible, duration: 0.4)

            Spacer()
                .frame(height: AppSpacing.sectionGap(deviceInfo.spacingScale))

            // Time picker
            DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .scaleEffect(1.2)
                .blur(radius: contentVisible ? 0 : 8)
                .opacity(contentVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.08), value: contentVisible)
                .onChange(of: wakeTime) {
                    manager.setWakeTime(wakeTime)
                }

            Spacer()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            contentVisible = true
            manager.setWakeTime(wakeTime)

            try? await Task.sleep(for: .milliseconds(500))
            onReadyForButton()
        }
    }
}

#Preview {
    OnboardingContainerView.preview(step: .time)
}
