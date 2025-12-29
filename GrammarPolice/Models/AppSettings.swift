//
//  AppSettings.swift
//  GrammarPolice
//
//  Settings data model for the application
//

import Foundation

// MARK: - Grammar Mode

enum GrammarMode: String, Codable, CaseIterable {
    case minimal = "Minimal"
    case friendly = "Friendly"
    case work = "Work"
    case custom = "Custom"
    
    var systemPrompt: String {
        switch self {
        case .minimal:
            return "You are a careful grammar assistant."
        case .friendly:
            return "You are a helpful friendly-writing assistant."
        case .work:
            return "You are a professional business writing assistant."
        case .custom:
            return ""
        }
    }
    
    var userPrompt: String {
        switch self {
        case .minimal:
            return "Correct only the grammar of the following text. Make the minimal necessary edits, preserve meaning and tone, and return only the corrected text with no extra commentary."
        case .friendly:
            return "Correct grammar and adjust tone to be friendly while preserving meaning. Return only the corrected text, no commentary."
        case .work:
            return "Correct grammar and adjust tone to be professional and suitable for business communication. Return only the corrected text, no commentary."
        case .custom:
            return ""
        }
    }
}

// MARK: - Output Format

enum OutputFormat: String, Codable, CaseIterable {
    case original = "Original"
    case slack = "Slack Format"
    case preserveRTF = "Preserve RTF"
}

// MARK: - LLM Backend

enum LLMBackend: String, Codable, CaseIterable {
    case openAI = "OpenAI"
    case localLLM = "Local LLM"
}

// MARK: - Local LLM Mode

enum LocalLLMMode: String, Codable, CaseIterable {
    case cli = "CLI Command"
    case http = "HTTP Endpoint"
}

// MARK: - Hotkey Configuration

struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    
    static let defaultGrammar = HotkeyConfig(keyCode: 5, modifiers: 4352)  // Ctrl+Cmd+G
    static let defaultTranslate = HotkeyConfig(keyCode: 17, modifiers: 4352)  // Ctrl+Cmd+T
    
    var displayString: String {
        var parts: [String] = []
        
        if modifiers & 256 != 0 { parts.append("Cmd") }
        if modifiers & 512 != 0 { parts.append("Shift") }
        if modifiers & 2048 != 0 { parts.append("Option") }
        if modifiers & 4096 != 0 { parts.append("Control") }
        
        let keyName = KeyCodeMap.keyName(for: keyCode)
        parts.append(keyName)
        
        return parts.joined(separator: "+")
    }
}

// MARK: - Key Code Map

enum KeyCodeMap {
    static func keyName(for keyCode: UInt32) -> String {
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
            50: "`", 51: "Delete", 53: "Escape"
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }
}

// MARK: - App Settings

struct AppSettings: Codable {
    // General
    var launchAtLogin: Bool = false
    var grammarHotkey: HotkeyConfig = .defaultGrammar
    var translateHotkey: HotkeyConfig = .defaultTranslate
    var restoreClipboard: Bool = true
    
    // Grammar
    var grammarMode: GrammarMode = .minimal
    var customSystemPrompt: String = ""
    var customUserPrompt: String = ""
    var outputFormat: OutputFormat = .original
    
    // Translation
    var targetLanguage: String = "Vietnamese"
    
    // LLM
    var llmBackend: LLMBackend = .openAI
    var openAIModel: String = "gpt-4o-mini"
    var temperature: Double = 0.0
    var maxTokens: Int = 300
    var timeout: TimeInterval = 30.0
    
    // Local LLM
    var localLLMMode: LocalLLMMode = .http
    var localLLMCommand: String = ""
    var localLLMEndpoint: String = "http://localhost:11434"
    
    // Custom Words
    var caseSensitiveMatching: Bool = false
    var wholeWordMatching: Bool = true
    
    // Safety
    var maxCharacters: Int = 2000
    
    // Debug
    var debugLoggingEnabled: Bool = false
    var logVerbosity: Int = 1
    
    // Privacy
    var hasShownPrivacyConsent: Bool = false
    var privacyConsentGranted: Bool = false
    
    // History
    var historyRetentionDays: Int = 30
}

