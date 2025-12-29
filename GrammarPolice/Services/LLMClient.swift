//
//  LLMClient.swift
//  GrammarPolice
//
//  OpenAI Chat Completions API client
//

import Foundation

@MainActor
enum LLMError: Error, LocalizedError {
    case noAPIKey
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case rateLimited
    case timeout
    case textTooLong(Int, Int)
    case privacyConsentRequired
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let message):
            return "API error: \(message)"
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .timeout:
            return "Request timed out"
        case .textTooLong(let current, let max):
            return "Text too long (\(current) chars). Maximum is \(max) chars."
        case .privacyConsentRequired:
            return "Privacy consent required for remote LLM"
        }
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let max_tokens: Int
}

struct ChatCompletionResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let message: Message
        let finish_reason: String?
    }
    
    struct Usage: Codable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }
    
    let id: String
    let choices: [Choice]
    let usage: Usage?
}

struct APIErrorResponse: Codable {
    struct ErrorDetail: Codable {
        let message: String
        let type: String?
        let code: String?
    }
    let error: ErrorDetail
}

@MainActor
final class LLMClient {
    static let shared = LLMClient()
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = SettingsManager.shared.timeout
        config.timeoutIntervalForResource = SettingsManager.shared.timeout * 2
        session = URLSession(configuration: config)
    }
    
    // MARK: - Grammar Correction
    
    func correctGrammar(_ text: String) async throws -> (result: String, latencyMs: Int) {
        try checkPrerequisites(textLength: text.count)
        
        let prompts = SettingsManager.shared.getGrammarPrompt(for: text)
        return try await sendRequest(systemPrompt: prompts.system, userPrompt: prompts.user)
    }
    
    // MARK: - Translation
    
    func translate(_ text: String) async throws -> (result: String, latencyMs: Int) {
        try checkPrerequisites(textLength: text.count)
        
        let prompts = SettingsManager.shared.getTranslationPrompt(for: text)
        return try await sendRequest(systemPrompt: prompts.system, userPrompt: prompts.user)
    }
    
    // MARK: - Generic Request
    
    private func sendRequest(systemPrompt: String, userPrompt: String) async throws -> (result: String, latencyMs: Int) {
        guard let apiKey = KeychainService.shared.openAIAPIKey, !apiKey.isEmpty else {
            throw LLMError.noAPIKey
        }
        
        guard let url = URL(string: baseURL) else {
            throw LLMError.invalidURL
        }
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: userPrompt)
        ]
        
        let requestBody = ChatCompletionRequest(
            model: SettingsManager.shared.openAIModel,
            messages: messages,
            temperature: SettingsManager.shared.temperature,
            max_tokens: SettingsManager.shared.maxTokens
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = SettingsManager.shared.timeout
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw LLMError.networkError(error)
        }
        
        let startTime = Date()
        
        LoggingService.shared.log("Sending request to OpenAI API", level: .debug)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200:
                break
            case 401:
                throw LLMError.apiError("Invalid API key")
            case 429:
                throw LLMError.rateLimited
            case 500...599:
                throw LLMError.apiError("Server error")
            default:
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw LLMError.apiError(errorResponse.error.message)
                }
                throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let completionResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            
            guard let firstChoice = completionResponse.choices.first else {
                throw LLMError.invalidResponse
            }
            
            var result = firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Strip surrounding quotes if present (LLM sometimes adds them)
            if result.hasPrefix("\"") && result.hasSuffix("\"") && result.count >= 2 {
                result = String(result.dropFirst().dropLast())
            }
            
            LoggingService.shared.logLLMResponse(backend: "OpenAI", latencyMs: latencyMs, success: true)
            
            return (result, latencyMs)
            
        } catch let error as LLMError {
            LoggingService.shared.log("LLM error: \(error.localizedDescription)", level: .error)
            throw error
        } catch let error as URLError where error.code == .timedOut {
            LoggingService.shared.log("LLM request timed out", level: .error)
            throw LLMError.timeout
        } catch {
            LoggingService.shared.log("Network error: \(error.localizedDescription)", level: .error)
            throw LLMError.networkError(error)
        }
    }
    
    // MARK: - Validation
    
    private func checkPrerequisites(textLength: Int) throws {
        // Check privacy consent
        if !SettingsManager.shared.privacyConsentGranted && SettingsManager.shared.llmBackend == .openAI {
            throw LLMError.privacyConsentRequired
        }
        
        // Check text length
        let maxChars = SettingsManager.shared.maxCharacters
        if textLength > maxChars {
            throw LLMError.textTooLong(textLength, maxChars)
        }
    }
    
    // MARK: - Test Connection
    
    func testConnection() async throws -> Bool {
        guard let apiKey = KeychainService.shared.openAIAPIKey, !apiKey.isEmpty else {
            throw LLMError.noAPIKey
        }
        
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        return httpResponse.statusCode == 200
    }
}

