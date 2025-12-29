//
//  LocalLLMRunner.swift
//  GrammarPolice
//
//  Local LLM support via CLI or HTTP endpoint (e.g., Ollama)
//

import Foundation

enum LocalLLMError: Error, LocalizedError {
    case commandNotConfigured
    case endpointNotConfigured
    case executionFailed(String)
    case timeout
    case invalidResponse
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .commandNotConfigured:
            return "Local LLM command not configured"
        case .endpointNotConfigured:
            return "Local LLM endpoint not configured"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .timeout:
            return "Local LLM request timed out"
        case .invalidResponse:
            return "Invalid response from local LLM"
        case .connectionFailed:
            return "Could not connect to local LLM"
        }
    }
}

// MARK: - Ollama API Structures

struct OllamaRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: OllamaOptions?
}

struct OllamaOptions: Codable {
    let temperature: Double?
    let num_predict: Int?
}

struct OllamaResponse: Codable {
    let model: String
    let response: String
    let done: Bool
}

@MainActor
final class LocalLLMRunner {
    static let shared = LocalLLMRunner()
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = SettingsManager.shared.timeout
        session = URLSession(configuration: config)
    }
    
    // MARK: - Grammar Correction
    
    func correctGrammar(_ text: String) async throws -> (result: String, latencyMs: Int) {
        let prompts = SettingsManager.shared.getGrammarPrompt(for: text)
        let combinedPrompt = "\(prompts.system)\n\n\(prompts.user)"
        return try await sendRequest(prompt: combinedPrompt)
    }
    
    // MARK: - Translation
    
    func translate(_ text: String) async throws -> (result: String, latencyMs: Int) {
        let prompts = SettingsManager.shared.getTranslationPrompt(for: text)
        let combinedPrompt = "\(prompts.system)\n\n\(prompts.user)"
        return try await sendRequest(prompt: combinedPrompt)
    }
    
    // MARK: - Send Request
    
    private func sendRequest(prompt: String) async throws -> (result: String, latencyMs: Int) {
        switch SettingsManager.shared.localLLMMode {
        case .cli:
            return try await runCLICommand(prompt: prompt)
        case .http:
            return try await sendHTTPRequest(prompt: prompt)
        }
    }
    
    // MARK: - CLI Mode
    
    private func runCLICommand(prompt: String) async throws -> (result: String, latencyMs: Int) {
        let command = SettingsManager.shared.localLLMCommand
        guard !command.isEmpty else {
            throw LocalLLMError.commandNotConfigured
        }
        
        let startTime = Date()
        // Capture timeout value outside of the Sendable closure to avoid MainActor-isolated access
        let timeoutSeconds: TimeInterval = SettingsManager.shared.timeout
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                
                // Parse command
                let components = command.components(separatedBy: " ")
                guard let executable = components.first else {
                    continuation.resume(throwing: LocalLLMError.commandNotConfigured)
                    return
                }
                
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                var arguments = [executable]
                arguments.append(contentsOf: Array(components.dropFirst()))
                
                // Add prompt as input or argument
                process.arguments = arguments
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                // Create input pipe for prompt
                let inputPipe = Pipe()
                process.standardInput = inputPipe
                
                do {
                    try process.run()
                    
                    // Write prompt to stdin
                    let inputData = prompt.data(using: .utf8)!
                    inputPipe.fileHandleForWriting.write(inputData)
                    inputPipe.fileHandleForWriting.closeFile()

                    let deadline = DispatchTime.now() + timeoutSeconds

                    var timedOut = false
                    DispatchQueue.global().asyncAfter(deadline: deadline) { [process] in
                        if process.isRunning {
                            process.terminate()
                            timedOut = true
                        }
                    }
                    
                    process.waitUntilExit()
                    
                    if timedOut {
                        continuation.resume(throwing: LocalLLMError.timeout)
                        return
                    }
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    if process.terminationStatus != 0 {
                        let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: LocalLLMError.executionFailed(errorString))
                        return
                    }
                    
                    guard let output = String(data: outputData, encoding: .utf8) else {
                        continuation.resume(throwing: LocalLLMError.invalidResponse)
                        return
                    }
                    
                    let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
                    var result = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Strip surrounding quotes if present
                    if result.hasPrefix("\"") && result.hasSuffix("\"") && result.count >= 2 {
                        result = String(result.dropFirst().dropLast())
                    }
                    
                    LoggingService.shared.logLLMResponse(backend: "LocalCLI", latencyMs: latencyMs, success: true)
                    
                    continuation.resume(returning: (result, latencyMs))
                    
                } catch {
                    continuation.resume(throwing: LocalLLMError.executionFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - HTTP Mode (Ollama Compatible)
    
    private func sendHTTPRequest(prompt: String) async throws -> (result: String, latencyMs: Int) {
        let endpoint = SettingsManager.shared.localLLMEndpoint
        guard !endpoint.isEmpty else {
            throw LocalLLMError.endpointNotConfigured
        }
        
        // Assume Ollama-compatible API
        let urlString = endpoint.hasSuffix("/") ? "\(endpoint)api/generate" : "\(endpoint)/api/generate"
        guard let url = URL(string: urlString) else {
            throw LocalLLMError.endpointNotConfigured
        }
        
        let requestBody = OllamaRequest(
            model: "llama3",  // Could be configurable
            prompt: prompt,
            stream: false,
            options: OllamaOptions(
                temperature: SettingsManager.shared.temperature,
                num_predict: SettingsManager.shared.maxTokens
            )
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = SettingsManager.shared.timeout
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw LocalLLMError.invalidResponse
        }
        
        let startTime = Date()
        
        do {
            let (data, response) = try await session.data(for: request)
            
            let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw LocalLLMError.connectionFailed
            }
            
            let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
            var result = ollamaResponse.response.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Strip surrounding quotes if present
            if result.hasPrefix("\"") && result.hasSuffix("\"") && result.count >= 2 {
                result = String(result.dropFirst().dropLast())
            }
            
            LoggingService.shared.logLLMResponse(backend: "LocalHTTP", latencyMs: latencyMs, success: true)
            
            return (result, latencyMs)
            
        } catch let error as LocalLLMError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw LocalLLMError.timeout
        } catch {
            LoggingService.shared.log("Local LLM HTTP error: \(error)", level: .error)
            throw LocalLLMError.connectionFailed
        }
    }
    
    // MARK: - Test Connection
    
    func testConnection() async throws -> Bool {
        switch SettingsManager.shared.localLLMMode {
        case .cli:
            // Test if command exists
            let command = SettingsManager.shared.localLLMCommand.components(separatedBy: " ").first ?? ""
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = [command]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            try process.run()
            process.waitUntilExit()
            
            return process.terminationStatus == 0
            
        case .http:
            let endpoint = SettingsManager.shared.localLLMEndpoint
            guard !endpoint.isEmpty, let url = URL(string: endpoint) else {
                return false
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 5
            
            do {
                let (_, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    return false
                }
                return httpResponse.statusCode < 500
            } catch {
                return false
            }
        }
    }
}


