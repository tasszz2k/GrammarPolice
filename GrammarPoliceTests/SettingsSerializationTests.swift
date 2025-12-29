//
//  SettingsSerializationTests.swift
//  GrammarPoliceTests
//
//  Unit tests for settings serialization
//

import XCTest
@testable import GrammarPolice

final class SettingsSerializationTests: XCTestCase {
    
    // MARK: - AppSettings Codable Tests
    
    func testAppSettingsEncodeDecode() throws {
        // Given
        var settings = AppSettings()
        settings.launchAtLogin = true
        settings.grammarMode = .friendly
        settings.targetLanguage = "Spanish"
        settings.temperature = 0.5
        settings.maxTokens = 500
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSettings.self, from: data)
        
        // Then
        XCTAssertEqual(decoded.launchAtLogin, true)
        XCTAssertEqual(decoded.grammarMode, .friendly)
        XCTAssertEqual(decoded.targetLanguage, "Spanish")
        XCTAssertEqual(decoded.temperature, 0.5)
        XCTAssertEqual(decoded.maxTokens, 500)
    }
    
    func testAppSettingsDefaultValues() {
        // Given
        let settings = AppSettings()
        
        // Then
        XCTAssertEqual(settings.launchAtLogin, false)
        XCTAssertEqual(settings.grammarMode, .minimal)
        XCTAssertEqual(settings.targetLanguage, "Vietnamese")
        XCTAssertEqual(settings.llmBackend, .openAI)
        XCTAssertEqual(settings.temperature, 0.0)
        XCTAssertEqual(settings.maxTokens, 300)
        XCTAssertEqual(settings.maxCharacters, 2000)
    }
    
    // MARK: - HotkeyConfig Tests
    
    func testHotkeyConfigEncodeDecode() throws {
        // Given
        let hotkey = HotkeyConfig(keyCode: 5, modifiers: 768)
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(hotkey)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HotkeyConfig.self, from: data)
        
        // Then
        XCTAssertEqual(decoded.keyCode, 5)
        XCTAssertEqual(decoded.modifiers, 768)
    }
    
    func testHotkeyConfigDisplayString() {
        // Given
        let cmdShiftG = HotkeyConfig(keyCode: 5, modifiers: 768)  // Cmd+Shift+G
        let cmdShiftT = HotkeyConfig(keyCode: 17, modifiers: 768)  // Cmd+Shift+T
        
        // Then
        XCTAssertEqual(cmdShiftG.displayString, "Cmd+Shift+G")
        XCTAssertEqual(cmdShiftT.displayString, "Cmd+Shift+T")
    }
    
    func testHotkeyConfigEquality() {
        // Given
        let hotkey1 = HotkeyConfig(keyCode: 5, modifiers: 768)
        let hotkey2 = HotkeyConfig(keyCode: 5, modifiers: 768)
        let hotkey3 = HotkeyConfig(keyCode: 6, modifiers: 768)
        
        // Then
        XCTAssertEqual(hotkey1, hotkey2)
        XCTAssertNotEqual(hotkey1, hotkey3)
    }
    
    // MARK: - GrammarMode Tests
    
    func testGrammarModeEncodeDecode() throws {
        // Given
        let modes: [GrammarMode] = [.minimal, .friendly, .work, .custom]
        
        for mode in modes {
            // When
            let encoder = JSONEncoder()
            let data = try encoder.encode(mode)
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(GrammarMode.self, from: data)
            
            // Then
            XCTAssertEqual(decoded, mode)
        }
    }
    
    func testGrammarModePrompts() {
        // Given/Then
        XCTAssertFalse(GrammarMode.minimal.systemPrompt.isEmpty)
        XCTAssertFalse(GrammarMode.minimal.userPrompt.isEmpty)
        
        XCTAssertFalse(GrammarMode.friendly.systemPrompt.isEmpty)
        XCTAssertFalse(GrammarMode.friendly.userPrompt.isEmpty)
        
        XCTAssertFalse(GrammarMode.work.systemPrompt.isEmpty)
        XCTAssertFalse(GrammarMode.work.userPrompt.isEmpty)
        
        // Custom mode has empty prompts (user provides them)
        XCTAssertTrue(GrammarMode.custom.systemPrompt.isEmpty)
        XCTAssertTrue(GrammarMode.custom.userPrompt.isEmpty)
    }
    
    // MARK: - CustomWord Tests
    
    func testCustomWordEncodeDecode() throws {
        // Given
        let word = CustomWord(
            id: UUID(),
            word: "testword",
            caseSensitive: true,
            wholeWordMatch: false,
            createdAt: Date()
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(word)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CustomWord.self, from: data)
        
        // Then
        XCTAssertEqual(decoded.word, "testword")
        XCTAssertEqual(decoded.caseSensitive, true)
        XCTAssertEqual(decoded.wholeWordMatch, false)
    }
    
    func testCustomWordHashable() {
        // Given
        let word1 = CustomWord(word: "test")
        let word2 = CustomWord(word: "test")
        
        var set = Set<CustomWord>()
        
        // When
        set.insert(word1)
        set.insert(word2)
        
        // Then - Different UUIDs, so both should be in set
        XCTAssertEqual(set.count, 2)
    }
    
    // MARK: - LLMBackend Tests
    
    func testLLMBackendEncodeDecode() throws {
        // Given
        let backends: [LLMBackend] = [.openAI, .localLLM]
        
        for backend in backends {
            // When
            let encoder = JSONEncoder()
            let data = try encoder.encode(backend)
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(LLMBackend.self, from: data)
            
            // Then
            XCTAssertEqual(decoded, backend)
        }
    }
    
    // MARK: - OutputFormat Tests
    
    func testOutputFormatEncodeDecode() throws {
        // Given
        let formats: [OutputFormat] = [.original, .slack, .preserveRTF]
        
        for format in formats {
            // When
            let encoder = JSONEncoder()
            let data = try encoder.encode(format)
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(OutputFormat.self, from: data)
            
            // Then
            XCTAssertEqual(decoded, format)
        }
    }
    
    // MARK: - JSON Compatibility Tests
    
    func testSettingsJSONCompatibility() throws {
        // Given - JSON that might come from a previous version
        let json = """
        {
            "launchAtLogin": true,
            "grammarMode": "Friendly",
            "targetLanguage": "French",
            "llmBackend": "OpenAI",
            "temperature": 0.3,
            "maxTokens": 400,
            "restoreClipboard": true,
            "debugLoggingEnabled": true
        }
        """.data(using: .utf8)!
        
        // When
        let decoder = JSONDecoder()
        
        // Then - Should not throw even with missing fields (uses defaults)
        XCTAssertNoThrow(try decoder.decode(AppSettings.self, from: json))
    }
    
    // MARK: - Key Code Map Tests
    
    func testKeyCodeMapCommonKeys() {
        // Then
        XCTAssertEqual(KeyCodeMap.keyName(for: 5), "G")
        XCTAssertEqual(KeyCodeMap.keyName(for: 17), "T")
        XCTAssertEqual(KeyCodeMap.keyName(for: 0), "A")
        XCTAssertEqual(KeyCodeMap.keyName(for: 49), "Space")
        XCTAssertEqual(KeyCodeMap.keyName(for: 36), "Return")
    }
    
    func testKeyCodeMapUnknownKey() {
        // Then
        XCTAssertEqual(KeyCodeMap.keyName(for: 999), "Key999")
    }
}

