//
//  HotkeyManager.swift
//  GrammarPolice
//
//  Global hotkey registration using Carbon APIs
//

import Carbon
import AppKit
import Combine

final class HotkeyManager {
    
    // Callbacks for hotkey actions
    var onGrammarCorrect: (() -> Void)?
    var onTranslate: (() -> Void)?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // Hotkey configurations
    private var grammarHotkey: HotkeyConfig
    private var translateHotkey: HotkeyConfig
    
    init() {
        self.grammarHotkey = SettingsManager.shared.grammarHotkey
        self.translateHotkey = SettingsManager.shared.translateHotkey
    }
    
    deinit {
        unregisterAllHotkeys()
    }
    
    // MARK: - Registration
    
    func registerHotkeys() {
        // Create event tap to intercept key events
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        // Store self reference for callback
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                
                let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return hotkeyManager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: userInfo
        )
        
        guard let eventTap = eventTap else {
            LoggingService.shared.log("Failed to create event tap. Make sure Accessibility is enabled.", level: .error)
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        LoggingService.shared.log("Hotkeys registered successfully", level: .info)
    }
    
    func unregisterAllHotkeys() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        
        LoggingService.shared.log("Hotkeys unregistered", level: .info)
    }
    
    func updateHotkeys() {
        grammarHotkey = SettingsManager.shared.grammarHotkey
        translateHotkey = SettingsManager.shared.translateHotkey
        LoggingService.shared.log("Hotkeys updated - Grammar: \(grammarHotkey.displayString), Translate: \(translateHotkey.displayString)", level: .info)
    }
    
    // MARK: - Event Handling
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        
        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        // Convert CGEventFlags to our modifier format
        let modifiers = convertFlags(flags)
        
        // Check for grammar hotkey (default: Cmd+Shift+G)
        if keyCode == grammarHotkey.keyCode && modifiers == grammarHotkey.modifiers {
            LoggingService.shared.log("Grammar hotkey triggered", level: .debug)
            DispatchQueue.main.async { [weak self] in
                self?.onGrammarCorrect?()
            }
            return nil  // Consume the event
        }
        
        // Check for translate hotkey (default: Cmd+Shift+T)
        if keyCode == translateHotkey.keyCode && modifiers == translateHotkey.modifiers {
            LoggingService.shared.log("Translate hotkey triggered", level: .debug)
            DispatchQueue.main.async { [weak self] in
                self?.onTranslate?()
            }
            return nil  // Consume the event
        }
        
        return Unmanaged.passRetained(event)
    }
    
    private func convertFlags(_ flags: CGEventFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        
        if flags.contains(.maskCommand) {
            modifiers |= 256  // cmdKey
        }
        if flags.contains(.maskShift) {
            modifiers |= 512  // shiftKey
        }
        if flags.contains(.maskAlternate) {
            modifiers |= 2048  // optionKey
        }
        if flags.contains(.maskControl) {
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

