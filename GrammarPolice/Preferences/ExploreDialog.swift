//
//  ExploreDialog.swift
//  GrammarPolice
//
//  SwiftUI-based explore dialog used for both translation and grammar
//  explore output. Native macOS look + feel: proper window chrome,
//  SF Symbol speak button, smooth ScrollView, selectable rounded text
//  boxes that follow control-background / separator colors.
//

import SwiftUI
import AppKit

struct ExploreDialogPayload {
    let windowTitle: String
    let original: String
    let primaryLabel: String
    let primary: String
    let extendedLabel: String
    let extended: String
}

struct ExploreDialogView: View {
    let payload: ExploreDialogPayload
    let onClose: () -> Void

    @State private var isSpeaking = false

    var body: some View {
        VStack(spacing: 0) {
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    originalSection
                    primarySection
                    extendedSection
                }
                .padding(20)
            }
            .scrollIndicators(.automatic)

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Done") { onClose() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 540, idealWidth: 620, minHeight: 520, idealHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Sections

    private var originalSection: some View {
        sectionLayout(title: "Original", trailing: AnyView(speakButton)) {
            textBox(content: payload.original, fixedHeight: 88)
        }
    }

    private var primarySection: some View {
        sectionLayout(title: payload.primaryLabel, trailing: nil) {
            textBox(content: payload.primary, fixedHeight: 72)
        }
    }

    private var extendedSection: some View {
        sectionLayout(title: payload.extendedLabel, trailing: nil) {
            textBox(content: payload.extended, fixedHeight: nil, minHeight: 220)
        }
    }

    // MARK: - Building blocks

    private func sectionLayout<C: View>(
        title: String,
        trailing: AnyView?,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
                if let trailing { trailing }
            }
            content()
        }
    }

    private func textBox(content: String, fixedHeight: CGFloat?, minHeight: CGFloat = 60) -> some View {
        ScrollView {
            Text(content)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: fixedHeight)
        .frame(minHeight: minHeight)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var speakButton: some View {
        Button {
            SpeechService.shared.speak(text: payload.original)
        } label: {
            Label("Speak", systemImage: "speaker.wave.2.fill")
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .help("Listen to the original text")
    }
}

// MARK: - Window presentation

@MainActor
enum ExploreDialogPresenter {
    /// Shows the dialog as an application-modal window. Blocks until the user
    /// clicks Done or closes the window.
    static func presentModal(payload: ExploreDialogPayload) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = payload.windowTitle
        window.isReleasedWhenClosed = false
        window.center()
        window.titlebarAppearsTransparent = false

        let host = NSHostingController(
            rootView: ExploreDialogView(payload: payload) {
                NSApp.stopModal()
            }
        )
        window.contentViewController = host
        window.setContentSize(host.view.fittingSize)
        window.center()

        NSApp.runModal(for: window)

        // Cleanup
        SpeechService.shared.stop()
        window.orderOut(nil)
    }
}
