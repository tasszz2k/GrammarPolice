//
//  AppDelegate.swift
//  GrammarPolice
//
//  Created by GrammarPolice on 2025.
//

import AppKit
import SwiftUI
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem?
    private var preferencesWindow: NSWindow?
    private var menubarController: MenubarController?
    private var hotkeyManager: HotkeyManager?
    private var modelContainer: ModelContainer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupModelContainer()
        setupMenubar()
        setupHotkeys()
        checkAccessibilityPermission()
        requestNotificationPermission()
        checkPrivacyConsent()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregisterAllHotkeys()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Setup
    
    private func setupModelContainer() {
        do {
            let schema = Schema([HistoryEntry.self])
            let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            LoggingService.shared.log("SwiftData model container initialized", level: .info)
        } catch {
            LoggingService.shared.log("Failed to create model container: \(error)", level: .error)
        }
    }
    
    private func setupMenubar() {
        menubarController = MenubarController(
            onOpenPreferences: { [weak self] in self?.openPreferences() },
            onGrammarCorrect: { [weak self] in self?.performGrammarCorrection() },
            onTranslate: { [weak self] in self?.performTranslation() },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
    }
    
    private func setupHotkeys() {
        hotkeyManager = HotkeyManager()
        hotkeyManager?.onGrammarCorrect = { [weak self] in
            Task { @MainActor in
                self?.performGrammarCorrection()
            }
        }
        hotkeyManager?.onTranslate = { [weak self] in
            Task { @MainActor in
                self?.performTranslation()
            }
        }
        hotkeyManager?.registerHotkeys()
    }
    
    // MARK: - Actions
    
    private func openPreferences() {
        if preferencesWindow == nil {
            let preferencesView = PreferencesView()
                .environment(\.modelContext, modelContainer?.mainContext ?? ModelContext(try! ModelContainer(for: HistoryEntry.self)))
            
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            preferencesWindow?.title = "GrammarPolice Preferences"
            preferencesWindow?.contentView = NSHostingView(rootView: preferencesView)
            preferencesWindow?.center()
            preferencesWindow?.setFrameAutosaveName("PreferencesWindow")
            preferencesWindow?.isReleasedWhenClosed = false
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func performGrammarCorrection() {
        guard let container = modelContainer else { return }
        
        Task {
            let flow = GrammarCorrectionFlow(modelContext: container.mainContext)
            await flow.execute()
        }
    }
    
    private func performTranslation() {
        guard let container = modelContainer else { return }
        
        Task {
            let flow = TranslationFlow(modelContext: container.mainContext)
            await flow.execute()
        }
    }
    
    // MARK: - Permissions
    
    private func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            LoggingService.shared.log("Accessibility permission not granted", level: .warning)
        } else {
            LoggingService.shared.log("Accessibility permission granted", level: .info)
        }
    }
    
    private func requestNotificationPermission() {
        NotificationService.shared.requestPermission()
    }
    
    private func checkPrivacyConsent() {
        if !SettingsManager.shared.hasShownPrivacyConsent && SettingsManager.shared.llmBackend == .openAI {
            showPrivacyConsentDialog()
        }
    }
    
    private func showPrivacyConsentDialog() {
        // Ensure we're on the main actor; this class is @MainActor but keep it explicit for clarity
        let alert = NSAlert()
        alert.messageText = "Privacy Notice"
        alert.informativeText = "GrammarPolice will send your selected text to OpenAI's servers for grammar correction and translation. Your text will be processed according to OpenAI's privacy policy.\n\nDo you consent to sending text to remote LLM services?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "I Consent")
        alert.addButton(withTitle: "Use Local LLM Only")

        // Present as a sheet to avoid blocking a high-QoS thread with runModal().
        // Prefer the preferences window if it's open; otherwise, fall back to the key window or a temporary window.
        let hostWindow: NSWindow? = self.preferencesWindow ?? NSApp.keyWindow ?? NSApp.mainWindow

        if let window = hostWindow {
            alert.beginSheetModal(for: window) { response in
                // Handle the user's choice without blocking.
                if response == .alertFirstButtonReturn {
                    SettingsManager.shared.privacyConsentGranted = true
                } else {
                    SettingsManager.shared.llmBackend = .localLLM
                    SettingsManager.shared.privacyConsentGranted = false
                }
                SettingsManager.shared.hasShownPrivacyConsent = true
            }
        } else {
            // If there is no window to attach a sheet to, create a temporary panel to host the sheet.
            let tempWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            tempWindow.isReleasedWhenClosed = false
            tempWindow.alphaValue = 0.0
            tempWindow.orderFrontRegardless()
            alert.beginSheetModal(for: tempWindow) { response in
                if response == .alertFirstButtonReturn {
                    SettingsManager.shared.privacyConsentGranted = true
                } else {
                    SettingsManager.shared.llmBackend = .localLLM
                    SettingsManager.shared.privacyConsentGranted = false
                }
                SettingsManager.shared.hasShownPrivacyConsent = true
                tempWindow.close()
            }
        }
    }
}

