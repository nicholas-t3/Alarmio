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

    @Binding var isPresented: Bool
    @Binding var currentStep: DetentStep

    // MARK: - State

    @State private var displayedHeight: CGFloat = 0
    @State private var offset: CGFloat = 1000
    @State private var dragOffset: CGFloat = 0
    @State private var contentOpacity: Double = 0

    // MARK: - Constants

    let minimumHeight: CGFloat
    let dismissible: Bool
    let content: () -> Content

    init(
        isPresented: Binding<Bool>,
        currentStep: Binding<DetentStep>,
        minimumHeight: CGFloat = 200,
        dismissible: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self._currentStep = currentStep
        self.minimumHeight = minimumHeight
        self.dismissible = dismissible
        self.content = content
    }

    // MARK: - Computed Properties

    private var effectiveHeight: CGFloat {
        max(minimumHeight, displayedHeight)
    }

    private var totalOffset: CGFloat {
        offset + dragOffset
    }

    private var presentationProgress: CGFloat {
        max(0, min(1, 1 - (totalOffset / 600)))
    }

    private var backgroundOpacity: Double {
        Double(presentationProgress) * 0.45
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {

                // Dimmed background
                if isPresented || backgroundOpacity > 0 {
                    Color.black
                        .opacity(backgroundOpacity)
                        .ignoresSafeArea()
                        .onTapGesture {
                            if dismissible { dismiss(screenHeight: geometry.size.height) }
                        }
                }

                // Modal
                VStack {

                    Spacer()

                    VStack(spacing: 0) {

                        // Drag handle
                        if dismissible {
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 36, height: 5)
                                .padding(.top, 12)
                                .padding(.bottom, 8)
                        } else {
                            Spacer().frame(height: 20)
                        }

                        // Content area
                        ZStack {
                            content()
                                .opacity(contentOpacity)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: effectiveHeight - 25, alignment: .top)
                        .clipped()
                    }
                    .frame(width: geometry.size.width - 32)
                    .frame(height: effectiveHeight)
                    .background(modalBackground)
                    .mask(modalShape)
                    .offset(y: totalOffset)
                    .gesture(dragGesture(screenHeight: geometry.size.height))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: displayedHeight)
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    displayedHeight = currentStep.height
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        offset = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            contentOpacity = 1
                        }
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.15)) {
                        contentOpacity = 0
                    }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                        offset = geometry.size.height
                    }
                }
            }
            .onChange(of: currentStep) { _, newStep in
                _ = withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    displayedHeight = newStep.height
                }
            }
            .onAppear {
                if isPresented {
                    displayedHeight = currentStep.height
                    offset = geometry.size.height
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            offset = 0
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            contentOpacity = 1
                        }
                    }
                } else {
                    offset = geometry.size.height
                }
            }
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

    // MARK: - Gestures

    private func dragGesture(screenHeight: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard dismissible else { return }
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                guard dismissible else { return }
                let velocity = value.predictedEndTranslation.height - value.translation.height
                let threshold: CGFloat = 100
                let velocityThreshold: CGFloat = 500

                if value.translation.height > threshold || velocity > velocityThreshold {
                    offset += dragOffset
                    dragOffset = 0
                    dismiss(screenHeight: screenHeight)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Private Methods

    private func dismiss(screenHeight: CGFloat) {
        withAnimation(.easeOut(duration: 0.15)) {
            contentOpacity = 0
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            offset = screenHeight
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isPresented = false
            dragOffset = 0
        }
    }
}

// MARK: - Container

private struct DetentModalContainer<Base: View, ModalContent: View>: View {

    let base: Base
    @Binding var isPresented: Bool
    @Binding var currentStep: DetentStep
    let dismissible: Bool
    @ViewBuilder let modalContent: () -> ModalContent

    @State private var modalProgress: CGFloat = 0
    @State private var isInViewTree = false
    @State private var modalBinding = false

    var body: some View {
        ZStack {
            base
                .overlay {
                    UIKitBlurView(style: .systemUltraThinMaterial, intensity: modalBinding ? 0.3 : 0)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .animation(.easeOut(duration: 0.3), value: modalBinding)
                }

            if isInViewTree {
                DetentModal(
                    isPresented: $modalBinding,
                    currentStep: $currentStep,
                    dismissible: dismissible,
                    content: modalContent
                )
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                isInViewTree = true
                modalBinding = true
            } else {
                modalBinding = false
            }
        }
        .onChange(of: modalBinding) { _, newValue in
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInViewTree = false
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - View Extension

extension View {
    func detentModal<Content: View>(
        isPresented: Binding<Bool>,
        currentStep: Binding<DetentStep>,
        dismissible: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DetentModalContainer(
            base: self,
            isPresented: isPresented,
            currentStep: currentStep,
            dismissible: dismissible,
            modalContent: content
        )
    }
}

// MARK: - Preview

private let previewStepOne = DetentStep(360, id: "step-one")
private let previewStepTwo = DetentStep(500, id: "step-two")
private let previewStepSchedule = DetentStep(560, id: "step-schedule")

#Preview {
    struct PreviewContainer: View {

        @State private var showModal = true
        @State private var currentStep = previewStepOne
        @State private var targetPage = 0
        @State private var visiblePage = 0
        @State private var contentRevealed = true
        @State private var wakeTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5]

        private var timeString: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: wakeTime)
        }

        private var scheduleSummary: String {
            if selectedDays.isEmpty {
                return "One-time alarm"
            } else if selectedDays == Set([1, 2, 3, 4, 5]) {
                return "Weekdays"
            } else if selectedDays == Set([0, 6]) {
                return "Weekends"
            } else if selectedDays.count == 7 {
                return "Every day"
            } else {
                return "\(selectedDays.count) days per week"
            }
        }

        private func stepForPage(_ page: Int) -> DetentStep {
            switch page {
            case 0: return previewStepOne
            case 1: return previewStepTwo
            case 2: return previewStepSchedule
            default: return previewStepOne
            }
        }

        var body: some View {
            ZStack {

                // Background
                NightSkyBackground()

                // Reopen button (visible when modal dismissed)
                if !showModal {
                    Button {
                        targetPage = 0
                        visiblePage = 0
                        currentStep = previewStepOne
                        contentRevealed = true
                        showModal = true
                    } label: {
                        Text("Edit Alarm")
                            .font(AppTypography.labelLarge)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
            .detentModal(isPresented: $showModal, currentStep: $currentStep) {
                ZStack {
                    switch visiblePage {
                    case 0:
                        pageOne
                    case 2:
                        schedulePage
                    default:
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
            .onChange(of: targetPage) { _, newPage in
                contentRevealed = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    visiblePage = newPage
                    currentStep = stepForPage(newPage)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    contentRevealed = true
                }
            }
        }

        // MARK: - Pages

        private var pageOne: some View {
            VStack(spacing: 12) {

                // Schedule row — tappable
                detentRow(
                    icon: "clock.fill",
                    label: "Schedule",
                    value: timeString,
                    detail: scheduleSummary
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    targetPage = 2
                }

                // Snooze row
                detentRow(
                    icon: "zzz",
                    label: "Snooze",
                    value: "2 × 5 min",
                    detail: "10 min total"
                )

                // Next button
                Button {
                    targetPage = 1
                } label: {
                    Text("Next")
                }
                .primaryButton()
                .padding(.top, 12)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 16)
            .padding(.bottom, 50)
        }

        private var pageTwo: some View {
            VStack(spacing: 12) {

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

                // Schedule row
                detentRow(
                    icon: "clock.fill",
                    label: "Schedule",
                    value: timeString,
                    detail: scheduleSummary
                )

                // Snooze row
                detentRow(
                    icon: "zzz",
                    label: "Snooze",
                    value: "2 × 5 min",
                    detail: "10 min total"
                )

                // Voice row
                detentRow(
                    icon: "waveform",
                    label: "Voice",
                    value: "Calm Guide",
                    detail: "Soothing · Gentle"
                )

                // Tone row
                detentRow(
                    icon: "flame.fill",
                    label: "Tone",
                    value: "Encourage",
                    detail: nil
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 50)
        }

        // MARK: - Schedule Page

        private var schedulePage: some View {
            VStack(spacing: 16) {

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

                // Time picker
                VStack(spacing: 4) {
                    Text("WAKE TIME")
                        .font(AppTypography.caption)
                        .tracking(AppTypography.captionTracking)
                        .foregroundStyle(.white.opacity(0.4))

                    DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .colorScheme(.dark)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))

                // Day picker
                VStack(spacing: 14) {
                    Text("REPEAT")
                        .font(AppTypography.caption)
                        .tracking(AppTypography.captionTracking)
                        .foregroundStyle(.white.opacity(0.4))

                    DayPicker(selectedDays: $selectedDays)

                    Text(scheduleSummary)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 50)
        }

        // MARK: - Shared Row

        private func detentRow(
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
    }

    return PreviewContainer()
}
