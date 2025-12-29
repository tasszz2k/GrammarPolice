//
//  ClipboardService.swift
//  GrammarPolice
//
//  Clipboard operations for fallback text capture and paste
//

import AppKit
import Carbon

struct ClipboardState {
    let items: [NSPasteboardItem]
    let changeCount: Int
}

final class ClipboardService {
    static let shared = ClipboardService()
    
    private let pasteboard = NSPasteboard.general
    private var savedState: ClipboardState?
    
    private init() {}
    
    // MARK: - Save/Restore Clipboard
    
    func saveClipboardState() {
        let items = pasteboard.pasteboardItems ?? []
        let copiedItems = items.map { item -> NSPasteboardItem in
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            return newItem
        }
        
        savedState = ClipboardState(
            items: copiedItems,
            changeCount: pasteboard.changeCount
        )
        
        LoggingService.shared.log("Clipboard state saved", level: .debug)
    }
    
    func restoreClipboardState() {
        guard let state = savedState else { return }
        
        pasteboard.clearContents()
        pasteboard.writeObjects(state.items)
        savedState = nil
        
        LoggingService.shared.log("Clipboard state restored", level: .debug)
    }
    
    // MARK: - Get/Set Text
    
    func getText() -> String? {
        return pasteboard.string(forType: .string)
    }
    
    func setText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    func setTextPreservingRTF(_ text: String, originalRTF: Data? = nil) {
        pasteboard.clearContents()
        
        // Try to preserve RTF if available
        if let rtfData = originalRTF {
            pasteboard.setData(rtfData, forType: .rtf)
        }
        
        pasteboard.setString(text, forType: .string)
    }
    
    // MARK: - Get RTF Data
    
    func getRTFData() -> Data? {
        return pasteboard.data(forType: .rtf)
    }
    
    // MARK: - Clipboard-based Text Capture
    
    func captureSelectedTextViaCopy() async -> String? {
        let shouldRestore = SettingsManager.shared.restoreClipboard
        
        if shouldRestore {
            saveClipboardState()
        }
        
        // Clear clipboard first and record change count
        pasteboard.clearContents()
        let clearedChangeCount = pasteboard.changeCount
        
        LoggingService.shared.log("Clipboard cleared, attempting Cmd+C fallback", level: .debug)
        
        // Small delay before sending key event (helps with app responsiveness)
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Simulate Cmd+C
        simulateCopy()
        
        // Wait for clipboard to update (increased timeout for slow apps like Slack)
        let capturedText = await waitForClipboardChange(from: clearedChangeCount, timeout: 2.0)
        
        if let text = capturedText, !text.isEmpty {
            LoggingService.shared.log("Captured text via copy fallback, length: \(text.count)", level: .debug)
        } else {
            LoggingService.shared.log("Copy fallback: no text captured (clipboard unchanged or empty)", level: .debug)
        }
        
        return capturedText
    }
    
    private func waitForClipboardChange(from changeCount: Int, timeout: TimeInterval) async -> String? {
        let startTime = Date()
        let checkInterval: TimeInterval = 0.05
        
        while Date().timeIntervalSince(startTime) < timeout {
            if pasteboard.changeCount != changeCount {
                // Clipboard changed, but give a tiny bit more time for complete data
                try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
                let text = getText()
                if let t = text, !t.isEmpty {
                    return t
                }
            }
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }
        
        // Timeout reached - check one final time
        LoggingService.shared.log("Clipboard capture timeout reached", level: .debug)
        return getText()
    }
    
    // MARK: - Simulate Key Events
    
    private func simulateCopy() {
        // Create Cmd+C key event
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down for C (keycode 8) with Cmd modifier
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        
        // Key up
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    func simulatePaste() {
        // Create Cmd+V key event
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down for V (keycode 9) with Cmd modifier
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        
        // Key up
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
    }
}

