//
//  AXSelectionService.swift
//  GrammarPolice
//
//  Accessibility API service for reading and replacing selected text
//

import AppKit
import ApplicationServices

enum AXError: Error, LocalizedError {
    case noFocusedElement
    case noSelectedText
    case cannotReadSelection
    case cannotReplaceText
    case secureTextField
    case accessibilityNotEnabled
    
    var errorDescription: String? {
        switch self {
        case .noFocusedElement:
            return "No focused element found"
        case .noSelectedText:
            return "No text is selected"
        case .cannotReadSelection:
            return "Cannot read the selected text"
        case .cannotReplaceText:
            return "Cannot replace the selected text"
        case .secureTextField:
            return "Cannot access secure text fields"
        case .accessibilityNotEnabled:
            return "Accessibility permission not granted"
        }
    }
}

struct FocusedAppInfo {
    let bundleIdentifier: String
    let appName: String
    let processIdentifier: pid_t
}

final class AXSelectionService {
    static let shared = AXSelectionService()
    
    private init() {}
    
    // MARK: - Permission Check
    
    var isAccessibilityEnabled: Bool {
        return AXIsProcessTrusted()
    }
    
    func checkAndRequestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    // MARK: - Get Focused App Info
    
    func getFocusedAppInfo() -> FocusedAppInfo? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        return FocusedAppInfo(
            bundleIdentifier: frontApp.bundleIdentifier ?? "",
            appName: frontApp.localizedName ?? "Unknown",
            processIdentifier: frontApp.processIdentifier
        )
    }
    
    // MARK: - Get Selected Text
    
    func getSelectedText() throws -> String {
        guard isAccessibilityEnabled else {
            throw AXError.accessibilityNotEnabled
        }
        
        // Get the focused application
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            throw AXError.noFocusedElement
        }
        
        let pid = frontApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        // Get the focused element
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard focusResult == .success, let element = focusedElement else {
            LoggingService.shared.log("Failed to get focused element: \(focusResult.rawValue)", level: .debug)
            throw AXError.noFocusedElement
        }
        
        let axElement = element as! AXUIElement
        
        // Check if this is a secure text field
        if isSecureTextField(axElement) {
            LoggingService.shared.log("Detected secure text field, skipping", level: .warning)
            throw AXError.secureTextField
        }
        
        // Get the selected text
        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )
        
        guard textResult == .success, let text = selectedText as? String else {
            LoggingService.shared.log("Failed to get selected text: \(textResult.rawValue)", level: .debug)
            throw AXError.noSelectedText
        }
        
        if text.isEmpty {
            throw AXError.noSelectedText
        }
        
        LoggingService.shared.log("Got selected text via AX, length: \(text.count)", level: .debug)
        return text
    }
    
    // MARK: - Replace Selected Text
    
    func replaceSelectedText(with newText: String) throws {
        guard isAccessibilityEnabled else {
            throw AXError.accessibilityNotEnabled
        }
        
        // Get the focused application
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            throw AXError.noFocusedElement
        }
        
        let pid = frontApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        // Get the focused element
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard focusResult == .success, let element = focusedElement else {
            throw AXError.noFocusedElement
        }
        
        let axElement = element as! AXUIElement
        
        // Check if this is a secure text field
        if isSecureTextField(axElement) {
            throw AXError.secureTextField
        }
        
        // Check if the element is settable
        var isSettable: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(
            axElement,
            kAXSelectedTextAttribute as CFString,
            &isSettable
        )
        
        guard settableResult == .success && isSettable.boolValue else {
            LoggingService.shared.log("Selected text attribute is not settable", level: .debug)
            throw AXError.cannotReplaceText
        }
        
        // Set the new text
        let setResult = AXUIElementSetAttributeValue(
            axElement,
            kAXSelectedTextAttribute as CFString,
            newText as CFTypeRef
        )
        
        guard setResult == .success else {
            LoggingService.shared.log("Failed to set selected text: \(setResult.rawValue)", level: .debug)
            throw AXError.cannotReplaceText
        }
        
        LoggingService.shared.log("Successfully replaced text via AX", level: .debug)
    }
    
    // MARK: - Helpers
    
    private func isSecureTextField(_ element: AXUIElement) -> Bool {
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &role
        )
        
        if roleResult == .success, let roleString = role as? String {
            // kAXSecureTextFieldRole = "AXSecureTextField"
            if roleString == "AXSecureTextField" {
                return true
            }
        }
        
        // Also check subrole
        var subrole: CFTypeRef?
        let subroleResult = AXUIElementCopyAttributeValue(
            element,
            kAXSubroleAttribute as CFString,
            &subrole
        )
        
        if subroleResult == .success, let subroleString = subrole as? String {
            if subroleString.contains("Secure") || subroleString.contains("Password") {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Check if AX Replace is Likely to Work
    
    func canReplaceText() -> Bool {
        guard isAccessibilityEnabled else { return false }
        
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        
        // Some apps are known to not support AX replacement well
        let problematicBundles = [
            "com.google.Chrome",
            "com.microsoft.Word",
            "com.apple.Safari"
        ]
        
        if let bundleId = frontApp.bundleIdentifier,
           problematicBundles.contains(where: { bundleId.hasPrefix($0) }) {
            return false
        }
        
        return true
    }
}

