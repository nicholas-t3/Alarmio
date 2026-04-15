//
//  NameAlarmSheet.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/15/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI

struct NameAlarmSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var name: String
    @FocusState private var fieldFocused: Bool

    // MARK: - Constants

    let initialName: String
    let onCommit: (String) -> Void

    // MARK: - Init

    init(initialName: String, onCommit: @escaping (String) -> Void) {
        self.initialName = initialName
        self.onCommit = onCommit
        _name = State(initialValue: initialName)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {

            // Title
            Text("ALARM NAME")
                .font(AppTypography.caption)
                .tracking(AppTypography.captionTracking)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 8)

            // Text field card
            TextField(
                "",
                text: $name,
                prompt: Text("e.g. Morning Run").foregroundStyle(.white.opacity(0.3))
            )
            .font(AppTypography.labelLarge)
            .foregroundStyle(.white)
            .tint(.white)
            .multilineTextAlignment(.center)
            .submitLabel(.done)
            .textInputAutocapitalization(.words)
            .focused($fieldFocused)
            .onSubmit { commitAndDismiss() }
            .onChange(of: name) { _, newValue in
                if newValue.count > 40 {
                    name = String(newValue.prefix(40))
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.tint(Color(hex: "0e2444").opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { commitAndDismiss() }
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 16)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                fieldFocused = true
            }
        }
    }

    // MARK: - Private Methods

    private func commitAndDismiss() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        onCommit(trimmed)
        fieldFocused = false
        dismiss()
    }
}

// MARK: - Previews

#Preview("Empty") {
    ZStack {
        Color(hex: "0f1a2e").ignoresSafeArea()
        NameAlarmSheet(initialName: "") { _ in }
    }
}

#Preview("With Name") {
    ZStack {
        Color(hex: "0f1a2e").ignoresSafeArea()
        NameAlarmSheet(initialName: "Morning run") { _ in }
    }
}
