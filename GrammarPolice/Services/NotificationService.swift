//
//  NotificationService.swift
//  GrammarPolice
//
//  macOS notification service with fallback support
//

import Foundation
import UserNotifications
import AppKit

@MainActor
final class NotificationService: NSObject {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private var useNativeNotifications = true
    private var permissionChecked = false
    
    private override init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    // MARK: - Permission
    
    func requestPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            // Avoid capturing `self` in a concurrently-executing closure by hopping to the main actor
            let grantedCopy = granted
            let errorCopy = error
            Task { @MainActor in
                if let errorCopy = errorCopy {
                    LoggingService.shared.log("Notification permission error: \(errorCopy). Using fallback notifications.", level: .warning)
                    self.useNativeNotifications = false
                } else if grantedCopy {
                    LoggingService.shared.log("Notification permission granted", level: .info)
                    self.useNativeNotifications = true
                } else {
                    LoggingService.shared.log("Notification permission denied. Using fallback notifications.", level: .warning)
                    self.useNativeNotifications = false
                }
                self.permissionChecked = true
            }
        }
    }
    
    func checkPermission() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    // MARK: - Notifications
    
    func showGrammarCorrectionSuccess(preview: String) {
        ToastService.shared.show(title: "Grammar Corrected", body: preview, style: .success)
    }

    func showGrammarCopiedToClipboard(preview: String) {
        ToastService.shared.show(
            title: "Corrected Text Copied (Cmd+V to paste)",
            body: preview,
            style: .success
        )
    }
    
    func showTranslationComplete(preview: String, targetLanguage: String) {
        showNotification(
            title: "Translated to \(targetLanguage)",
            body: truncateText(preview, maxLength: 100),
            identifier: "translation-complete"
        )
    }
    
    @MainActor
    func showTranslationDialog(translatedText: String, targetLanguage: String) {
        let alert = NSAlert()
        alert.messageText = "Translation to \(targetLanguage)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.accessoryView = makeScrollableTextView(content: translatedText, width: 400, height: 200)
        alert.informativeText = ""
        alert.runModal()
    }

    // Strong reference holder so button targets survive while the modal is open.
    private var activeSpeakHandlers: [SpeakButtonHandler] = []

    @MainActor
    func showTranslationExploreDialog(original: String, simple: String, extended: String, targetLanguage: String) {
        let alert = NSAlert()
        alert.messageText = "Translation to \(targetLanguage)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        let width: CGFloat = 520
        let originalHeight: CGFloat = 70
        let simpleHeight: CGFloat = 60
        let extendedHeight: CGFloat = 260
        let labelHeight: CGFloat = 18
        let gap: CGFloat = 6
        let totalHeight = labelHeight + originalHeight + gap
                        + labelHeight + simpleHeight + gap
                        + labelHeight + extendedHeight

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: totalHeight))

        var y: CGFloat = 0

        // Extended (bottom)
        let extendedScroll = makeScrollableTextView(content: extended, width: width, height: extendedHeight)
        extendedScroll.frame = NSRect(x: 0, y: y, width: width, height: extendedHeight)
        extendedScroll.autoresizingMask = [.width]
        container.addSubview(extendedScroll)
        y += extendedHeight
        let extendedLabel = makeSectionLabel(text: "Extended", width: width, y: y)
        container.addSubview(extendedLabel)
        y += labelHeight + gap

        // Translated (middle)
        let simpleScroll = makeScrollableTextView(content: simple, width: width, height: simpleHeight)
        simpleScroll.frame = NSRect(x: 0, y: y, width: width, height: simpleHeight)
        simpleScroll.autoresizingMask = [.width]
        container.addSubview(simpleScroll)
        y += simpleHeight
        let simpleLabel = makeSectionLabel(text: "Translation (\(targetLanguage))", width: width, y: y)
        container.addSubview(simpleLabel)
        y += labelHeight + gap

        // Original (top) with Speak button.
        let speakBtnWidth: CGFloat = 90
        let originalScroll = makeScrollableTextView(content: original, width: width - speakBtnWidth - gap, height: originalHeight)
        originalScroll.frame = NSRect(x: 0, y: y, width: width - speakBtnWidth - gap, height: originalHeight)
        originalScroll.autoresizingMask = [.width]
        container.addSubview(originalScroll)

        let handler = SpeakButtonHandler(text: original)
        activeSpeakHandlers.append(handler)
        let speakButton = NSButton(
            title: "🔊 Speak",
            target: handler,
            action: #selector(SpeakButtonHandler.speak)
        )
        speakButton.bezelStyle = .rounded
        speakButton.frame = NSRect(
            x: width - speakBtnWidth,
            y: y + (originalHeight - 28) / 2,
            width: speakBtnWidth,
            height: 28
        )
        container.addSubview(speakButton)

        y += originalHeight
        let originalLabel = makeSectionLabel(text: "Original", width: width, y: y)
        container.addSubview(originalLabel)

        alert.accessoryView = container
        alert.informativeText = ""
        alert.runModal()

        // Modal closed: stop playback + release handlers.
        SpeechService.shared.stop()
        activeSpeakHandlers.removeAll()
    }

    @MainActor
    func showGrammarExploreDialog(original: String, corrected: String, lesson: String) {
        let alert = NSAlert()
        alert.messageText = "Grammar Explore"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        let width: CGFloat = 540
        let originalHeight: CGFloat = 90
        let correctedHeight: CGFloat = 90
        let lessonHeight: CGFloat = 260
        let labelHeight: CGFloat = 18
        let gap: CGFloat = 6
        let totalHeight = labelHeight + originalHeight + gap
                        + labelHeight + correctedHeight + gap
                        + labelHeight + lessonHeight

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: totalHeight))

        var y: CGFloat = 0

        // Lesson (bottom)
        let lessonScroll = makeScrollableTextView(content: lesson, width: width, height: lessonHeight)
        lessonScroll.frame = NSRect(x: 0, y: y, width: width, height: lessonHeight)
        lessonScroll.autoresizingMask = [.width]
        container.addSubview(lessonScroll)
        y += lessonHeight
        container.addSubview(makeSectionLabel(text: "Lesson", width: width, y: y))
        y += labelHeight + gap

        // Corrected (middle)
        let correctedScroll = makeScrollableTextView(content: corrected, width: width, height: correctedHeight)
        correctedScroll.frame = NSRect(x: 0, y: y, width: width, height: correctedHeight)
        correctedScroll.autoresizingMask = [.width]
        container.addSubview(correctedScroll)
        y += correctedHeight
        container.addSubview(makeSectionLabel(text: "Corrected", width: width, y: y))
        y += labelHeight + gap

        // Original (top) with Speak button
        let speakBtnWidth: CGFloat = 90
        let originalScroll = makeScrollableTextView(content: original, width: width - speakBtnWidth - gap, height: originalHeight)
        originalScroll.frame = NSRect(x: 0, y: y, width: width - speakBtnWidth - gap, height: originalHeight)
        originalScroll.autoresizingMask = [.width]
        container.addSubview(originalScroll)

        let handler = SpeakButtonHandler(text: original)
        activeSpeakHandlers.append(handler)
        let speakButton = NSButton(
            title: "🔊 Speak",
            target: handler,
            action: #selector(SpeakButtonHandler.speak)
        )
        speakButton.bezelStyle = .rounded
        speakButton.frame = NSRect(
            x: width - speakBtnWidth,
            y: y + (originalHeight - 28) / 2,
            width: speakBtnWidth,
            height: 28
        )
        container.addSubview(speakButton)

        y += originalHeight
        container.addSubview(makeSectionLabel(text: "Original", width: width, y: y))

        alert.accessoryView = container
        alert.informativeText = ""
        alert.runModal()

        SpeechService.shared.stop()
        activeSpeakHandlers.removeAll()
    }

    @MainActor
    private func makeSectionLabel(text: String, width: CGFloat, y: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.boldSystemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 0, y: y, width: width, height: 18)
        label.autoresizingMask = [.width]
        return label
    }

    @MainActor
    private func makeScrollableTextView(content: String, width: CGFloat, height: CGFloat) -> NSScrollView {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width - 20, height: height))
        textView.string = content
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        return scrollView
    }
    
    func showNoTextSelected() {
        showNotification(
            title: "No Text Selected",
            body: "Select some text and press the hotkey again.",
            identifier: "no-selection"
        )
    }
    
    func showError(_ message: String) {
        showNotification(
            title: "GrammarPolice Error",
            body: message,
            identifier: "error"
        )
    }
    
    func showSecureFieldWarning() {
        showNotification(
            title: "Secure Field Detected",
            body: "Cannot access password or secure text fields.",
            identifier: "secure-field"
        )
    }
    
    func showTextTooLong(current: Int, max: Int) {
        showNotification(
            title: "Text Too Long",
            body: "Selected text (\(current) chars) exceeds maximum (\(max) chars). Please select less text.",
            identifier: "text-too-long"
        )
    }
    
    func showPrivacyConsentRequired() {
        showNotification(
            title: "Privacy Consent Required",
            body: "Open Preferences to grant consent for sending text to remote LLM.",
            identifier: "privacy-consent"
        )
    }
    
    func showAPIKeyNotSet() {
        showNotification(
            title: "OpenAI API Key Not Set",
            body: "Please set your OpenAI API key in Preferences > LLM.",
            identifier: "api-key-not-set"
        )
    }
    
    func showLocalLLMNotConfigured() {
        showNotification(
            title: "Local LLM Not Configured",
            body: "Please configure your local LLM command or endpoint in Preferences > LLM.",
            identifier: "local-llm-not-configured"
        )
    }
    
    func showAccessibilityPermissionRequired() {
        showNotification(
            title: "Accessibility Permission Required",
            body: "Please enable Accessibility permission in System Settings > Privacy & Security > Accessibility.",
            identifier: "accessibility-required"
        )
    }
    
    func showInputMonitoringRequired() {
        showNotification(
            title: "Input Monitoring Permission Required",
            body: "For keyboard shortcuts to work in all apps, enable Input Monitoring in System Settings > Privacy & Security > Input Monitoring.",
            identifier: "input-monitoring-required"
        )
    }
    
    // MARK: - Private
    
    private func showNotification(title: String, body: String, identifier: String) {
        // If permission hasn't been checked yet or native notifications are unavailable, use fallback
        if !permissionChecked || !useNativeNotifications {
            showFallbackNotification(title: title, body: body)
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: identifier + "-" + UUID().uuidString,
            content: content,
            trigger: nil  // Show immediately
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                LoggingService.shared.log("Failed to show notification: \(error). Falling back.", level: .warning)
                // Fall back to floating notification on error
                Task { @MainActor in
                    self.useNativeNotifications = false
                    self.showFallbackNotification(title: title, body: body)
                }
            } else {
                LoggingService.shared.log("Notification posted: \(title)", level: .debug)
            }
        }
    }
    
    private func showFallbackNotification(title: String, body: String) {
        FloatingNotificationManager.shared.showNotification(title: title, body: body)
    }
    
    private func truncateText(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength - 3)) + "..."
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .list])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap if needed
        Task { @MainActor in
            LoggingService.shared.log("Notification tapped: \(response.notification.request.identifier)", level: .debug)
        }
        completionHandler()
    }
}

