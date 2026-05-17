//
//  GrammarSettingsView.swift
//  GrammarPolice
//
//  Grammar mode selection and custom prompt configuration
//

import SwiftUI

struct GrammarSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    
    @State private var testInput = ""
    @State private var testOutput = ""
    @State private var isTesting = false
    
    private let suggestedLanguages = [
        "Vietnamese",
        "English",
        "Chinese (Simplified)",
        "Chinese (Traditional)",
        "Japanese",
        "Korean",
        "Spanish",
        "French",
        "German",
        "Italian",
        "Portuguese",
        "Russian",
        "Arabic",
        "Hindi",
        "Thai",
        "Indonesian"
    ]
    
    var body: some View {
        Form {
            Section {
                Picker("Grammar Mode:", selection: Binding(
                    get: { settings.grammarMode },
                    set: { settings.grammarMode = $0 }
                )) {
                    ForEach(GrammarMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(modeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Explore (show lesson instead of auto-replace)", isOn: Binding(
                    get: { settings.grammarExploreEnabled },
                    set: { settings.grammarExploreEnabled = $0 }
                ))
                Text("When on, the grammar hotkey does NOT replace selected text. Instead it shows a dialog with the original, the corrected version, and a structured lesson explaining the fixes. The corrected text is also copied to the clipboard.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Stepper(
                        String(format: "Notification duration: %.1fs", settings.notificationDurationSec),
                        value: Binding(
                            get: { settings.notificationDurationSec },
                            set: { settings.notificationDurationSec = $0 }
                        ),
                        in: 1.0...30.0,
                        step: 0.5
                    )
                }
                Text("How long the in-app toast stays on screen after a grammar correction. Toasts show the full corrected text without truncation.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Mode")
            }
            
            if settings.grammarMode == .custom {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("System Prompt:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: Binding(
                            get: { settings.customSystemPrompt },
                            set: { settings.customSystemPrompt = $0 }
                        ))
                        .frame(height: 60)
                        .font(.system(.body, design: .monospaced))
                        .border(Color.secondary.opacity(0.3))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("User Prompt:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: Binding(
                            get: { settings.customUserPrompt },
                            set: { settings.customUserPrompt = $0 }
                        ))
                        .frame(height: 60)
                        .font(.system(.body, design: .monospaced))
                        .border(Color.secondary.opacity(0.3))
                    }
                    
                    Text("Use {masked_text} as placeholder for the input text.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Custom Prompt")
                }
            }
            
            Section {
                Picker("Output Format:", selection: Binding(
                    get: { settings.outputFormat },
                    set: { settings.outputFormat = $0 }
                )) {
                    ForEach(OutputFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
            } header: {
                Text("Output")
            }

            Section {
                Stepper("Context Window: \(settings.contextWindowChars) chars",
                        value: Binding(
                            get: { settings.contextWindowChars },
                            set: { settings.contextWindowChars = $0 }
                        ),
                        in: 0...2000,
                        step: 50)

                Text("Characters captured before and after the selection. Sent to the LLM for reference. 0 disables surrounding-context capture.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Global Context:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: Binding(
                        get: { settings.globalContext },
                        set: { settings.globalContext = $0 }
                    ))
                    .frame(height: 100)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.secondary.opacity(0.3))

                    Text("Persistent context appended to every grammar/translation system prompt. Example: \"DevOps engineer at Axon. Writes professional Slack messages and emails in en-US. Prefers concise, technical language.\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Context")
            }
            
            Section {
                Picker("Target Language:", selection: Binding(
                    get: { settings.targetLanguage },
                    set: { settings.targetLanguage = $0 }
                )) {
                    ForEach(suggestedLanguages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }

                Picker("Translation Mode:", selection: Binding(
                    get: { settings.translationMode },
                    set: { settings.translationMode = $0 }
                )) {
                    ForEach(TranslationMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(translationModeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Translation")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Input:")
                        .font(.caption)
                    
                    TextField("", text: $testInput, prompt: Text("Enter text to test...").foregroundColor(.secondary))
                    
                    HStack {
                        Button("Test Grammar Correction") {
                            testGrammar()
                        }
                        .disabled(testInput.isEmpty || isTesting)
                        
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    
                    if !testOutput.isEmpty {
                        Text("Output:")
                            .font(.caption)
                        
                        Text(testOutput)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            } header: {
                Text("Test")
            }
        }
        .formStyle(.grouped)
    }
    
    private var translationModeDescription: String {
        switch settings.translationMode {
        case .simple:
            return "Plain translation into the target language. Returns only the translated text."
        case .explore:
            return "Learner mode. Returns a rich dictionary-style entry: meaning, part of speech, examples, word family, collocations, synonyms, contrast, and usage notes."
        }
    }

    private var modeDescription: String {
        switch settings.grammarMode {
        case .minimal:
            return "Makes minimal grammar corrections while preserving meaning and tone."
        case .friendly:
            return "Corrects grammar and adjusts tone to be friendly."
        case .work:
            return "Corrects grammar with a professional, business-appropriate tone."
        case .custom:
            return "Use your own custom prompts for grammar correction."
        }
    }
    
    private func testGrammar() {
        isTesting = true
        testOutput = ""
        
        Task {
            do {
                let maskedResult = MaskingService.shared.maskCustomWords(in: testInput)
                
                let result: (result: String, latencyMs: Int)
                if SettingsManager.shared.llmBackend == .openAI {
                    result = try await LLMClient.shared.correctGrammar(maskedResult.maskedText)
                } else {
                    result = try await LocalLLMRunner.shared.correctGrammar(maskedResult.maskedText)
                }
                
                let unmasked = MaskingService.shared.unmaskTokens(in: result.result, using: maskedResult.mapping, orderedFallback: maskedResult.orderedOriginals)
                
                await MainActor.run {
                    testOutput = unmasked
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testOutput = "Error: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}

#Preview {
    GrammarSettingsView()
        .frame(width: 500, height: 500)
}

