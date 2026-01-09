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
        showNotification(
            title: "Grammar Corrected",
            body: truncateText(preview, maxLength: 100),
            identifier: "grammar-success"
        )
    }
    
    func showGrammarCopiedToClipboard(preview: String) {
        showNotification(
            title: "Corrected Text Copied",
            body: truncateText(preview, maxLength: 100) + "\n\nPaste with Cmd+V",
            identifier: "grammar-clipboard"
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
        alert.informativeText = translatedText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        // Make the alert text selectable by using an accessory view
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 380, height: 200))
        textView.string = translatedText
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        
        scrollView.documentView = textView
        alert.accessoryView = scrollView
        alert.informativeText = "" // Clear since we use accessory view
        
        alert.runModal()
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

