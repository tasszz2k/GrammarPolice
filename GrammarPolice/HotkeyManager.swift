//
//  HotkeyManager.swift
//  GrammarPolice
//
//  Global hotkey registration using Carbon's RegisterEventHotKey.
//
//  Carbon hotkeys are dispatched to our process by the OS and are NOT
//  delivered to the focused application, which prevents the previously
//  observed problem where the focused app (e.g. Cursor / VS Code) would
//  process the hotkey first -- mutating the user's text selection -- and
//  the synthesized Cmd+C fallback then captured nothing.
//

import Carbon
import AppKit
import Combine

@MainActor
final class HotkeyManager {
    
    // Callbacks for hotkey actions
    var onGrammarCorrect: (() -> Void)?
    var onTranslate: (() -> Void)?
    
    // Carbon registration state
    private var grammarHotKeyRef: EventHotKeyRef?
    private var translateHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    
    private var permissionCheckTimer: Timer?
    private var wasAccessibilityGranted = false
    
    // Hotkey configurations
    private var grammarHotkey: HotkeyConfig
    private var translateHotkey: HotkeyConfig
    
    // Identifiers used to distinguish hotkeys inside the Carbon callback.
    fileprivate static let grammarHotKeyID: UInt32 = 1
    fileprivate static let translateHotKeyID: UInt32 = 2
    private static let signature: OSType = 0x47504F4C  // 'GPOL' (GrammarPOLice)
    
    init() {
        self.grammarHotkey = SettingsManager.shared.grammarHotkey
        self.translateHotkey = SettingsManager.shared.translateHotkey
        self.wasAccessibilityGranted = AXIsProcessTrusted()
    }
    
    deinit {
        // deinit is not MainActor-isolated; the Carbon C calls below are safe
        // to invoke from any thread.
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
        }
        if let ref = grammarHotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let ref = translateHotKeyRef {
            UnregisterEventHotKey(ref)
        }
        permissionCheckTimer?.invalidate()
    }
    
    // MARK: - Registration
    
    func registerHotkeys() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            LoggingService.shared.log("Accessibility permission not granted. Hotkeys will fire but text selection will be unavailable until granted.", level: .warning)
        }
        
        installEventHandlerIfNeeded()
        
        guard eventHandlerRef != nil else {
            LoggingService.shared.log("Skipping hotkey registration: Carbon event handler failed to install.", level: .error)
            return
        }
        
        registerCarbonHotkey(config: grammarHotkey, id: Self.grammarHotKeyID, into: &grammarHotKeyRef)
        registerCarbonHotkey(config: translateHotkey, id: Self.translateHotKeyID, into: &translateHotKeyRef)
        
        if grammarHotKeyRef != nil || translateHotKeyRef != nil {
            LoggingService.shared.log("Hotkeys registered (Carbon) - Grammar: \(grammarHotkey.displayString), Translate: \(translateHotkey.displayString)", level: .info)
        } else {
            LoggingService.shared.log("Failed to register any global hotkeys.", level: .error)
        }
        
        if !trusted {
            startPermissionPolling()
        }
    }
    
    func unregisterAllHotkeys() {
        if let ref = grammarHotKeyRef {
            UnregisterEventHotKey(ref)
            grammarHotKeyRef = nil
        }
        if let ref = translateHotKeyRef {
            UnregisterEventHotKey(ref)
            translateHotKeyRef = nil
        }
        LoggingService.shared.log("Hotkeys unregistered", level: .info)
    }
    
    func updateHotkeys() {
        grammarHotkey = SettingsManager.shared.grammarHotkey
        translateHotkey = SettingsManager.shared.translateHotkey
        
        installEventHandlerIfNeeded()
        registerCarbonHotkey(config: grammarHotkey, id: Self.grammarHotKeyID, into: &grammarHotKeyRef)
        registerCarbonHotkey(config: translateHotkey, id: Self.translateHotKeyID, into: &translateHotKeyRef)
        
        LoggingService.shared.log("Hotkeys updated - Grammar: \(grammarHotkey.displayString), Translate: \(translateHotkey.displayString)", level: .info)
    }
    
    // MARK: - Carbon helpers
    
    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            hotKeyEventHandlerCallback,
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
        
        if status != noErr {
            LoggingService.shared.log("InstallEventHandler failed (status=\(status))", level: .error)
            eventHandlerRef = nil
        }
    }
    
    private func registerCarbonHotkey(config: HotkeyConfig, id: UInt32, into ref: inout EventHotKeyRef?) {
        if let existing = ref {
            UnregisterEventHotKey(existing)
            ref = nil
        }
        
        // No modifiers means hotkey is unset; skip so we don't grab a bare key globally.
        guard config.modifiers != 0 else {
            LoggingService.shared.log("Skipping hotkey id=\(id) (no modifiers configured)", level: .debug)
            return
        }
        
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            config.keyCode,
            config.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &newRef
        )
        
        if status == noErr {
            ref = newRef
        } else {
            LoggingService.shared.log("RegisterEventHotKey failed (id=\(id), status=\(status))", level: .error)
            ref = nil
        }
    }
    
    // MARK: - Dispatch (called from the Carbon C callback)
    
    fileprivate func handleHotKeyFired(id: UInt32) {
        if id == Self.grammarHotKeyID {
            LoggingService.shared.log("Grammar hotkey triggered", level: .debug)
            onGrammarCorrect?()
        } else if id == Self.translateHotKeyID {
            LoggingService.shared.log("Translate hotkey triggered", level: .debug)
            onTranslate?()
        }
    }
    
    // MARK: - Permission Polling
    
    private func startPermissionPolling() {
        permissionCheckTimer?.invalidate()
        // Use target/selector to avoid capturing `self` in a @Sendable closure
        let timer = Timer(timeInterval: 1.0, target: self, selector: #selector(permissionTimerFired(_:)), userInfo: nil, repeats: true)
        permissionCheckTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func permissionTimerFired(_ timer: Timer) {
        // We are already on the main run loop; ensure main-actor isolation
        Task { @MainActor in
            self.checkAndReregisterIfNeeded()
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
            
            unregisterAllHotkeys()
            installEventHandlerIfNeeded()
            registerCarbonHotkey(config: grammarHotkey, id: Self.grammarHotKeyID, into: &grammarHotKeyRef)
            registerCarbonHotkey(config: translateHotkey, id: Self.translateHotKeyID, into: &translateHotKeyRef)
            
            LoggingService.shared.log("Hotkeys re-registered after permission grant", level: .info)
        }
    }
}

// MARK: - Carbon Event Handler (C callback)

private let hotKeyEventHandlerCallback: EventHandlerUPP = { (_, theEvent, userData) -> OSStatus in
    guard let userData, let theEvent else {
        return OSStatus(eventNotHandledErr)
    }
    
    var hkID = EventHotKeyID()
    let status = GetEventParameter(
        theEvent,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hkID
    )
    guard status == noErr else { return status }
    
    let firedID = hkID.id
    
    Task { @MainActor in
        let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
        manager.handleHotKeyFired(id: firedID)
    }
    
    return noErr
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
