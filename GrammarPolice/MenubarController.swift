//
//  MenubarController.swift
//  GrammarPolice
//
//  Manages the menubar status item and dropdown menu
//

import AppKit
import SwiftUI

@MainActor
final class MenubarController {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    
    private let onOpenPreferences: () -> Void
    private let onGrammarCorrect: () -> Void
    private let onTranslate: () -> Void
    private let onQuit: () -> Void
    
    init(
        onOpenPreferences: @escaping () -> Void,
        onGrammarCorrect: @escaping () -> Void,
        onTranslate: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onOpenPreferences = onOpenPreferences
        self.onGrammarCorrect = onGrammarCorrect
        self.onTranslate = onTranslate
        self.onQuit = onQuit
        
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Use SF Symbol for the menubar icon
            if let image = NSImage(systemSymbolName: "text.badge.checkmark", accessibilityDescription: "GrammarPolice") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "GP"
            }
            button.toolTip = "GrammarPolice"
        }
        
        setupMenu()
        statusItem?.menu = menu
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        // Grammar Correct
        let grammarItem = NSMenuItem(
            title: "Correct Grammar",
            action: #selector(grammarCorrectClicked),
            keyEquivalent: ""
        )
        grammarItem.target = self
        grammarItem.keyEquivalentModifierMask = [.command, .option]
        grammarItem.keyEquivalent = "g"
        menu?.addItem(grammarItem)
        
        // Translate
        let translateItem = NSMenuItem(
            title: "Translate",
            action: #selector(translateClicked),
            keyEquivalent: ""
        )
        translateItem.target = self
        translateItem.keyEquivalentModifierMask = [.command, .option]
        translateItem.keyEquivalent = "t"
        menu?.addItem(translateItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        // Status indicator
        let statusItem = NSMenuItem(title: "Status: Ready", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        statusItem.tag = 100  // Tag for updating later
        menu?.addItem(statusItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        // Preferences
        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(preferencesClicked),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        preferencesItem.keyEquivalentModifierMask = .command
        menu?.addItem(preferencesItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        // About
        let aboutItem = NSMenuItem(
            title: "About GrammarPolice",
            action: #selector(aboutClicked),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu?.addItem(aboutItem)
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit GrammarPolice",
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = .command
        menu?.addItem(quitItem)
    }
    
    // MARK: - Menu Actions
    
    @objc private func grammarCorrectClicked() {
        onGrammarCorrect()
    }
    
    @objc private func translateClicked() {
        onTranslate()
    }
    
    @objc private func preferencesClicked() {
        onOpenPreferences()
    }
    
    @objc private func aboutClicked() {
        showAboutWindow()
    }
    
    @objc private func quitClicked() {
        onQuit()
    }
    
    // MARK: - Status Updates
    
    func updateStatus(_ status: String) {
        if let statusItem = menu?.item(withTag: 100) {
            statusItem.title = "Status: \(status)"
        }
    }
    
    func setProcessing(_ processing: Bool) {
        if let button = statusItem?.button {
            if processing {
                // Could add animation here
                button.alphaValue = 0.5
                updateStatus("Processing...")
            } else {
                button.alphaValue = 1.0
                updateStatus("Ready")
            }
        }
    }
    
    // MARK: - About Window
    
    private func showAboutWindow() {
        let alert = NSAlert()
        alert.messageText = "GrammarPolice"
        alert.informativeText = """
            Version 1.0
            
            A macOS menubar app for grammar correction and translation.
            
            Hotkeys:
            - Cmd+Shift+G: Correct Grammar
            - Cmd+Shift+T: Translate
            
            Select text in any app and press the hotkey to correct or translate.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

