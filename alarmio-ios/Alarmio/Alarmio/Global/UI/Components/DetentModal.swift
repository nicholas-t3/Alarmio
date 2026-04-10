//
//  DetentModal.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/10/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

// MARK: - Detent Step

struct DetentStep: Equatable, Sendable {
    let height: CGFloat
    let id: String

    init(_ height: CGFloat, id: String = UUID().uuidString) {
        self.height = height
        self.id = id
    }

    static func == (lhs: DetentStep, rhs: DetentStep) -> Bool {
        lhs.id == rhs.id && lhs.height == rhs.height
    }
}

// MARK: - Detent Modal

struct DetentModal<Content: View>: View {

    // MARK: - Bindings

    @Binding var currentStep: DetentStep

    // MARK: - State

    @State private var displayedHeight: CGFloat = 0

    // MARK: - Constants

    let minimumHeight: CGFloat
    let content: () -> Content

    init(
        currentStep: Binding<DetentStep>,
        minimumHeight: CGFloat = 200,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._currentStep = currentStep
        self.minimumHeight = minimumHeight
        self.content = content
    }

    // MARK: - Computed Properties

    private var effectiveHeight: CGFloat {
        max(minimumHeight, displayedHeight)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            Spacer()

            // Modal container
            VStack(spacing: 0) {

                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // Content area
                ZStack {
                    content()
                }
                .frame(maxWidth: .infinity)
                .frame(height: effectiveHeight - 25, alignment: .top)
                .clipped()
            }
            .frame(height: effectiveHeight)
            .background(modalBackground)
            .mask(modalShape)
            .padding(.horizontal, 16)
        }
        .onChange(of: currentStep) { _, newStep in
            transitionTo(newStep)
        }
        .onAppear {
            displayedHeight = currentStep.height
        }
    }

    // MARK: - Subviews

    private var modalBackground: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 45,
                bottomTrailingRadius: 45,
                topTrailingRadius: 20
            )
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)

            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 45,
                bottomTrailingRadius: 45,
                topTrailingRadius: 20
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "060e1c").opacity(0.75),
                        Color(hex: "111d35").opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 45,
                bottomTrailingRadius: 45,
                topTrailingRadius: 20
            )
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.25), .white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
    }

    private var modalShape: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 20,
            bottomLeadingRadius: 45,
            bottomTrailingRadius: 45,
            topTrailingRadius: 20
        )
    }

    // MARK: - Private Methods

    private func transitionTo(_ step: DetentStep) {
        _ = withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            displayedHeight = step.height
        }
    }
}

// MARK: - Preview

private let previewStepOne = DetentStep(440, id: "step-one")
private let previewStepTwo = DetentStep(520, id: "step-two")

#Preview {
    struct PreviewContainer: View {

        @State private var currentStep = previewStepOne
        @State private var targetPage = 0
        @State private var visiblePage = 0
        @State private var contentRevealed = true

        var body: some View {
            ZStack {

                // Background
                NightSkyBackground()

                // Modal
                DetentModal(currentStep: $currentStep, minimumHeight: 200) {
                    ZStack {
                        if visiblePage == 0 {
                            pageOne
                        } else {
                            pageTwo
                        }
                    }
                    .premiumBlur(
                        isVisible: contentRevealed,
                        duration: 0.2,
                        disableScale: true,
                        disableOffset: true
                    )
                }
            }
            .onChange(of: targetPage) { _, newPage in
                // Phase 1: blur out current content
                contentRevealed = false

                // Phase 2: swap page + animate height while blurred
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    visiblePage = newPage
                    currentStep = newPage == 0 ? previewStepOne : previewStepTwo
                }

                // Phase 3: reveal new content after height settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    contentRevealed = true
                }
            }
        }

        // MARK: - Pages

        private var pageOne: some View {
            VStack(spacing: 24) {

                Text("STEP ONE")
                    .font(AppTypography.headlineMedium)
                    .tracking(AppTypography.headlineMediumTracking)
                    .foregroundStyle(.white.opacity(0.9))

                Text("A compact first step.\nChoose something to continue.")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                // Liquid glass box
                VStack(spacing: 12) {
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.white.opacity(0.7))

                    Text("Preview")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))

                // Next button
                Button {
                    targetPage = 1
                } label: {
                    Text("Next")
                }
                .primaryButton()
                .padding(.top, 8)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 24)
            .padding(.bottom, 50)
        }

        private var pageTwo: some View {
            VStack(spacing: 20) {

                // Back row
                HStack {
                    Button {
                        targetPage = 0
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

                Text("STEP TWO")
                    .font(AppTypography.headlineMedium)
                    .tracking(AppTypography.headlineMediumTracking)
                    .foregroundStyle(.white.opacity(0.9))

                Text("More room here for content.")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(.white.opacity(0.5))

                // Grid of placeholder boxes
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(0..<4) { i in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.06))
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            )
                            .overlay(
                                Text("Option \(i + 1)")
                                    .font(AppTypography.labelSmall)
                                    .foregroundStyle(.white.opacity(0.4))
                            )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 16)
            .padding(.bottom, 50)
        }
    }

    return PreviewContainer()
}
