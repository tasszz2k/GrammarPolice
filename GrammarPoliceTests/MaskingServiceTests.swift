//
//  MaskingServiceTests.swift
//  GrammarPoliceTests
//
//  Unit tests for MaskingService
//

import XCTest
@testable import GrammarPolice

final class MaskingServiceTests: XCTestCase {
    
    var maskingService: MaskingService!
    
    override func setUpWithError() throws {
        maskingService = MaskingService.shared
        
        // Clear any existing custom words
        for word in CustomWordsManager.shared.allWords {
            CustomWordsManager.shared.deleteWord(word)
        }
    }
    
    override func tearDownWithError() throws {
        // Clean up custom words after tests
        for word in CustomWordsManager.shared.allWords {
            CustomWordsManager.shared.deleteWord(word)
        }
    }
    
    // MARK: - Basic Masking Tests
    
    func testMaskingSingleWord() {
        // Given
        CustomWordsManager.shared.addWord(CustomWord(word: "ais", caseSensitive: false, wholeWordMatch: true))
        let text = "The ais system is working."
        
        // When
        let result = maskingService.maskCustomWords(in: text)
        
        // Then
        XCTAssertTrue(result.maskedText.contains("__CWORD_"))
        XCTAssertFalse(result.maskedText.contains("ais"))
        XCTAssertEqual(result.mapping.count, 1)
    }
    
    func testMaskingMultipleOccurrences() {
        // Given
        CustomWordsManager.shared.addWord(CustomWord(word: "test", caseSensitive: false, wholeWordMatch: true))
        let text = "This test is a test of the test system."
        
        // When
        let result = maskingService.maskCustomWords(in: text)
        
        // Then
        XCTAssertEqual(result.mapping.count, 3)
        XCTAssertFalse(result.maskedText.lowercased().contains("test"))
    }
    
    func testMaskingWithPunctuation() {
        // Given
        CustomWordsManager.shared.addWord(CustomWord(word: "word", caseSensitive: false, wholeWordMatch: true))
        let text = "This word, that word! Another word?"
        
        // When
        let result = maskingService.maskCustomWords(in: text)
        
        // Then
        XCTAssertEqual(result.mapping.count, 3)
        XCTAssertTrue(result.maskedText.contains(","))
        XCTAssertTrue(result.maskedText.contains("!"))
        XCTAssertTrue(result.maskedText.contains("?"))
    }
    
    // MARK: - Case Sensitivity Tests
    
    func testCaseInsensitiveMatching() {
        // Given
        CustomWordsManager.shared.addWord(CustomWord(word: "Test", caseSensitive: false, wholeWordMatch: true))
        let text = "test TEST Test tEsT"
        
        // When
        let result = maskingService.maskCustomWords(in: text)
        
        // Then
        XCTAssertEqual(result.mapping.count, 4)
    }
    
    func testCaseSensitiveMatching() {
        // Given
        CustomWordsManager.shared.addWord(CustomWord(word: "Test", caseSensitive: true, wholeWordMatch: true))
        let text = "test TEST Test tEsT"
        
        // When
        let result = maskingService.maskCustomWords(in: text)
        
        // Then
        XCTAssertEqual(result.mapping.count, 1)
        XCTAssertTrue(result.mapping.values.contains("Test"))
    }
    
    // MARK: - Whole Word Match Tests
    
    func testWholeWordMatch() {
        // Given
        CustomWordsManager.shared.addWord(CustomWord(word: "test", caseSensitive: false, wholeWordMatch: true))
        let text = "test testing tested contest"
        
        // When
        let result = maskingService.maskCustomWords(in: text)
        
        // Then
        XCTAssertEqual(result.mapping.count, 1)
        XCTAssertTrue(result.maskedText.contains("testing"))
        XCTAssertTrue(result.maskedText.contains("tested"))
        XCTAssertTrue(result.maskedText.contains("contest"))
    }
    
    func testPartialMatch() {
        // Given
        CustomWordsManager.shared.addWord(CustomWord(word: "test", caseSensitive: false, wholeWordMatch: false))
        let text = "test testing tested contest"
        
        // When
        let result = maskingService.maskCustomWords(in: text)
        
        // Then
        XCTAssertEqual(result.mapping.count, 4)
    }
    
    // MARK: - Unmasking Tests
    
