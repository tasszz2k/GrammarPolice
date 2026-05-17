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

    var contextWindowChars: Int {
        get { settings.contextWindowChars }
        set {
            settings.contextWindowChars = newValue
            saveSettings()
        }
    }

    var globalContext: String {
        get { settings.globalContext }
        set {
            settings.globalContext = newValue
            saveSettings()
        }
    }

    var grammarExploreEnabled: Bool {
        get { settings.grammarExploreEnabled }
        set {
            settings.grammarExploreEnabled = newValue
            saveSettings()
        }
    }

    var notificationDurationSec: Double {
        get { settings.notificationDurationSec }
        set {
            settings.notificationDurationSec = newValue
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

    var translationMode: TranslationMode {
        get { settings.translationMode }
        set {
            settings.translationMode = newValue
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

    var monthlyCostCapUSD: Double {
        get { settings.monthlyCostCapUSD }
        set {
            settings.monthlyCostCapUSD = newValue
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
    
    var autoExportEnabled: Bool {
        get { settings.autoExportEnabled }
        set { settings.autoExportEnabled = newValue; saveSettings() }
    }
    
    var autoExportFolderPath: String {
        get { settings.autoExportFolderPath }
        set { settings.autoExportFolderPath = newValue; saveSettings() }
    }
    
    var autoExportPrefix: String {
        get { settings.autoExportPrefix }
        set { settings.autoExportPrefix = newValue; saveSettings() }
    }
    
    var lastAutoExportDate: Date? {
        get { settings.lastAutoExportDate }
        set { settings.lastAutoExportDate = newValue; saveSettings() }
    }
    
    // MARK: - Prompt Generation
    
    func getGrammarPrompt(for maskedText: String, context: String? = nil) -> (system: String, user: String) {
        var systemPrompt: String
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

        systemPrompt = injectGlobalContext(into: systemPrompt)

        let userPrompt: String
        if let ctx = context, !ctx.isEmpty, ctx != maskedText {
            userPrompt = "\(userPromptTemplate)\n\nText to correct:\n\(maskedText)\n\nSurrounding context (for reference only, do not include in output):\n\(ctx)"
        } else {
            userPrompt = "\(userPromptTemplate)\n\n\(maskedText)"
        }
        return (systemPrompt, userPrompt)
    }

    func getTranslationPrompt(for maskedText: String, context: String? = nil) -> (system: String, user: String) {
        switch translationMode {
        case .simple:
            return buildSimpleTranslationPrompt(for: maskedText, context: context)
        case .explore:
            return buildExploreTranslationPrompt(for: maskedText, context: context)
        }
    }

    private func buildSimpleTranslationPrompt(for maskedText: String, context: String?) -> (system: String, user: String) {
        var systemPrompt = "You are a translation assistant that can translate from any language."
        systemPrompt = injectGlobalContext(into: systemPrompt)
        let userPromptTemplate = "Detect the source language and translate the following text into \(targetLanguage). Preserve named entities, and copy any placeholder tokens matching the pattern __CWORD_<digits>__ (for example __CWORD_0__, __CWORD_1__) verbatim with their digits intact. Return only the translated text, no quotes, no commentary."
        let userPrompt: String
        if let ctx = context, !ctx.isEmpty, ctx != maskedText {
            userPrompt = "\(userPromptTemplate)\n\nText to translate:\n\(maskedText)\n\nSurrounding context (for reference only, do not include in output):\n\(ctx)"
        } else {
            userPrompt = "\(userPromptTemplate)\n\n\(maskedText)"
        }
        return (systemPrompt, userPrompt)
    }

    private func buildExploreTranslationPrompt(for maskedText: String, context: String?) -> (system: String, user: String) {
        var systemPrompt = """
        You are a bilingual language tutor helping a learner of \(targetLanguage).
        The user gives a single word, phrase, idiom, or short sentence in the source language.

        Output MUST be split into TWO blocks separated by a line containing EXACTLY:
        ---EXPLORE---

        BLOCK 1 (before the separator): the plain translation into \(targetLanguage) only. No labels, no part of speech, no IPA, no extra commentary. One short line for a word or phrase; a full clean translation for a sentence.

        BLOCK 2 (after the separator): a compact "explore" entry that teaches the item.
        Output rules for block 2:
        - Plain text only. No markdown code fences. No surrounding quotes.
        - Include only the sections that apply. Skip the rest entirely (do not write empty labels).
        - Keep it dense: every line carries weight. No filler restatements.
        - Use the surrounding context (if given) to choose the sense that fits. Do NOT echo the context.
        - Copy any placeholder tokens matching __CWORD_<digits>__ verbatim.

        Section order for block 2, when applicable:
        1. Headword line: <original> - <part_of_speech> · /<IPA or romanization if helpful>/ · <register if non-neutral>
        2. Meaning: numbered senses "1. <\(targetLanguage) gloss> - <short English gloss>"
        3. Examples: 1-2 natural example sentences in the source language. Under each, the \(targetLanguage) translation prefixed with "-> ".
        4. Word family: derived forms with POS tags, e.g. "supersede (v), supersession (n), superseded (adj)".
        5. Collocations: 3-5 common collocations.
        6. Synonyms: comma-separated, source language.
        7. Antonyms: comma-separated, source language (only if meaningful).
        8. Contrast: one short note distinguishing the headword from its closest near-synonym.
        9. Note: register, formality, false-friend warning, or domain (only if non-obvious).

        When the input is a full sentence rather than a vocabulary item, block 2 contains 1-3 short notes on idioms, tricky grammar, or notable vocabulary (NOT a repeat of the translation).

        Always emit both blocks and the separator, even if block 2 is short.
        """
        systemPrompt = injectGlobalContext(into: systemPrompt)

        let userPromptTemplate = "Explore the following text and produce the two-block output. Target language: \(targetLanguage)."
        let userPrompt: String
        if let ctx = context, !ctx.isEmpty, ctx != maskedText {
            userPrompt = "\(userPromptTemplate)\n\nText:\n\(maskedText)\n\nSurrounding context (for sense disambiguation only, do not include in output):\n\(ctx)"
        } else {
            userPrompt = "\(userPromptTemplate)\n\nText:\n\(maskedText)"
        }
        return (systemPrompt, userPrompt)
    }

    static let exploreSeparator = "---EXPLORE---"

    func getGrammarExplorePrompt(for maskedText: String, context: String? = nil) -> (system: String, user: String) {
        var systemPrompt = """
        You are an English writing coach helping a learner improve. Given a passage, return BOTH the corrected version and a structured lesson.

        Output MUST be split into TWO blocks separated by a line containing EXACTLY:
        \(Self.exploreSeparator)

        BLOCK 1 (before the separator): the corrected text only. Apply only the corrections you would normally make in the current grammar mode. Preserve meaning, voice, and structure. Copy any placeholder tokens matching __CWORD_<digits>__ verbatim. No commentary, no labels, no surrounding quotes.

        BLOCK 2 (after the separator): a compact lesson, plain text, no markdown fences. Use these section labels exactly, in order, and include only the sections that apply:

        Fixes:
        - For each correction: "<original phrase>" -> "<corrected phrase>" - <one-line reason>
        - One bullet per fix. Quote the exact substrings, not whole sentences.
        - If there are no corrections, write a single bullet "No changes needed - the text is already correct."

        Word notes:
        - Misused / weak word choices that were swapped, with a 1-line explanation per word. Skip if none.

        Rules applied:
        - Concise list of the grammar rules that drove the fixes (e.g. "subject-verb agreement", "article use with countable nouns"). 1-5 items.

        Lesson:
        - 2-4 sentence learner-facing takeaway. Focus on the underlying pattern, not the specific text. Reference one or two of the rules above so the learner can recognize this mistake next time.

        Keep it dense. No filler. No restating the input. Always emit both blocks and the separator.
        """
        systemPrompt = injectGlobalContext(into: systemPrompt)

        let userPromptTemplate = "Correct the following text and produce the two-block output."
        let userPrompt: String
        if let ctx = context, !ctx.isEmpty, ctx != maskedText {
            userPrompt = "\(userPromptTemplate)\n\nText to correct:\n\(maskedText)\n\nSurrounding context (for reference only, do not include in output):\n\(ctx)"
        } else {
            userPrompt = "\(userPromptTemplate)\n\nText:\n\(maskedText)"
        }
        return (systemPrompt, userPrompt)
    }

    private func injectGlobalContext(into systemPrompt: String) -> String {
        let ctx = globalContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ctx.isEmpty else { return systemPrompt }
        let block = "User-provided context (apply when interpreting tone, terminology, and intent; do not echo this context in your output):\n\(ctx)"
        if systemPrompt.isEmpty {
            return block
        }
        return "\(systemPrompt)\n\n\(block)"
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

