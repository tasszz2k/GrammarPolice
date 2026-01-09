//
//  FloatingNotificationWindow.swift
//  GrammarPolice
//
//  A custom floating notification that doesn't require Push Notifications capability.
//  Used as a fallback when UNUserNotificationCenter is not available.
//

import AppKit
import SwiftUI

// MARK: - FloatingNotificationWindow

@MainActor
final class FloatingNotificationWindow: NSPanel {
    
    private var dismissTimer: Timer?
    private var fadeOutWorkItem: DispatchWorkItem?
    
    init(title: String, body: String, duration: TimeInterval = 4.0) {
        // Calculate position - top right of main screen
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let notificationWidth: CGFloat = 340
        let notificationHeight: CGFloat = 80
        let padding: CGFloat = 16
        
        let frame = NSRect(
            x: screenFrame.maxX - notificationWidth - padding,
            y: screenFrame.maxY - notificationHeight - padding,
            width: notificationWidth,
            height: notificationHeight
        )
        
        super.init(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure window appearance
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        
        // Create content view
        let contentView = FloatingNotificationView(
            title: title,
            message: body,
            onDismiss: { [weak self] in
                self?.dismissNotification()
            }
        )
        self.contentView = NSHostingView(rootView: contentView)
        
        // Schedule auto-dismiss
        scheduleAutoDismiss(after: duration)
    }
    
    private func scheduleAutoDismiss(after duration: TimeInterval) {
        fadeOutWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissNotification()
        }
        fadeOutWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }
    
    func dismissNotification() {
        fadeOutWorkItem?.cancel()

        // Use a stable constant to avoid capturing mutable `self` in sendable contexts
        let window = self

        NSAnimationContext.runAnimationGroup({ [window] context in
            context.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: { [window] in
            Task { @MainActor in
                window.orderOut(nil)
                FloatingNotificationManager.shared.notificationDismissed(window)
            }
        })
    }
    
    func show() {
        self.alphaValue = 0
        self.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.animator().alphaValue = 1
        }
    }
}

// MARK: - FloatingNotificationView

struct FloatingNotificationView: View {
    let title: String
    let message: String
    let onDismiss: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 0)
            
            // Close button (visible on hover)
            if isHovered {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - VisualEffectView

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - FloatingNotificationManager

@MainActor
final class FloatingNotificationManager {
    static let shared = FloatingNotificationManager()
    
    private var activeNotifications: [FloatingNotificationWindow] = []
    private let maxVisibleNotifications = 3
    private let notificationSpacing: CGFloat = 8
    
    private init() {}
    
    func showNotification(title: String, body: String, duration: TimeInterval = 4.0) {
        // Remove oldest if we have too many
        while activeNotifications.count >= maxVisibleNotifications {
            if let oldest = activeNotifications.first {
                oldest.dismissNotification()
            }
        }
        
        let notification = FloatingNotificationWindow(title: title, body: body, duration: duration)
        
        // Adjust position based on existing notifications
        if !activeNotifications.isEmpty {
            adjustNotificationPositions(for: notification)
        }
        
        activeNotifications.append(notification)
        notification.show()
        
        LoggingService.shared.log("Floating notification shown: \(title)", level: .debug)
    }
    
    func notificationDismissed(_ notification: FloatingNotificationWindow?) {
        guard let notification = notification else { return }
        activeNotifications.removeAll { $0 === notification }
        repositionNotifications()
    }
    
    private func adjustNotificationPositions(for newNotification: FloatingNotificationWindow) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let padding: CGFloat = 16
        
        // Calculate Y offset based on number of existing notifications
        let yOffset = CGFloat(activeNotifications.count) * (80 + notificationSpacing)
        
        var frame = newNotification.frame
        frame.origin.y = screenFrame.maxY - frame.height - padding - yOffset
        newNotification.setFrame(frame, display: false)
    }
    
    private func repositionNotifications() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let padding: CGFloat = 16
        
        for (index, notification) in activeNotifications.enumerated() {
            let yOffset = CGFloat(index) * (80 + notificationSpacing)
            var frame = notification.frame
            let targetY = screenFrame.maxY - frame.height - padding - yOffset
            
            if frame.origin.y != targetY {
                frame.origin.y = targetY
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    notification.animator().setFrame(frame, display: true)
                }
            }
        }
    }
}

