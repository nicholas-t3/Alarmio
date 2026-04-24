//
//  VolumeTipCard.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/23/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct VolumeTipCard: View {

    // MARK: - Environment

    @Environment(\.alertManager) private var alertManager

    // MARK: - State

    let onDismiss: () -> Void

    // MARK: - Body

    var body: some View {
        Button {
            HapticManager.shared.softTap()
            presentVolumeGuide()
        } label: {
            HStack(spacing: 14) {

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 40, height: 40)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }

                // Copy
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alarm too quiet?")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Tap to adjust")
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Private Methods

    private func presentVolumeGuide() {
        alertManager.showModal(
            title: "Alarm Volume",
            message: """
                1. Open Settings, then tap Sounds & Haptics.
                2. Drag the "Ringtone and Alert Volume" slider to your desired volume.

                Silent mode and Focus modes don't silence Alarmio — it will always ring.
                """,
            dismissible: true,
            primaryAction: AlertAction(label: "Got It") {},
            onDismiss: onDismiss
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VolumeTipCard(onDismiss: {})
            .padding()
    }
}
