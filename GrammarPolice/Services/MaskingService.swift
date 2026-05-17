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
    let orderedOriginals: [String]  // originals in text-position order (for fuzzy unmask fallback)
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
            return MaskingResult(maskedText: text, mapping: [:], tokensUsed: [], orderedOriginals: [])
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

        // Build text-position-ordered list of originals for fuzzy unmask fallback
        var orderedOriginals: [String] = []
        let scanPattern = "\(NSRegularExpression.escapedPattern(for: tokenPrefix))\\d+\(NSRegularExpression.escapedPattern(for: tokenSuffix))"
        if let scanRegex = try? NSRegularExpression(pattern: scanPattern) {
            let scanRange = NSRange(maskedText.startIndex..., in: maskedText)
            for match in scanRegex.matches(in: maskedText, options: [], range: scanRange) {
                guard let r = Range(match.range, in: maskedText) else { continue }
                let token = String(maskedText[r])
                if let original = mapping[token] {
                    orderedOriginals.append(original)
                }
            }
        }

        return MaskingResult(
            maskedText: maskedText,
            mapping: mapping,
            tokensUsed: tokensUsed,
            orderedOriginals: orderedOriginals
        )
    }
    
    // MARK: - Unmasking
    
    func unmaskTokens(in text: String, using mapping: [String: String], orderedFallback: [String] = []) -> String {
        var unmaskedText = text

        // Sort by token index to ensure correct order
        let sortedTokens = mapping.keys.sorted { token1, token2 in
            extractIndex(from: token1) < extractIndex(from: token2)
        }

        // First pass: exact replacement
        for token in sortedTokens {
            if let original = mapping[token] {
                unmaskedText = unmaskedText.replacingOccurrences(of: token, with: original)
            }
        }

        // Second pass: fuzzy repair of LLM-corrupted tokens (e.g. __CWORD_n__, _CWORD_, CWORD0).
        // Match in left-to-right text order, replace using orderedFallback by positional index.
        if !orderedFallback.isEmpty {
            let fuzzyPattern = #"_*CWORD[_\w]*_*"#
            if let regex = try? NSRegularExpression(pattern: fuzzyPattern, options: [.caseInsensitive]) {
                let nsRange = NSRange(unmaskedText.startIndex..., in: unmaskedText)
                let matches = regex.matches(in: unmaskedText, options: [], range: nsRange)

                if !matches.isEmpty {
                    // Iterate reversed to keep ranges valid; index by original (forward) position.
                    for (i, match) in matches.enumerated().reversed() {
                        guard let r = Range(match.range, in: unmaskedText) else { continue }
                        let replacement: String
                        if i < orderedFallback.count {
                            replacement = orderedFallback[i]
                        } else if let last = orderedFallback.last {
                            replacement = last
                        } else {
                            continue
                        }
                        unmaskedText.replaceSubrange(r, with: replacement)
                    }
                    LoggingService.shared.log("Fuzzy-repaired \(matches.count) corrupted tokens", level: .warning)
                }
            }
        }

        // Final cleanup: strip any orphan token shapes that still remain (no mapping info).
        unmaskedText = Self.scrubOrphanTokens(in: unmaskedText)

        if !mapping.isEmpty {
            LoggingService.shared.log("Unmasked \(mapping.count) tokens", level: .debug)
        }

        return unmaskedText
    }

    // MARK: - Orphan Token Scrubbing (display-side / corrupt-history salvage)

    /// Remove leftover masking-token shapes from text when no mapping is available.
    /// Used for displaying historical entries that were saved before fuzzy-repair was added.
    static func scrubOrphanTokens(in text: String) -> String {
        let pattern = #"_*CWORD[_\w]*_*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard regex.firstMatch(in: text, options: [], range: nsRange) != nil else {
            return text  // no token shapes present, leave text untouched
        }
        var result = regex.stringByReplacingMatches(in: text, options: [], range: nsRange, withTemplate: "")
        // Collapse runs of whitespace introduced by removal
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespaces)
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

