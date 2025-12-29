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
                Picker("Target Language:", selection: Binding(
                    get: { settings.targetLanguage },
                    set: { settings.targetLanguage = $0 }
                )) {
                    ForEach(suggestedLanguages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
                
                Text("Translation works with any source language and translates to the selected target language.")
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
                
                let unmasked = MaskingService.shared.unmaskTokens(in: result.result, using: maskedResult.mapping)
                
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

