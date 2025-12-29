//
//  HotkeyManager.swift
//  GrammarPolice
//
//  Global hotkey registration using NSEvent global monitoring
//

import Carbon
import AppKit
import Combine

@MainActor
final class HotkeyManager {
    
    // Callbacks for hotkey actions
    var onGrammarCorrect: (() -> Void)?
    var onTranslate: (() -> Void)?
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var permissionCheckTimer: Timer?
    private var wasAccessibilityGranted = false
    
    // Hotkey configurations
    private var grammarHotkey: HotkeyConfig
    private var translateHotkey: HotkeyConfig
    
    init() {
        self.grammarHotkey = SettingsManager.shared.grammarHotkey
        self.translateHotkey = SettingsManager.shared.translateHotkey
        self.wasAccessibilityGranted = AXIsProcessTrusted()
    }
    
    deinit {
        unregisterAllHotkeys()
        permissionCheckTimer?.invalidate()
    }
    
    // MARK: - Registration
    
    func registerHotkeys() {
        // Check if we have accessibility permission
        let trusted = AXIsProcessTrusted()
        
        if !trusted {
            LoggingService.shared.log("Accessibility permission not granted. Global hotkeys will not work.", level: .warning)
            // Still try to register - it will work once permission is granted
        }
        
        // Global monitor for events when app is not focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // Local monitor for events when app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // Consume the event
            }
            return event
        }
        
        if globalMonitor != nil {
            LoggingService.shared.log("Hotkeys registered successfully", level: .info)
        } else {
            LoggingService.shared.log("Failed to register global hotkey monitor. Make sure Accessibility is enabled.", level: .error)
        }
        
        // If accessibility is not granted, start polling to re-register when granted
        if !trusted {
            startPermissionPolling()
        }
    }
    
    // MARK: - Permission Polling
    
    private func startPermissionPolling() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAndReregisterIfNeeded()
        }
    }
    
    private func checkAndReregisterIfNeeded() {
        let nowTrusted = AXIsProcessTrusted()
        
        if nowTrusted && !wasAccessibilityGranted {
            // Permission was just granted - re-register hotkeys
            wasAccessibilityGranted = true
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil
            
            LoggingService.shared.log("Accessibility permission granted - re-registering hotkeys", level: .info)
            
            // Unregister and re-register to get working monitors
            unregisterAllHotkeys()
            
            // Re-register (but don't start polling again since we now have permission)
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyEvent(event)
            }
            
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if self?.handleKeyEvent(event) == true {
                    return nil
                }
                return event
            }
            
            LoggingService.shared.log("Hotkeys re-registered after permission grant", level: .info)
        }
    }
    
    func unregisterAllHotkeys() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        
        LoggingService.shared.log("Hotkeys unregistered", level: .info)
    }
    
    func updateHotkeys() {
        grammarHotkey = SettingsManager.shared.grammarHotkey
        translateHotkey = SettingsManager.shared.translateHotkey
        LoggingService.shared.log("Hotkeys updated - Grammar: \(grammarHotkey.displayString), Translate: \(translateHotkey.displayString)", level: .info)
    }
    
    // MARK: - Event Handling
    
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let keyCode = UInt32(event.keyCode)
        let modifiers = convertModifierFlags(event.modifierFlags)
        
        // Check for grammar hotkey (default: Cmd+Shift+G)
        if keyCode == grammarHotkey.keyCode && modifiers == grammarHotkey.modifiers {
            LoggingService.shared.log("Grammar hotkey triggered via global monitor", level: .debug)
            DispatchQueue.main.async { [weak self] in
                self?.onGrammarCorrect?()
            }
            return true
        }
        
        // Check for translate hotkey (default: Cmd+Shift+T)
        if keyCode == translateHotkey.keyCode && modifiers == translateHotkey.modifiers {
            LoggingService.shared.log("Translate hotkey triggered via global monitor", level: .debug)
            DispatchQueue.main.async { [weak self] in
                self?.onTranslate?()
            }
            return true
        }
        
        return false
    }
    
    private func convertModifierFlags(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        
        if flags.contains(.command) {
            modifiers |= 256  // cmdKey
        }
        if flags.contains(.shift) {
            modifiers |= 512  // shiftKey
        }
        if flags.contains(.option) {
            modifiers |= 2048  // optionKey
        }
        if flags.contains(.control) {
            modifiers |= 4096  // controlKey
        }
        
        return modifiers
    }
}

// MARK: - Hotkey Recording

final class HotkeyRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var recordedHotkey: HotkeyConfig?
    
    private var eventMonitor: Any?
    
    func startRecording(completion: @escaping (HotkeyConfig?) -> Void) {
        isRecording = true
        recordedHotkey = nil
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            
            let keyCode = UInt32(event.keyCode)
            var modifiers: UInt32 = 0
            
            if event.modifierFlags.contains(.command) {
                modifiers |= 256
            }
            if event.modifierFlags.contains(.shift) {
                modifiers |= 512
            }
            if event.modifierFlags.contains(.option) {
                modifiers |= 2048
            }
            if event.modifierFlags.contains(.control) {
                modifiers |= 4096
            }
            
            // Require at least one modifier
            guard modifiers != 0 else { return event }
            
            let hotkey = HotkeyConfig(keyCode: keyCode, modifiers: modifiers)
            self.recordedHotkey = hotkey
            self.stopRecording()
            completion(hotkey)
            
            return nil  // Consume the event
        }
    }
    
    func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
