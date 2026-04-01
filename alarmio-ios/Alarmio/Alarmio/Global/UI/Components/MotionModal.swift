//
//  MotionModal.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct MotionModal<Content: View>: View {

    // MARK: - Constants

    @Binding var isPresented: Bool
    let dismissible: Bool
    @ViewBuilder let content: () -> Content

    // MARK: - State

    @State private var offset: CGFloat = 1000
    @State private var dragOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var contentOpacity: Double = 0

    // MARK: - Computed Properties

    private var totalOffset: CGFloat {
        offset + dragOffset
    }

    private var backgroundOpacity: Double {
        let progress = 1 - (totalOffset / 600)
        return max(0, min(0.6, progress * 0.6))
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {

                // Fullscreen dimmed background
                if isPresented || backgroundOpacity > 0 {
                    Color.black
                        .opacity(backgroundOpacity)
                        .ignoresSafeArea()
                        .onTapGesture {
                            if dismissible {
                                dismiss()
                            }
                        }
                }

                // Modal content
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

                        // Content with fade-in
                        content()
                            .opacity(contentOpacity)
                            .background(
                                GeometryReader { contentGeometry in
                                    Color.clear
                                        .preference(
                                            key: MotionModalHeightKey.self,
                                            value: contentGeometry.size.height + 25
                                        )
                                }
                            )
                    }
                    .frame(height: contentHeight > 0 ? contentHeight : nil)
                    .background(modalBackground)
                    .mask(modalShape)
                    .padding(.horizontal, 16)
                    .offset(y: totalOffset)
                    .onPreferenceChange(MotionModalHeightKey.self) { height in
                        contentHeight = height
                    }
                    .gesture(dragGesture)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: contentHeight)
            .onChange(of: isPresented) { _, newValue in
                if newValue {
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
            .onAppear {
                if isPresented {
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
            .fill(Color(hex: "0A0A0A").opacity(0.7))

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

    private var dragGesture: some Gesture {
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
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Private Methods

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.15)) {
            contentOpacity = 0
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            offset = 1000
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isPresented = false
            dragOffset = 0
        }
    }
}

private struct MotionModalHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func motionModal<Content: View>(
        isPresented: Binding<Bool>,
        dismissible: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            self

            if isPresented.wrappedValue {
                MotionModal(
                    isPresented: isPresented,
                    dismissible: dismissible,
                    content: content
                )
            }
        }
    }
}

#Preview {
    struct PreviewContainer: View {
        @State private var showModal = true

        var body: some View {
            ZStack {
                NightSkyBackground()

                MotionModal(isPresented: $showModal, dismissible: false) {
                    VStack(spacing: 24) {
                        Text("PERMISSION REQUIRED")
                            .font(AppTypography.headlineLarge)
                            .tracking(AppTypography.headlineLargeTracking)
                            .foregroundStyle(.white.opacity(0.9))

                        Text("Alarmio needs alarm permission to work.\nPlease enable it in Settings.")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        Button {
                            showModal = false
                        } label: {
                            Text("Open Settings")
                        }
                        .primaryButton()
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 40)
                }
            }
        }
    }

    return PreviewContainer()
}
