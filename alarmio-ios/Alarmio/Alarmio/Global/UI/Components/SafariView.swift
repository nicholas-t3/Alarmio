//
//  SafariView.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/14/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {

    // MARK: - Constants

    let url: URL

    // MARK: - Representable

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false

        let controller = SFSafariViewController(url: url, configuration: config)
        controller.preferredBarTintColor = UIColor(Color(hex: "0f1a2e"))
        controller.preferredControlTintColor = UIColor(Color(hex: "E8A060"))
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Previews

#Preview("Safari Modal") {
    struct PreviewContainer: View {
        @State private var showSafari = true

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                Button("Open Safari") {
                    showSafari = true
                }
                .foregroundStyle(.white)
            }
            .sheet(isPresented: $showSafari) {
                SafariView(url: URL(string: "https://alarmioapp.com/terms-of-use")!)
                    .ignoresSafeArea()
            }
        }
    }

    return PreviewContainer()
}
