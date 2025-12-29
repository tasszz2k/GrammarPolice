//
//  LLMSettingsView.swift
//  GrammarPolice
//
//  LLM backend selection and configuration
//

import SwiftUI

struct LLMSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    
    @State private var apiKey = ""
    @State private var hasAPIKey = false
    @State private var isLoadingKeyStatus = true
    @State private var isTestingConnection = false
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var showingAPIKeyField = false
    
    enum ConnectionTestResult {
        case success
        case failure(String)
    }
    
    var body: some View {
        Form {
            Section {
                Picker("Backend:", selection: Binding(
                    get: { settings.llmBackend },
                    set: { settings.llmBackend = $0 }
                )) {
                    ForEach(LLMBackend.allCases, id: \.self) { backend in
                        Text(backend.rawValue).tag(backend)
                    }
                }
                .pickerStyle(.segmented)
                
                Toggle("Privacy Consent Granted", isOn: Binding(
                    get: { settings.privacyConsentGranted },
                    set: { settings.privacyConsentGranted = $0 }
                ))
                .help("Required for sending text to remote LLM services")
            } header: {
                Text("Backend Selection")
            }
            
            if settings.llmBackend == .openAI {
                Section {
                    HStack {
                        if showingAPIKeyField {
                            SecureField("API Key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Save") {
                                saveAPIKey()
                            }
                            
                            Button("Cancel") {
                                showingAPIKeyField = false
                                apiKey = ""
                            }
                        } else {
                            if isLoadingKeyStatus {
                                Text("API Key: Loading...")
                                    .foregroundColor(.secondary)
                            } else {
                                Text(hasAPIKey ? "API Key: ********" : "API Key: Not Set")
                            }
                            
                            Spacer()
                            
                            Button(hasAPIKey ? "Change" : "Set") {
                                showingAPIKeyField = true
                                apiKey = ""
                            }
                            .disabled(isLoadingKeyStatus)
                        }
                    }
                    
                    Picker("Model:", selection: Binding(
                        get: { settings.openAIModel },
                        set: { settings.openAIModel = $0 }
                    )) {
                        Text("gpt-4.1-mini").tag("gpt-4.1-mini")
                        Text("gpt-4o-mini").tag("gpt-4o-mini")
                        Text("gpt-4o").tag("gpt-4o")
                        Text("gpt-4-turbo").tag("gpt-4-turbo")
                        Text("gpt-3.5-turbo").tag("gpt-3.5-turbo")
                    }
                    
                    HStack {
                        Text("Temperature:")
                        Slider(value: Binding(
                            get: { settings.temperature },
                            set: { settings.temperature = $0 }
                        ), in: 0...2, step: 0.1)
                        Text(String(format: "%.1f", settings.temperature))
                            .frame(width: 30)
                    }
                    
                    Stepper("Max Tokens: \(settings.maxTokens)", value: Binding(
                        get: { settings.maxTokens },
                        set: { settings.maxTokens = $0 }
                    ), in: 50...4000, step: 50)
                    
                    Stepper("Timeout: \(Int(settings.timeout))s", value: Binding(
                        get: { settings.timeout },
                        set: { settings.timeout = $0 }
                    ), in: 5...120, step: 5)
                    
                    HStack {
                        Button("Test Connection") {
                            testOpenAIConnection()
                        }
                        .disabled(isTestingConnection || !hasAPIKey || isLoadingKeyStatus)
                        
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        
                        if let result = connectionTestResult {
                            switch result {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Connected")
                                    .foregroundColor(.green)
                            case .failure(let message):
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(message)
                                    .foregroundColor(.red)
                                    .lineLimit(1)
                            }
                        }
                    }
                } header: {
                    Text("OpenAI Configuration")
                }
            }
            
            if settings.llmBackend == .localLLM {
                Section {
                    Picker("Mode:", selection: Binding(
                        get: { settings.localLLMMode },
                        set: { settings.localLLMMode = $0 }
                    )) {
                        ForEach(LocalLLMMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    
                    if settings.localLLMMode == .cli {
                        TextField("Command:", text: Binding(
                            get: { settings.localLLMCommand },
                            set: { settings.localLLMCommand = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        Text("Example: ollama run llama3")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if settings.localLLMMode == .http {
                        TextField("Endpoint:", text: Binding(
                            get: { settings.localLLMEndpoint },
                            set: { settings.localLLMEndpoint = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        Text("Example: http://localhost:11434")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Button("Test Connection") {
                            testLocalLLMConnection()
                        }
                        .disabled(isTestingConnection)
                        
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        
                        if let result = connectionTestResult {
                            switch result {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Connected")
                                    .foregroundColor(.green)
                            case .failure(let message):
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(message)
                                    .foregroundColor(.red)
                                    .lineLimit(1)
                            }
                        }
                    }
                } header: {
                    Text("Local LLM Configuration")
                }
            }
            
            Section {
                Stepper("Max Characters: \(settings.maxCharacters)", value: Binding(
                    get: { settings.maxCharacters },
                    set: { settings.maxCharacters = $0 }
                ), in: 500...10000, step: 500)
                
                Text("Maximum characters that can be sent to the LLM")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Safety")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadAPIKeyStatus()
        }
    }
    
    private func loadAPIKeyStatus() {
        isLoadingKeyStatus = true

        Task {
            // Perform background work to fetch key existence
            let keyExists = KeychainService.shared.hasOpenAIAPIKey

            // Update UI on the main actor
            await MainActor.run {
                hasAPIKey = keyExists
                isLoadingKeyStatus = false
            }
        }
    }
    
    private func saveAPIKey() {
        // Snapshot the key on the main actor
        let keyToSave = apiKey

        Task {
            // Perform the keychain write on the main actor
            await MainActor.run {
                KeychainService.shared.openAIAPIKey = keyToSave
            }

            // Update UI-related state on the main actor
            hasAPIKey = !keyToSave.isEmpty
            showingAPIKeyField = false
            apiKey = ""
        }
    }
    
    private func testOpenAIConnection() {
        isTestingConnection = true
        connectionTestResult = nil
        
        Task {
            do {
                let success = try await LLMClient.shared.testConnection()
                await MainActor.run {
                    connectionTestResult = success ? .success : .failure("Connection failed")
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = .failure(error.localizedDescription)
                    isTestingConnection = false
                }
            }
        }
    }
    
    private func testLocalLLMConnection() {
        isTestingConnection = true
        connectionTestResult = nil
        
        Task {
            do {
                let success = try await LocalLLMRunner.shared.testConnection()
                await MainActor.run {
                    connectionTestResult = success ? .success : .failure("Connection failed")
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = .failure(error.localizedDescription)
                    isTestingConnection = false
                }
            }
        }
    }
}

#Preview {
    LLMSettingsView()
        .frame(width: 500, height: 500)
}
