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
        
        // Check Accessibility permission first
        if !axService.isAccessibilityEnabled {
            notificationService.showAccessibilityPermissionRequired()
            LoggingService.shared.log("Accessibility permission not granted", level: .warning)
            // Still try to open the permission prompt
            _ = axService.checkAndRequestAccessibility()
            return
        }
        
        // Check LLM configuration
        if !isLLMConfigured() {
            return
        }
        
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
        var usedFallback = false
        
        // For apps known to have AX issues (Electron apps, etc.), skip AX and go straight to clipboard
        if axService.isAppWithAXIssues() {
            LoggingService.shared.log("App known to have AX issues, using clipboard fallback directly", level: .debug)
            usedFallback = true
            selectedText = await clipboardService.captureSelectedTextViaCopy()
        } else {
            do {
                selectedText = try axService.getSelectedText()
            } catch AXError.secureTextField {
                notificationService.showSecureFieldWarning()
                return
            } catch AXError.noSelectedText {
                // Try fallback
                usedFallback = true
                selectedText = await clipboardService.captureSelectedTextViaCopy()
            } catch {
                // Try fallback
                usedFallback = true
                selectedText = await clipboardService.captureSelectedTextViaCopy()
            }
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
    
    private func isLLMConfigured() -> Bool {
        let settings = SettingsManager.shared
        
        if settings.llmBackend == .openAI {
            if !KeychainService.shared.hasOpenAIAPIKey {
                notificationService.showAPIKeyNotSet()
                LoggingService.shared.log("OpenAI API key not set", level: .warning)
                return false
            }
        } else {
            // Local LLM
            if settings.localLLMMode == .cli && settings.localLLMCommand.isEmpty {
                notificationService.showLocalLLMNotConfigured()
                LoggingService.shared.log("Local LLM command not configured", level: .warning)
                return false
            }
            if settings.localLLMMode == .http && settings.localLLMEndpoint.isEmpty {
                notificationService.showLocalLLMNotConfigured()
                LoggingService.shared.log("Local LLM endpoint not configured", level: .warning)
                return false
            }
        }
        
        return true
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