    func testUnmaskingRestoresOriginal() {
        // Given
        CustomWordsManager.shared.addWord(CustomWord(word: "special", caseSensitive: false, wholeWordMatch: true))
        let originalText = "This is a special word."
        
        // When
        let maskResult = maskingService.maskCustomWords(in: originalText)
        let unmaskedText = maskingService.unmaskTokens(in: maskResult.maskedText, using: maskResult.mapping)
        
        // Then
        XCTAssertEqual(unmaskedText, originalText)
    }
    
    func testUnmaskingPreservesCase() {
        // Given
        CustomWordsManager.shared.addWord(CustomWord(word: "word", caseSensitive: false, wholeWordMatch: true))
        let originalText = "WORD Word word"
        
        // When
        let maskResult = maskingService.maskCustomWords(in: originalText)
        let unmaskedText = maskingService.unmaskTokens(in: maskResult.maskedText, using: maskResult.mapping)
        
        // Then
        XCTAssertEqual(unmaskedText, originalText)
    }
    
    func testUnmaskingAfterLLMModification() {
        // Given
        CustomWordsManager.shared.addWord(CustomWord(word: "ais", caseSensitive: false, wholeWordMatch: true))
        let originalText = "The ais system work good."
        
        // When
        let maskResult = maskingService.maskCustomWords(in: originalText)
        
        // Simulate LLM correcting grammar but preserving tokens
        let llmOutput = maskResult.maskedText.replacingOccurrences(of: "work good", with: "works well")
        
        let unmaskedText = maskingService.unmaskTokens(in: llmOutput, using: maskResult.mapping)
        
        // Then
        XCTAssertTrue(unmaskedText.contains("ais"))
        XCTAssertTrue(unmaskedText.contains("works well"))
    }
    
    // MARK: - Edge Cases
    
    func testEmptyText() {
        // Given
        CustomWordsManager.shared.addWord(CustomWord(word: "test", caseSensitive: false, wholeWordMatch: true))
        let text = ""
        
        // When
        let result = maskingService.maskCustomWords(in: text)
        
        // Then
        XCTAssertEqual(result.maskedText, "")
        XCTAssertTrue(result.mapping.isEmpty)
    }
    
    func testNoCustomWords() {
        // Given
        let text = "This is some text without custom words."
        
        // When
        let result = maskingService.maskCustomWords(in: text)
        
        // Then
        XCTAssertEqual(result.maskedText, text)
        XCTAssertTrue(result.mapping.isEmpty)
    }
    
    func testSpecialCharactersInWord() {
        // Given
        CustomWordsManager.shared.addWord(CustomWord(word: "C++", caseSensitive: false, wholeWordMatch: false))
        let text = "I love C++ programming."
        
        // When
        let result = maskingService.maskCustomWords(in: text)
        
        // Then
        XCTAssertEqual(result.mapping.count, 1)
        XCTAssertFalse(result.maskedText.contains("C++"))
    }
    
    func testCollisionDetection() {
        // Given
        let textWithToken = "This text contains __CWORD_0__ already."
        
        // When
        let hasCollision = !maskingService.validateNoCollisions(in: textWithToken)
        
        // Then
        XCTAssertTrue(hasCollision)
    }
    
    func testNoCollision() {
        // Given
        let normalText = "This is normal text without tokens."
        
        // When
        let hasCollision = !maskingService.validateNoCollisions(in: normalText)
        
        // Then
        XCTAssertFalse(hasCollision)
    }
    
    // MARK: - Round-Trip Tests
    
    func testRoundTripWithMultipleWords() {
        // Given
        CustomWordsManager.shared.addWord(CustomWord(word: "alpha", caseSensitive: false, wholeWordMatch: true))
        CustomWordsManager.shared.addWord(CustomWord(word: "beta", caseSensitive: false, wholeWordMatch: true))
        CustomWordsManager.shared.addWord(CustomWord(word: "gamma", caseSensitive: false, wholeWordMatch: true))
        
        let originalText = "Testing alpha and beta with gamma values."
        
        // When
        let maskResult = maskingService.maskCustomWords(in: originalText)
        let unmaskedText = maskingService.unmaskTokens(in: maskResult.maskedText, using: maskResult.mapping)
        
        // Then
        XCTAssertEqual(unmaskedText, originalText)
    }
}

