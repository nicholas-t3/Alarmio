//
//  TextTransitionEffect.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/1/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct TextTransitionEffect: View {

    // MARK: - State
    @State private var showFullText = false

    // MARK: - Body
    var body: some View {
        ZStack {

            // Background
            Color.black.ignoresSafeArea()

            // Transition demos
            VStack(spacing: 40) {

                // From empty space
                VStack(spacing: 8) {
                    Text("From space:").font(.caption).foregroundStyle(.gray)
                    Text(showFullText ? "This is the new text" : " ")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.8), value: showFullText)
                }

                // From dot
                VStack(spacing: 8) {
                    Text("From dot:").font(.caption).foregroundStyle(.gray)
                    Text(showFullText ? "This is the new text" : ".")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.8), value: showFullText)
                }
            }
        }
        .task {
            while true {
                try? await Task.sleep(for: .seconds(2))
                showFullText.toggle()
            }
        }
    }
}

#Preview {
    TextTransitionEffect()
}
