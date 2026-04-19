//
//  CompactPlayableVoiceCard.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/19/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

/// Compact voice selector with an inline Play/Stop capsule. Used in
/// `CreateAlarmView` step 2 when Pro mode is on — the Pro inputs take up
/// more vertical space, so the big `voiceHeroCard` is swapped for this
/// tighter row. Voice info sits on the left; prev / play / next controls
/// line up on the right. Matches the 40pt Play capsule used by the
/// confirmation screen's alarm-preview card so the Play affordance feels
/// consistent across the flow.
struct CompactPlayableVoiceCard: View {

    // MARK: - Constants

    let voice: HeroVoice
    let isPlayingThis: Bool
    let onPrev: () -> Void
    let onNext: () -> Void
    let onTogglePlay: () -> Void
    /// Glass tint — `.standard` (clear) in the create flow, `.edit`
    /// (dark blue tint) inside the edit sheet so it matches the rest of
    /// the edit surfaces.
    var mode: CardMode = .standard

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {

            // Section label — centered to match CustomizeCard's header.
            Text("VOICE")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity)

            // Voice info (left) + prev / play / next (right)
            HStack(spacing: 10) {

                // Voice info
                VStack(alignment: .leading, spacing: 2) {
                    Text(voice.name)
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(voice.descriptor)
                        .font(AppTypography.caption)
                        .foregroundStyle(.white.opacity(0.35))
                        .contentTransition(.numericText())
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: voice.persona)

                Spacer(minLength: 8)

                // Prev
                Button {
                    HapticManager.shared.selection()
                    onPrev()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }

                // Play / Stop — icon-only. Same 40pt height as the
                // confirmation screen's alarm-preview capsule so the Play
                // affordance feels consistent across the flow.
                Button {
                    HapticManager.shared.buttonTap()
                    onTogglePlay()
                } label: {
                    Image(systemName: isPlayingThis ? "stop.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPlayingThis)

                // Next
                Button {
                    HapticManager.shared.selection()
                    onNext()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .modifier(CardGlassModifier(mode: mode))
    }
}

// MARK: - Previews

#Preview("Stopped") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        CompactPlayableVoiceCard(
            voice: VoiceCatalog.all.first!,
            isPlayingThis: false,
            onPrev: {},
            onNext: {},
            onTogglePlay: {}
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("Playing") {
    ZStack {
        Color(hex: "050505").ignoresSafeArea()
        CompactPlayableVoiceCard(
            voice: VoiceCatalog.all.first!,
            isPlayingThis: true,
            onPrev: {},
            onNext: {},
            onTogglePlay: {}
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

#Preview("Edit Mode") {
    ZStack {
        Color(hex: "0f1a2e").ignoresSafeArea()
        CompactPlayableVoiceCard(
            voice: VoiceCatalog.all.first!,
            isPlayingThis: false,
            onPrev: {},
            onNext: {},
            onTogglePlay: {},
            mode: .edit
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}
