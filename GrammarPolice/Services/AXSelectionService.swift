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
        let window = SettingsManager.shared.contextWindowChars
        let surroundingContext = extractSurroundingWindow(
            fullText: fullText,
            selectionLocation: cfRange.location,
            selectionLength: cfRange.length,
            charsBefore: window,
            charsAfter: window
        )
        LoggingService.shared.log("Got selected text via AX, length: \(text.count), context length: \(surroundingContext?.count ?? 0)", level: .debug)
        return SelectionContext(selectedText: text, surroundingContext: surroundingContext)
    }

    // Fetch full text of focused element (without needing a selection range).
    // Used as a fallback to build context when the selection itself was captured
    // via Cmd+C (clipboard) rather than via AX.
    func getFocusedElementFullText() -> String? {
        guard isAccessibilityEnabled,
              let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
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
            return nil
        }
        let axElement = element as! AXUIElement
        var fullTextRef: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXValueAttribute as CFString,
            &fullTextRef
        )
        guard valueResult == .success, let fullText = fullTextRef as? String, !fullText.isEmpty else {
            return nil
        }
        return fullText
    }

    // Build context from full text by locating the selection substring and
    // slicing a char window around it. Returns nil when selection text isn't
    // found in fullText (e.g. clipboard came from a different source).
    func contextWindow(around selection: String, fullText: String, window: Int) -> String? {
        guard !selection.isEmpty, !fullText.isEmpty,
              let range = fullText.range(of: selection) else {
            return nil
        }
        let startOffset = fullText.distance(from: fullText.startIndex, to: range.lowerBound)
        let length = fullText.distance(from: range.lowerBound, to: range.upperBound)
        return extractSurroundingWindow(
            fullText: fullText,
            selectionLocation: startOffset,
            selectionLength: length,
            charsBefore: window,
            charsAfter: window,
            useUTF16Offsets: false
        )
    }

    private func extractSurroundingWindow(
        fullText: String,
        selectionLocation: Int,
        selectionLength: Int,
        charsBefore: Int,
        charsAfter: Int,
        useUTF16Offsets: Bool = true
    ) -> String? {
        // Translate offsets to String.Index. AX returns UTF-16 offsets; our
        // helper variant may pass native String offsets.
        let startIndex: String.Index
        let endIndex: String.Index
        if useUTF16Offsets {
            let utf16 = fullText.utf16
            let utf16Count = utf16.count
            let selectionEnd = selectionLocation + selectionLength
            guard selectionLocation >= 0, selectionEnd <= utf16Count else { return nil }
            guard let s = utf16.index(utf16.startIndex, offsetBy: selectionLocation, limitedBy: utf16.endIndex)?.samePosition(in: fullText),
                  let e = utf16.index(utf16.startIndex, offsetBy: selectionEnd, limitedBy: utf16.endIndex)?.samePosition(in: fullText) else {
                return nil
            }
            startIndex = s
            endIndex = e
        } else {
            let count = fullText.count
            let selectionEnd = selectionLocation + selectionLength
            guard selectionLocation >= 0, selectionEnd <= count else { return nil }
            startIndex = fullText.index(fullText.startIndex, offsetBy: selectionLocation)
            endIndex = fullText.index(fullText.startIndex, offsetBy: selectionEnd)
        }

        // Step back charsBefore chars, then snap to nearest whitespace to avoid
        // cutting mid-word.
        let beforeStart = fullText.index(startIndex, offsetBy: -charsBefore, limitedBy: fullText.startIndex) ?? fullText.startIndex
        let snappedStart = snapForward(in: fullText, from: beforeStart, notPast: startIndex)

        let afterEnd = fullText.index(endIndex, offsetBy: charsAfter, limitedBy: fullText.endIndex) ?? fullText.endIndex
        let snappedEnd = snapBackward(in: fullText, from: afterEnd, notBefore: endIndex)

        let result = String(fullText[snappedStart..<snappedEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    // Move forward from `start` until whitespace boundary, but never past `notPast`.
    private func snapForward(in text: String, from start: String.Index, notPast limit: String.Index) -> String.Index {
        if start == text.startIndex { return start }
        var idx = start
        while idx < limit {
            if text[idx].isWhitespace || text[idx].isNewline {
                let next = text.index(after: idx)
                return next > limit ? start : next
            }
            idx = text.index(after: idx)
        }
        return start
    }

    // Move backward from `end` until whitespace boundary, but never before `notBefore`.
    private func snapBackward(in text: String, from end: String.Index, notBefore limit: String.Index) -> String.Index {
        if end == text.endIndex { return end }
        var idx = end
        while idx > limit {
            let prev = text.index(before: idx)
            if text[prev].isWhitespace || text[prev].isNewline {
                return idx
            }
            idx = prev
        }
        return end
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

    // Bundle id prefixes for apps that don't reliably expose text selection or
    // accept AX text replacement. These are routed through the clipboard
    // fallback path (synthesized Cmd+C / Cmd+V) instead of the Accessibility
    // API. Matched via hasPrefix so wrapped/variant builds also match.
    private static let problematicBundlePrefixes: [String] = [
        "com.google.Chrome",
        "com.microsoft.Word",
        "com.apple.Safari",
        "com.tinyspeck.slackmacgap",        // Slack
        "com.hnc.Discord",                  // Discord
        "com.microsoft.teams",              // Microsoft Teams
        "com.microsoft.VSCode",             // VS Code
        "com.visualstudio.code.oss",        // VSCodium / OSS builds
        "com.todesktop.230313mzl4w4u92",    // Cursor (stable, ToDesktop wrapper)
        "com.todesktop",                    // Cursor variants / other ToDesktop apps
        "com.exafunction.windsurf",         // Windsurf
        "com.electron",                     // Generic Electron apps
        "com.brave.Browser",                // Brave
        "com.operasoftware.Opera",          // Opera
        "org.mozilla.firefox",              // Firefox
        "com.vivaldi.Vivaldi"               // Vivaldi
    ]

    private static func isProblematicBundle(_ bundleId: String) -> Bool {
        return problematicBundlePrefixes.contains(where: { bundleId.hasPrefix($0) })
    }

    func canReplaceText() -> Bool {
        guard isAccessibilityEnabled else { return false }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        if let bundleId = frontApp.bundleIdentifier,
           Self.isProblematicBundle(bundleId) {
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

        return Self.isProblematicBundle(bundleId)
    }
}

