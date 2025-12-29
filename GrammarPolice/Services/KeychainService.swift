//
//  KeychainService.swift
//  GrammarPolice
//
//  Secure storage for API keys using macOS Keychain
//

import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unexpectedStatus(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Keychain item not found"
        case .duplicateItem:
            return "Keychain item already exists"
        case .invalidData:
            return "Invalid keychain data"
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        }
    }
}

final class KeychainService {
    static let shared = KeychainService()
    
    private let service = "com.tasszz2k.GrammarPolice"
    private let openAIKeyAccount = "openai_api_key"
    
    private init() {}
    
    // MARK: - OpenAI API Key
    
    var openAIAPIKey: String? {
        get {
            try? retrieveKey(account: openAIKeyAccount)
        }
        set {
            if let key = newValue {
                do {
                    try saveKey(key, account: openAIKeyAccount)
                } catch {
                    LoggingService.shared.log("Failed to save OpenAI API key: \(error)", level: .error)
                }
            } else {
                try? deleteKey(account: openAIKeyAccount)
            }
        }
    }
    
    var hasOpenAIAPIKey: Bool {
        return openAIAPIKey != nil && !openAIAPIKey!.isEmpty
    }
    
    // MARK: - Generic Key Operations
    
    func saveKey(_ key: String, account: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        // First try to delete any existing item
        try? deleteKey(account: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            throw KeychainError.unexpectedStatus(status)
        }
        
        LoggingService.shared.log("Saved key to keychain for account: \(account)", level: .debug)
    }
    
    func retrieveKey(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return key
    }
    
    func deleteKey(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
        
        LoggingService.shared.log("Deleted key from keychain for account: \(account)", level: .debug)
    }
    
    func updateKey(_ key: String, account: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                // Item doesn't exist, create it
                try saveKey(key, account: account)
                return
            }
            throw KeychainError.unexpectedStatus(status)
        }
        
        LoggingService.shared.log("Updated key in keychain for account: \(account)", level: .debug)
    }
    
    // MARK: - Test Connection
    
    func testOpenAIConnection() async throws -> Bool {
        guard let apiKey = openAIAPIKey, !apiKey.isEmpty else {
            throw KeychainError.itemNotFound
        }
        
        // Make a simple API call to verify the key
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        let success = httpResponse.statusCode == 200
        LoggingService.shared.log("OpenAI API key test: \(success ? "success" : "failed")", level: .info)
        
        return success
    }
}

