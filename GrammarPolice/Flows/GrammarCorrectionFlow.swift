//
//  GrammarCorrectionFlow.swift
//  GrammarPolice
//
//  Orchestrates the grammar correction flow
//

import Foundation
import SwiftData

@MainActor
final class GrammarCorrectionFlow {
    
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
            mode: "grammar"
        )
        
        // Step 1: Get selected text
        var selectedText: String?
        var usedFallback = false
        
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
        
        guard let text = selectedText, !text.isEmpty else {
            notificationService.showNoTextSelected()
            LoggingService.shared.log("No text selected", level: .warning)
            return
        }
        
        LoggingService.shared.log("Got selected text, length: \(text.count), usedFallback: \(usedFallback)", level: .debug)
        
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
        
        // Step 4: Send to LLM
        var correctedMasked: String
        var latencyMs: Int
        
        do {
            let result: (result: String, latencyMs: Int)
            
            if SettingsManager.shared.llmBackend == .openAI {
                result = try await LLMClient.shared.correctGrammar(maskResult.maskedText)
            } else {
                result = try await LocalLLMRunner.shared.correctGrammar(maskResult.maskedText)
            }
            
            correctedMasked = result.result
            latencyMs = result.latencyMs
            
        } catch LLMError.privacyConsentRequired {
            notificationService.showPrivacyConsentRequired()
            return
        } catch LLMError.textTooLong(let current, let max) {
            notificationService.showTextTooLong(current: current, max: max)
            return
        } catch {
            notificationService.showError(error.localizedDescription)
            LoggingService.shared.log("LLM error: \(error)", level: .error)
            saveHistory(
                input: text,
                output: "",
                appBundle: appBundle,
                appName: appName,
                success: false,
                replacementDone: false,
                customWordsUsed: maskResult.tokensUsed,
                latencyMs: 0
            )
            return
        }
        
        // Step 5: Unmask tokens
        let correctedText = maskingService.unmaskTokens(in: correctedMasked, using: maskResult.mapping)
        
        // Step 6: Replace text
        var replacementDone = false
        
        // Only try AX replacement if we didn't use fallback and AX replacement is likely to work
        if !usedFallback && axService.canReplaceText() {
            do {
                try axService.replaceSelectedText(with: correctedText)
                replacementDone = true
                notificationService.showGrammarCorrectionSuccess(preview: correctedText)
                LoggingService.shared.logReplacement(success: true, method: "AX")
            } catch {
                LoggingService.shared.log("AX replacement failed: \(error)", level: .debug)
            }
        }
        
        // If AX replacement failed or wasn't attempted, copy to clipboard
        if !replacementDone {
            clipboardService.setText(correctedText)
            notificationService.showGrammarCopiedToClipboard(preview: correctedText)
            LoggingService.shared.logReplacement(success: false, method: "Clipboard")
        }
        
        // Step 7: Save to history
        saveHistory(
            input: text,
            output: correctedText,
            appBundle: appBundle,
            appName: appName,
            success: true,
            replacementDone: replacementDone,
            customWordsUsed: maskResult.tokensUsed,
            latencyMs: latencyMs
        )
        
        // Restore clipboard if needed
        if replacementDone && SettingsManager.shared.restoreClipboard {
            clipboardService.restoreClipboardState()
        }
        
        let totalTime = Int(Date().timeIntervalSince(startTime) * 1000)
        LoggingService.shared.log("Grammar correction completed in \(totalTime)ms", level: .info)
    }
    
    private func saveHistory(
        input: String,
        output: String,
        appBundle: String,
        appName: String,
        success: Bool,
        replacementDone: Bool,
        customWordsUsed: [String],
        latencyMs: Int
    ) {
        let store = HistoryStore(modelContext: modelContext)
        store.addEntry(
            input: input,
            output: output,
            mode: .grammar,
            appBundleIdentifier: appBundle,
            appName: appName,
            success: success,
            replacementDone: replacementDone,
            customWordsUsed: customWordsUsed,
            sourceLanguage: "en",
            targetLanguage: "",
            llmBackend: SettingsManager.shared.llmBackend.rawValue,
            llmLatencyMs: latencyMs
        )
    }
}

