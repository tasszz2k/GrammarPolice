//
//  SettingsManager.swift
//  GrammarPolice
//
//  Central settings management using UserDefaults with JSON serialization
//

import Foundation
import Combine
import ServiceManagement

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    private let settingsKey = "GrammarPoliceSettings"
    
    @Published private(set) var settings: AppSettings
    
    private init() {
        settings = SettingsManager.loadSettings()
    }
    
    // MARK: - Persistence
    
    private static func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "GrammarPoliceSettings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }
    
    private func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            defaults.set(data, forKey: settingsKey)
            LoggingService.shared.log("Settings saved", level: .debug)
        } catch {
            LoggingService.shared.log("Failed to save settings: \(error)", level: .error)
        }
    }
    
    // MARK: - General Settings
    
    var launchAtLogin: Bool {
        get { settings.launchAtLogin }
        set {
            settings.launchAtLogin = newValue
            saveSettings()
            updateLoginItem(enabled: newValue)
        }
    }
    
    var grammarHotkey: HotkeyConfig {
        get { settings.grammarHotkey }
        set {
            settings.grammarHotkey = newValue
            saveSettings()
        }
    }
    
    var translateHotkey: HotkeyConfig {
        get { settings.translateHotkey }
        set {
            settings.translateHotkey = newValue
            saveSettings()
        }
    }
    
    var restoreClipboard: Bool {
        get { settings.restoreClipboard }
        set {
            settings.restoreClipboard = newValue
            saveSettings()
        }
    }
    
    // MARK: - Grammar Settings
    
    var grammarMode: GrammarMode {
        get { settings.grammarMode }
        set {
            settings.grammarMode = newValue
            saveSettings()
        }
    }
    
    var customSystemPrompt: String {
        get { settings.customSystemPrompt }
        set {
            settings.customSystemPrompt = newValue
            saveSettings()
        }
    }
    
    var customUserPrompt: String {
        get { settings.customUserPrompt }
        set {
            settings.customUserPrompt = newValue
            saveSettings()
        }
    }
    
    var outputFormat: OutputFormat {
        get { settings.outputFormat }
        set {
            settings.outputFormat = newValue
            saveSettings()
        }
    }
    
    // MARK: - Translation Settings
    
    var targetLanguage: String {
        get { settings.targetLanguage }
        set {
            settings.targetLanguage = newValue
            saveSettings()
        }
    }
    
    // MARK: - LLM Settings
    
    var llmBackend: LLMBackend {
        get { settings.llmBackend }
        set {
            settings.llmBackend = newValue
            saveSettings()
        }
    }
    
    var openAIModel: String {
        get { settings.openAIModel }
        set {
            settings.openAIModel = newValue
            saveSettings()
        }
    }
    
    var temperature: Double {
        get { settings.temperature }
        set {
            settings.temperature = newValue
            saveSettings()
        }
    }
    
    var maxTokens: Int {
        get { settings.maxTokens }
        set {
            settings.maxTokens = newValue
            saveSettings()
        }
    }
    
    var timeout: TimeInterval {
        get { settings.timeout }
        set {
            settings.timeout = newValue
            saveSettings()
        }
    }
    
    // MARK: - Local LLM Settings
    
    var localLLMMode: LocalLLMMode {
        get { settings.localLLMMode }
        set {
            settings.localLLMMode = newValue
            saveSettings()
        }
    }
    
    var localLLMCommand: String {
        get { settings.localLLMCommand }
        set {
            settings.localLLMCommand = newValue
            saveSettings()
        }
    }
    
    var localLLMEndpoint: String {
        get { settings.localLLMEndpoint }
        set {
            settings.localLLMEndpoint = newValue
            saveSettings()
        }
    }
    
    // MARK: - Custom Words Settings
    
    var caseSensitiveMatching: Bool {
        get { settings.caseSensitiveMatching }
        set {
            settings.caseSensitiveMatching = newValue
            saveSettings()
        }
    }
    
    var wholeWordMatching: Bool {
        get { settings.wholeWordMatching }
        set {
            settings.wholeWordMatching = newValue
            saveSettings()
        }
    }
    
    // MARK: - Safety Settings
    
    var maxCharacters: Int {
        get { settings.maxCharacters }
        set {
            settings.maxCharacters = newValue
            saveSettings()
        }
    }
    
    // MARK: - Debug Settings
    
    var debugLoggingEnabled: Bool {
        get { settings.debugLoggingEnabled }
        set {
            settings.debugLoggingEnabled = newValue
            saveSettings()
        }
    }
    
    var logVerbosity: Int {
        get { settings.logVerbosity }
        set {
            settings.logVerbosity = newValue
            saveSettings()
        }
    }
    
    // MARK: - Privacy Settings
    
    var hasShownPrivacyConsent: Bool {
        get { settings.hasShownPrivacyConsent }
        set {
            settings.hasShownPrivacyConsent = newValue
            saveSettings()
        }
    }
    
    var privacyConsentGranted: Bool {
        get { settings.privacyConsentGranted }
        set {
            settings.privacyConsentGranted = newValue
            saveSettings()
        }
    }
    
    // MARK: - History Settings
    
    var historyRetentionDays: Int {
        get { settings.historyRetentionDays }
        set {
            settings.historyRetentionDays = newValue
            saveSettings()
        }
    }
    
    // MARK: - Prompt Generation
    
    func getGrammarPrompt(for maskedText: String) -> (system: String, user: String) {
        let systemPrompt: String
        let userPromptTemplate: String
        
        switch grammarMode {
        case .minimal:
            systemPrompt = grammarMode.systemPrompt
            userPromptTemplate = grammarMode.userPrompt
        case .friendly:
            systemPrompt = grammarMode.systemPrompt
            userPromptTemplate = grammarMode.userPrompt
        case .work:
            systemPrompt = grammarMode.systemPrompt
            userPromptTemplate = grammarMode.userPrompt
        case .custom:
            systemPrompt = customSystemPrompt
            userPromptTemplate = customUserPrompt
        }
        
        let userPrompt = "\(userPromptTemplate)\n\n\(maskedText)"
        return (systemPrompt, userPrompt)
    }
    
    func getTranslationPrompt(for maskedText: String) -> (system: String, user: String) {
        let systemPrompt = "You are a translation assistant."
        let userPrompt = "Translate the following text into \(targetLanguage). Preserve named entities and tokens like __CWORD_n__ unchanged. Return only the translated text, no quotes, no commentary.\n\n\(maskedText)"
        return (systemPrompt, userPrompt)
    }
    
    // MARK: - Launch at Login
    
    private func updateLoginItem(enabled: Bool) {
        // Using SMAppService for macOS 13+
        // Note: This requires the app to be properly signed
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            LoggingService.shared.log("Failed to update login item: \(error)", level: .error)
        }
    }
    
    // MARK: - Reset
    
    func resetToDefaults() {
        settings = AppSettings()
        saveSettings()
        LoggingService.shared.log("Settings reset to defaults", level: .info)
    }
}

