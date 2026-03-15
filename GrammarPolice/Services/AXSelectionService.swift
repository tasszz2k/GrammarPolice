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

struct SelectionContext {
    let selectedText: String
    let surroundingContext: String?
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
    
    func getSelectedTextWithContext() throws -> SelectionContext {
        guard isAccessibilityEnabled else {
            throw AXError.accessibilityNotEnabled
        }
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            throw AXError.noFocusedElement
        }
        let pid = frontApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
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
        if isSecureTextField(axElement) {
            LoggingService.shared.log("Detected secure text field, skipping", level: .warning)
            throw AXError.secureTextField
        }
        var selectedTextRef: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextRef
        )
        guard textResult == .success, let text = selectedTextRef as? String else {
            LoggingService.shared.log("Failed to get selected text: \(textResult.rawValue)", level: .debug)
            throw AXError.noSelectedText
        }
        if text.isEmpty {
            throw AXError.noSelectedText
        }
        var fullTextRef: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXValueAttribute as CFString,
            &fullTextRef
        )
        guard valueResult == .success, let fullText = fullTextRef as? String else {
            LoggingService.shared.log("Got selected text via AX, length: \(text.count) (no context)", level: .debug)
            return SelectionContext(selectedText: text, surroundingContext: nil)
        }
        var rangeRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeRef
        )
        guard rangeResult == .success, let rangeValue = rangeRef else {
            LoggingService.shared.log("Got selected text via AX, length: \(text.count) (no range)", level: .debug)
            return SelectionContext(selectedText: text, surroundingContext: nil)
        }
        // rangeValue is an AXValue wrapping a CFRange
        let axValue = rangeValue as! AXValue
        var cfRange = CFRange(location: 0, length: 0)
        guard AXValueGetValue(axValue, .cfRange, &cfRange) else {
            LoggingService.shared.log("Got selected text via AX, length: \(text.count) (range decode failed)", level: .debug)
            return SelectionContext(selectedText: text, surroundingContext: nil)
        }
        let surroundingContext = extractSurroundingSentence(
            fullText: fullText,
            selectionLocation: cfRange.location,
            selectionLength: cfRange.length
        )
        LoggingService.shared.log("Got selected text via AX, length: \(text.count), context length: \(surroundingContext?.count ?? 0)", level: .debug)
        return SelectionContext(selectedText: text, surroundingContext: surroundingContext)
    }
    
    private func extractSurroundingSentence(fullText: String, selectionLocation: Int, selectionLength: Int) -> String? {
        let utf16 = fullText.utf16
        let utf16Count = utf16.count
        let selectionEnd = selectionLocation + selectionLength
        guard selectionLocation >= 0, selectionEnd <= utf16Count else { return nil }
        let terminators: Set<UInt16> = [0x002E, 0x0021, 0x003F, 0x000A]
        var sentenceStart = 0
        if selectionLocation > 0 {
            for i in stride(from: selectionLocation - 1, through: 0, by: -1) {
                let idx = utf16.index(utf16.startIndex, offsetBy: i)
                if terminators.contains(utf16[idx]) {
                    sentenceStart = i + 1
                    break
                }
            }
        }
        var sentenceEnd = utf16Count
        for i in selectionEnd..<utf16Count {
            let idx = utf16.index(utf16.startIndex, offsetBy: i)
            if terminators.contains(utf16[idx]) {
                sentenceEnd = i + 1
                break
            }
        }
        guard let strStart = utf16.index(utf16.startIndex, offsetBy: sentenceStart, limitedBy: utf16.endIndex)?.samePosition(in: fullText),
              let strEnd = utf16.index(utf16.startIndex, offsetBy: sentenceEnd, limitedBy: utf16.endIndex)?.samePosition(in: fullText) else {
            return nil
        }
        var result = String(fullText[strStart..<strEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        if result.count > 500 {
            result = String(result.prefix(500))
        }
        return result.isEmpty ? nil : result
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
        // This includes Electron-based apps and some native apps with custom text rendering
        let problematicBundles = [
            "com.google.Chrome",
            "com.microsoft.Word",
            "com.apple.Safari",
            "com.tinyspeck.slackmacgap",  // Slack
            "com.hnc.Discord",             // Discord
            "com.microsoft.teams",         // Microsoft Teams
            "com.microsoft.VSCode",        // VS Code
            "com.electron",                // Generic Electron apps
            "com.brave.Browser",           // Brave
            "com.operasoftware.Opera",     // Opera
            "org.mozilla.firefox",         // Firefox
            "com.vivaldi.Vivaldi"          // Vivaldi
        ]
        
        if let bundleId = frontApp.bundleIdentifier,
           problematicBundles.contains(where: { bundleId.hasPrefix($0) }) {
            LoggingService.shared.log("App \(bundleId) is known to have AX issues, will use clipboard fallback", level: .debug)
            return false
        }
        
        return true
    }
    
    // Check if the current app is known to have AX text selection issues
    func isAppWithAXIssues() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            return false
        }
        
        // Electron and Chromium-based apps typically don't expose text selection via AX
        let problematicBundles = [
            "com.tinyspeck.slackmacgap",  // Slack
            "com.hnc.Discord",             // Discord
            "com.microsoft.teams",         // Microsoft Teams
            "com.microsoft.VSCode",        // VS Code
            "com.electron",                // Generic Electron apps
            "com.google.Chrome",           // Chrome
            "com.brave.Browser",           // Brave
            "org.mozilla.firefox"          // Firefox
        ]
        
        return problematicBundles.contains(where: { bundleId.hasPrefix($0) })
    }
}

