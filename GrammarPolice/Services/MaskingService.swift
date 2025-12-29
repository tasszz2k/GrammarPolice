//
//  MaskingService.swift
//  GrammarPolice
//
//  Custom word masking/unmasking service
//

import Foundation

struct MaskingResult {
    let maskedText: String
    let mapping: [String: String]  // token -> original word
    let tokensUsed: [String]
}

final class MaskingService {
    static let shared = MaskingService()
    
    private let tokenPrefix = "__CWORD_"
    private let tokenSuffix = "__"
    
    private init() {}
    
    // MARK: - Masking
    
    func maskCustomWords(in text: String) -> MaskingResult {
        let customWords = CustomWordsManager.shared.allWords
        
        guard !customWords.isEmpty else {
            return MaskingResult(maskedText: text, mapping: [:], tokensUsed: [])
        }
        
        var maskedText = text
        var mapping: [String: String] = [:]
        var tokensUsed: [String] = []
        var tokenIndex = 0
        
        // Sort words by length (longest first) to avoid partial replacements
        let sortedWords = customWords.sorted { $0.word.count > $1.word.count }
        
        for customWord in sortedWords {
            let word = customWord.word
            let caseSensitive = customWord.caseSensitive
            let wholeWord = customWord.wholeWordMatch
            
            // Build regex pattern
            let escapedWord = NSRegularExpression.escapedPattern(for: word)
            let pattern: String
            
            if wholeWord {
                pattern = "\\b\(escapedWord)\\b"
            } else {
                pattern = escapedWord
            }
            
            // Create regex options
            var options: NSRegularExpression.Options = []
            if !caseSensitive {
                options.insert(.caseInsensitive)
            }
            
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
                continue
            }
            
            // Find all matches (need to iterate because we're replacing and the string changes)
            let searchRange = NSRange(maskedText.startIndex..., in: maskedText)
            
            let matches = regex.matches(in: maskedText, options: [], range: searchRange)
            
            for match in matches.reversed() {  // Reverse to maintain valid ranges
                let matchRange = match.range
                guard let range = Range(matchRange, in: maskedText) else { continue }
                
                let originalWord = String(maskedText[range])
                let token = "\(tokenPrefix)\(tokenIndex)\(tokenSuffix)"
                
                // Store mapping
                mapping[token] = originalWord
                tokensUsed.append(originalWord)
                
                // Replace with token
                maskedText.replaceSubrange(range, with: token)
                
                tokenIndex += 1
            }
        }
        
        if !mapping.isEmpty {
            LoggingService.shared.log("Masked \(mapping.count) custom words", level: .debug)
        }
        
        return MaskingResult(
            maskedText: maskedText,
            mapping: mapping,
            tokensUsed: tokensUsed
        )
    }
    
    // MARK: - Unmasking
    
    func unmaskTokens(in text: String, using mapping: [String: String]) -> String {
        var unmaskedText = text
        
        // Sort by token index to ensure correct order
        let sortedTokens = mapping.keys.sorted { token1, token2 in
            extractIndex(from: token1) < extractIndex(from: token2)
        }
        
        // Replace tokens with original words
        for token in sortedTokens {
            if let original = mapping[token] {
                unmaskedText = unmaskedText.replacingOccurrences(of: token, with: original)
            }
        }
        
        if !mapping.isEmpty {
            LoggingService.shared.log("Unmasked \(mapping.count) tokens", level: .debug)
        }
        
        return unmaskedText
    }
    
    // MARK: - Helpers
    
    private func extractIndex(from token: String) -> Int {
        let stripped = token
            .replacingOccurrences(of: tokenPrefix, with: "")
            .replacingOccurrences(of: tokenSuffix, with: "")
        return Int(stripped) ?? 0
    }
    
    // MARK: - Validation
    
    func validateNoCollisions(in text: String) -> Bool {
        // Check if the text already contains tokens that look like our tokens
        let pattern = "\(NSRegularExpression.escapedPattern(for: tokenPrefix))\\d+\(NSRegularExpression.escapedPattern(for: tokenSuffix))"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return true
        }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) == nil
    }
    
    // MARK: - Token Detection
    
    func detectTokensInText(_ text: String) -> [String] {
        let pattern = "\(NSRegularExpression.escapedPattern(for: tokenPrefix))\\d+\(NSRegularExpression.escapedPattern(for: tokenSuffix))"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        
        return matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }
}

// MARK: - Testing Helpers

extension MaskingService {
    /// Test function to verify masking/unmasking works correctly
    func testMaskUnmask(text: String, expectedMaskedCount: Int) -> Bool {
        let maskResult = maskCustomWords(in: text)
        
        guard maskResult.mapping.count == expectedMaskedCount else {
            return false
        }
        
        let unmasked = unmaskTokens(in: maskResult.maskedText, using: maskResult.mapping)
        
        return unmasked == text
    }
}

