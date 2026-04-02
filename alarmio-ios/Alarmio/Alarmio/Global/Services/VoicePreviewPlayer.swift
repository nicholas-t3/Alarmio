//
//  VoicePreviewPlayer.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/2/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import AVFoundation
import SwiftUI

@Observable
@MainActor
final class VoicePreviewPlayer {

    // MARK: - State

    private(set) var isPlaying = false
    private(set) var currentPersona: VoicePersona?
    private(set) var bands: [CGFloat] = Array(repeating: 0, count: 24)

    // MARK: - Constants

    private let bandCount = 24

    // MARK: - Private

    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private var smoothedBands: [CGFloat] = Array(repeating: 0, count: 24)
    private var bandPhases: [Double] = []
    private var bandSpeeds: [Double] = []

    // MARK: - Playback

    func play(persona: VoicePersona) {
        stop()

        guard let url = Bundle.main.url(forResource: persona.rawValue, withExtension: "mp3") else {
            print("[VoicePreviewPlayer] Missing audio file: \(persona.rawValue).mp3")
            return
        }

        do {
            // Duck other audio (pauses user's music), resume on deactivation
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.isMeteringEnabled = true
            player.prepareToPlay()
            player.play()

            audioPlayer = player
            currentPersona = persona
            isPlaying = true

            // Generate unique band character for this persona
            generateBandProfile(for: persona)
            startMetering()
        } catch {
            print("[VoicePreviewPlayer] Playback error: \(error.localizedDescription)")
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        stopMetering()

        isPlaying = false
        currentPersona = nil

        // Deactivate session — notifies other apps to resume their audio
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Private Methods

    private func generateBandProfile(for persona: VoicePersona) {
        // Seed from persona so each voice gets a consistent but unique pattern
        var rng = SeededRNG(seed: UInt64(abs(persona.rawValue.hashValue)))
        bandPhases = (0..<bandCount).map { _ in Double.random(in: 0...(.pi * 2), using: &rng) }
        bandSpeeds = (0..<bandCount).map { _ in Double.random(in: 1.5...4.0, using: &rng) }
    }

    private func startMetering() {
        let link = CADisplayLink(target: MeteringTarget(handler: { [weak self] in
            self?.updateBands()
        }), selector: #selector(MeteringTarget.tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopMetering() {
        displayLink?.invalidate()
        displayLink = nil

        // Ease bands to zero
        smoothedBands = Array(repeating: 0, count: bandCount)
        bands = smoothedBands
    }

    private func updateBands() {
        guard let player = audioPlayer, player.isPlaying else {
            // Audio finished naturally
            if audioPlayer != nil && !(audioPlayer?.isPlaying ?? false) {
                isPlaying = false
            }
            return
        }

        player.updateMeters()

        // Get overall power level (dB), normalize to 0–1
        let power = player.averagePower(forChannel: 0)
        let normalizedPower = CGFloat(max(0, min(1, (power + 50) / 50)))

        let now = CACurrentMediaTime()

        // Simulate frequency bands using power + per-band sine modulation
        for i in 0..<bandCount {
            let phase = bandPhases[i]
            let speed = bandSpeeds[i]

            // Multiple sine layers for organic movement
            let wave1 = sin(now * speed + phase)
            let wave2 = sin(now * speed * 1.7 + phase * 0.6) * 0.5
            let wave3 = sin(now * speed * 0.4 + phase * 2.1) * 0.3

            let modulation = (wave1 + wave2 + wave3 + 1.8) / 3.6 // normalize to ~0–1

            // Band position shapes the frequency curve — boost mids, taper highs/lows
            let bandPos = CGFloat(i) / CGFloat(bandCount - 1)
            let curve = 1.0 - pow(bandPos * 2.0 - 1.0, 2) * 0.4 // gentle mid-boost

            let target = normalizedPower * modulation * curve
            smoothedBands[i] += (target - smoothedBands[i]) * 0.18
        }

        bands = smoothedBands
    }
}

// MARK: - CADisplayLink Target

/// Prevent retain cycles with CADisplayLink — wraps closure in an NSObject target.
private class MeteringTarget: NSObject {
    let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func tick() {
        handler()
    }
}

// MARK: - Seeded RNG

/// Deterministic RNG so each persona generates the same band profile every time.
private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
