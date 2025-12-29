//
//  NotificationService.swift
//  GrammarPolice
//
//  macOS notification service
//

import Foundation
import UserNotifications

final class NotificationService: NSObject {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private override init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    // MARK: - Permission
    
    func requestPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                LoggingService.shared.log("Notification permission error: \(error)", level: .error)
            } else if granted {
                LoggingService.shared.log("Notification permission granted", level: .info)
            } else {
                LoggingService.shared.log("Notification permission denied", level: .warning)
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
            body: truncateText(preview, maxLength: 100) + "\n\nPaste with Cmd+V",
            identifier: "translation-complete"
        )
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
    
    // MARK: - Private
    
    private func showNotification(title: String, body: String, identifier: String) {
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
                LoggingService.shared.log("Failed to show notification: \(error)", level: .error)
            }
        }
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
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notification even when app is in foreground
        return [.banner, .sound]
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Handle notification tap if needed
        LoggingService.shared.log("Notification tapped: \(response.notification.request.identifier)", level: .debug)
    }
}

