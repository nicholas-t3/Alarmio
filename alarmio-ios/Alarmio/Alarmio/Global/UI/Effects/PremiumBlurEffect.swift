//
//  PremiumBlurEffect.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

// MARK: - Transition Direction
enum TransitionDirection: Equatable {
    case `in`   // Fade/blur in (visible)
    case out    // Fade/blur out (hidden)

    var isVisible: Bool {
        switch self {
        case .in: return true
        case .out: return false
        }
    }
}

// MARK: - Transition Profile
struct TransitionProfile {
    let duration: Double
    let blurAmount: CGFloat
    let scaleAmount: CGFloat
    let offsetAmount: CGFloat
    let animation: Animation

    static let premium = TransitionProfile(
        duration: 0.4,
        blurAmount: 10,
        scaleAmount: 0.95,
        offsetAmount: 20,
        animation: .easeOut(duration: 0.4)
    )

    static let fast = TransitionProfile(
        duration: 0.25,
        blurAmount: 8,
        scaleAmount: 0.97,
        offsetAmount: 15,
        animation: .easeOut(duration: 0.25)
    )

    static let gentle = TransitionProfile(
        duration: 0.6,
        blurAmount: 12,
        scaleAmount: 0.93,
        offsetAmount: 25,
        animation: .spring(response: 0.6, dampingFraction: 0.8)
    )
}

// MARK: - Transition Coordinator
@Observable
@MainActor
final class TransitionCoordinator {
    var direction: TransitionDirection = .out
}

// MARK: - Environment Key
private struct TransitionCoordinatorKey: EnvironmentKey {
    static let defaultValue = TransitionCoordinator()
}

extension EnvironmentValues {
    var transitionCoordinator: TransitionCoordinator {
        get { self[TransitionCoordinatorKey.self] }
        set { self[TransitionCoordinatorKey.self] = newValue }
    }
}

// MARK: - Premium Blur Effect (Environment-Driven)
struct PremiumBlurEffect: ViewModifier {
    @Environment(\.transitionCoordinator) private var transitionCoordinator
    let delay: Double
    let profile: TransitionProfile

    init(
        delay: Double = 0.0,
        profile: TransitionProfile = .premium
    ) {
        self.delay = delay
        self.profile = profile
    }

    func body(content: Content) -> some View {
        let visible = transitionCoordinator.direction.isVisible

        content
            .blur(radius: visible ? 0 : profile.blurAmount)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1.0 : profile.scaleAmount)
            .offset(y: visible ? 0 : profile.offsetAmount)
            .animation(
                profile.animation.delay(delay),
                value: transitionCoordinator.direction
            )
    }
}

// MARK: - Premium Blur Effect (Explicit Direction)
struct PremiumBlurEffectExplicit: ViewModifier {
    let direction: TransitionDirection
    let delay: Double
    let profile: TransitionProfile
    let disableScale: Bool
    let disableOffset: Bool

    init(
        direction: TransitionDirection,
        delay: Double = 0.0,
        profile: TransitionProfile = .premium,
        disableScale: Bool = false,
        disableOffset: Bool = false
    ) {
        self.direction = direction
        self.delay = delay
        self.profile = profile
        self.disableScale = disableScale
        self.disableOffset = disableOffset
    }

    init(
        isVisible: Bool,
        delay: Double = 0.0,
        duration: Double? = nil,
        disableScale: Bool = false,
        disableOffset: Bool = false
    ) {
        self.direction = isVisible ? .in : .out
        self.delay = delay
        self.disableScale = disableScale
        self.disableOffset = disableOffset

        if let duration = duration {
            self.profile = TransitionProfile(
                duration: duration,
                blurAmount: 10,
                scaleAmount: 0.95,
                offsetAmount: 20,
                animation: .easeOut(duration: duration)
            )
        } else {
            self.profile = .premium
        }
    }

    func body(content: Content) -> some View {
        let visible = direction.isVisible

        content
            .blur(radius: visible ? 0 : profile.blurAmount)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible || disableScale ? 1.0 : profile.scaleAmount)
            .offset(y: visible || disableOffset ? 0 : profile.offsetAmount)
            .animation(
                profile.animation.delay(delay),
                value: direction
            )
    }
}

// MARK: - View Extension
extension View {
    /// Auto-observed premium blur effect — reads direction from environment
    func premiumBlur(
        delay: Double = 0.0,
        profile: TransitionProfile = .premium
    ) -> some View {
        modifier(PremiumBlurEffect(delay: delay, profile: profile))
    }

    /// Explicit direction premium blur effect — for manual control
    func premiumBlur(
        _ direction: TransitionDirection,
        delay: Double = 0.0,
        profile: TransitionProfile = .premium
    ) -> some View {
        modifier(PremiumBlurEffectExplicit(direction: direction, delay: delay, profile: profile))
    }

    /// Boolean-based premium blur — simplest API
    func premiumBlur(
        isVisible: Bool,
        delay: Double = 0.0,
        duration: Double? = nil,
        disableScale: Bool = false,
        disableOffset: Bool = false
    ) -> some View {
        modifier(PremiumBlurEffectExplicit(
            isVisible: isVisible,
            delay: delay,
            duration: duration,
            disableScale: disableScale,
            disableOffset: disableOffset
        ))
    }
}

// MARK: - Backward Compatibility
typealias PremiumFadeEffect = PremiumBlurEffectExplicit

// MARK: - AnyTransition Helper
extension AnyTransition {
    /// Blur + fade transition matching the app's premium language. Use for
    /// view swaps where both sides should cross-dissolve through blur
    /// (e.g. root-level onboarding → home swap).
    static var premiumBlur: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: BlurFadeModifier(blur: 10, opacity: 0),
                identity: BlurFadeModifier(blur: 0, opacity: 1)
            ),
            removal: .modifier(
                active: BlurFadeModifier(blur: 10, opacity: 0),
                identity: BlurFadeModifier(blur: 0, opacity: 1)
            )
        )
    }
}

private struct BlurFadeModifier: ViewModifier {
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .opacity(opacity)
    }
}

// MARK: - Previews
#Preview("Premium Blur In") {
    ZStack {
        Color.black.ignoresSafeArea()

        Text("ALARMIO")
            .font(.system(size: 48, weight: .light))
            .tracking(4)
            .foregroundStyle(.white)
            .premiumBlur(isVisible: true)
    }
}

#Preview("Premium Blur Out") {
    ZStack {
        Color.black.ignoresSafeArea()

        Text("ALARMIO")
            .font(.system(size: 48, weight: .light))
            .tracking(4)
            .foregroundStyle(.white)
            .premiumBlur(isVisible: false)
    }
}
