//
//  TranslationFlow.swift
//  GrammarPolice
//
//  Orchestrates the translation flow
//

import Foundation
import SwiftData

@MainActor
final class TranslationFlow {
    
    private let modelContext: ModelContext
    private let axService = AXSelectionService.shared
    private let clipboardService = ClipboardService.shared
    private let maskingService = MaskingService.shared
    private let notificationService = NotificationService.shared
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func execute() async {
        let startTime = Date()
        
        // Get app info
        let appInfo = axService.getFocusedAppInfo()
        let appName = appInfo?.appName ?? "Unknown"
        let appBundle = appInfo?.bundleIdentifier ?? ""
        
        LoggingService.shared.logHotkeyPress(
            sourceApp: appName,
            selectedTextLength: 0,
            mode: "translate"
        )
        
        // Step 1: Get selected text
        var selectedText: String?
        
        do {
            selectedText = try axService.getSelectedText()
        } catch AXError.secureTextField {
            notificationService.showSecureFieldWarning()
            return
        } catch AXError.noSelectedText {
            // Try fallback
            selectedText = await clipboardService.captureSelectedTextViaCopy()
        } catch {
            // Try fallback
            selectedText = await clipboardService.captureSelectedTextViaCopy()
        }
        
        guard let text = selectedText, !text.isEmpty else {
            notificationService.showNoTextSelected()
            LoggingService.shared.log("No text selected for translation", level: .warning)
            return
        }
        
        LoggingService.shared.log("Got selected text for translation, length: \(text.count)", level: .debug)
        
        // Step 2: Check text length
        let maxChars = SettingsManager.shared.maxCharacters
        if text.count > maxChars {
            notificationService.showTextTooLong(current: text.count, max: maxChars)
            return
        }
        
        // Step 3: Mask custom words
        let maskResult = maskingService.maskCustomWords(in: text)
        LoggingService.shared.logLLMRequest(
            backend: SettingsManager.shared.llmBackend.rawValue,
            maskedTokensCount: maskResult.mapping.count
        )
        
        // Step 4: Send to LLM for translation
        var translatedMasked: String
        var latencyMs: Int
        let targetLanguage = SettingsManager.shared.targetLanguage
        
        do {
            let result: (result: String, latencyMs: Int)
            
            if SettingsManager.shared.llmBackend == .openAI {
                result = try await LLMClient.shared.translate(maskResult.maskedText)
            } else {
                result = try await LocalLLMRunner.shared.translate(maskResult.maskedText)
            }
            
            translatedMasked = result.result
            latencyMs = result.latencyMs
            
        } catch LLMError.privacyConsentRequired {
            notificationService.showPrivacyConsentRequired()
            return
        } catch LLMError.textTooLong(let current, let max) {
            notificationService.showTextTooLong(current: current, max: max)
            return
        } catch {
            notificationService.showError(error.localizedDescription)
            LoggingService.shared.log("Translation LLM error: \(error)", level: .error)
            saveHistory(
                input: text,
                output: "",
                appBundle: appBundle,
                appName: appName,
                success: false,
                customWordsUsed: maskResult.tokensUsed,
                targetLanguage: targetLanguage,
                latencyMs: 0
            )
            return
        }
        
        // Step 5: Unmask tokens
        let translatedText = maskingService.unmaskTokens(in: translatedMasked, using: maskResult.mapping)
        
        // Step 6: Copy to clipboard (always for translation)
        clipboardService.setText(translatedText)
        notificationService.showTranslationComplete(preview: translatedText, targetLanguage: targetLanguage)
        LoggingService.shared.log("Translation copied to clipboard", level: .debug)
        
        // Step 7: Save to history
        saveHistory(
            input: text,
            output: translatedText,
            appBundle: appBundle,
            appName: appName,
            success: true,
            customWordsUsed: maskResult.tokensUsed,
            targetLanguage: targetLanguage,
            latencyMs: latencyMs
        )
        
        let totalTime = Int(Date().timeIntervalSince(startTime) * 1000)
        LoggingService.shared.log("Translation completed in \(totalTime)ms", level: .info)
    }
    
    private func saveHistory(
        input: String,
        output: String,
        appBundle: String,
        appName: String,
        success: Bool,
        customWordsUsed: [String],
        targetLanguage: String,
        latencyMs: Int
    ) {
        let store = HistoryStore(modelContext: modelContext)
        store.addEntry(
            input: input,
            output: output,
            mode: .translate,
            appBundleIdentifier: appBundle,
            appName: appName,
            success: success,
            replacementDone: false,  // Translation always copies to clipboard
            customWordsUsed: customWordsUsed,
            sourceLanguage: "auto",  // Could detect source language
            targetLanguage: targetLanguage,
            llmBackend: SettingsManager.shared.llmBackend.rawValue,
            llmLatencyMs: latencyMs
        )
    }
}

