//
//  ToastService.swift
//  GrammarPolice
//
//  In-app toast notification: bottom-right floating panel showing full text
//  (no truncation). Auto-dismisses after a user-configurable duration.
//

import Foundation
import AppKit

@MainActor
final class ToastService {
    static let shared = ToastService()

    private var activePanel: NSPanel?
    private var dismissTimer: Timer?

    private init() {}

    struct Style {
        let titleColor: NSColor
        let backgroundColor: NSColor

        static let success = Style(
            titleColor: .white,
            backgroundColor: NSColor.systemGreen.withAlphaComponent(0.95)
        )

        static let info = Style(
            titleColor: .white,
            backgroundColor: NSColor.controlBackgroundColor.withAlphaComponent(0.95)
        )

        static let warning = Style(
            titleColor: .white,
            backgroundColor: NSColor.systemOrange.withAlphaComponent(0.95)
        )
    }

    func show(title: String, body: String, style: Style = .success, durationOverride: TimeInterval? = nil) {
        dismiss()

        let duration = durationOverride ?? SettingsManager.shared.notificationDurationSec
        guard duration > 0 else { return }

        let panel = makePanel(title: title, body: body, style: style)
        positionPanel(panel)
        panel.orderFrontRegardless()
        activePanel = panel

        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        activePanel?.orderOut(nil)
        activePanel = nil
    }

    // MARK: - Builders

    private func makePanel(title: String, body: String, style: Style) -> NSPanel {
        let maxWidth: CGFloat = 520
        let padding: CGFloat = 14

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.textColor = style.titleColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.font = NSFont.systemFont(ofSize: 12)
        bodyLabel.textColor = style.titleColor
        bodyLabel.preferredMaxLayoutWidth = maxWidth - padding * 2
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.maximumNumberOfLines = 0
        bodyLabel.isSelectable = true

        let titleSize = titleLabel.sizeThatFits(NSSize(width: maxWidth - padding * 2, height: .greatestFiniteMagnitude))
        let bodySize = bodyLabel.sizeThatFits(NSSize(width: maxWidth - padding * 2, height: .greatestFiniteMagnitude))

        let contentWidth = min(maxWidth, max(titleSize.width, bodySize.width) + padding * 2)
        let contentHeight = titleSize.height + 6 + bodySize.height + padding * 2

        let contentRect = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)

        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hidesOnDeactivate = false

        let containerView = NSView(frame: contentRect)
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = style.backgroundColor.cgColor
        containerView.layer?.cornerRadius = 10
        containerView.layer?.masksToBounds = true

        titleLabel.frame = NSRect(
            x: padding,
            y: contentHeight - padding - titleSize.height,
            width: contentWidth - padding * 2,
            height: titleSize.height
        )
        bodyLabel.frame = NSRect(
            x: padding,
            y: padding,
            width: contentWidth - padding * 2,
            height: bodySize.height
        )

        containerView.addSubview(titleLabel)
        containerView.addSubview(bodyLabel)
        panel.contentView = containerView

        return panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let margin: CGFloat = 16
        let size = panel.frame.size
        let origin = NSPoint(
            x: visible.maxX - size.width - margin,
            y: visible.minY + margin
        )
        panel.setFrameOrigin(origin)
    }
}
