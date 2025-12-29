//
//  CSVExportTests.swift
//  GrammarPoliceTests
//
//  Unit tests for CSV export functionality
//

import XCTest
@testable import GrammarPolice

final class CSVExportTests: XCTestCase {
    
    // MARK: - Custom Word CSV Tests
    
    func testCustomWordCSVExport() {
        // Given
        let word = CustomWord(
            id: UUID(),
            word: "testword",
            caseSensitive: true,
            wholeWordMatch: false,
            createdAt: Date()
        )
        
        // When
        let csv = word.csvRow
        
        // Then
        XCTAssertTrue(csv.contains("testword"))
        XCTAssertTrue(csv.contains("true"))
        XCTAssertTrue(csv.contains("false"))
    }
    
    func testCustomWordCSVEscapesQuotes() {
        // Given
        let word = CustomWord(
            id: UUID(),
            word: "word with \"quotes\"",
            caseSensitive: false,
            wholeWordMatch: true,
            createdAt: Date()
        )
        
        // When
        let csv = word.csvRow
        
        // Then
        // Quotes should be escaped as double quotes
        XCTAssertTrue(csv.contains("\"\""))
    }
    
    func testCustomWordCSVRoundTrip() {
        // Given
        let originalWord = CustomWord(
            id: UUID(),
            word: "roundtrip",
            caseSensitive: true,
            wholeWordMatch: true,
            createdAt: Date()
        )
        
        // When
        let csv = originalWord.csvRow
        let parsedWord = CustomWord.fromCSVRow(csv)
        
        // Then
        XCTAssertNotNil(parsedWord)
        XCTAssertEqual(parsedWord?.word, originalWord.word)
        XCTAssertEqual(parsedWord?.caseSensitive, originalWord.caseSensitive)
        XCTAssertEqual(parsedWord?.wholeWordMatch, originalWord.wholeWordMatch)
    }
    
    // MARK: - History Entry CSV Tests
    
    func testHistoryEntryCSVExport() {
        // Given
        let entry = HistoryEntry(
            input: "test input",
            output: "test output",
            mode: .grammar,
            appBundleIdentifier: "com.test.app",
            appName: "TestApp",
            success: true,
            replacementDone: true,
            customWordsUsed: ["word1", "word2"],
            sourceLanguage: "en",
            targetLanguage: "",
            llmBackend: "OpenAI",
            llmLatencyMs: 500
        )
        
        // When
        let csv = entry.csvRow
        
        // Then
        XCTAssertTrue(csv.contains("test input"))
        XCTAssertTrue(csv.contains("test output"))
        XCTAssertTrue(csv.contains("TestApp"))
        XCTAssertTrue(csv.contains("grammar"))
    }
    
    func testHistoryEntryCSVEscapesCommas() {
        // Given
        let entry = HistoryEntry(
            input: "text, with, commas",
            output: "output",
            mode: .grammar
        )
        
        // When
        let csv = entry.csvRow
        
        // Then
        // Text with commas should be quoted
        XCTAssertTrue(csv.contains("\"text, with, commas\""))
    }
    
    func testHistoryEntryCSVEscapesNewlines() {
        // Given
        let entry = HistoryEntry(
            input: "line1\nline2",
            output: "output",
            mode: .grammar
        )
        
        // When
        let csv = entry.csvRow
        
        // Then
        // Text with newlines should be quoted
        XCTAssertTrue(csv.contains("\"line1\nline2\""))
    }
    
    func testHistoryEntryCSVEscapesQuotes() {
        // Given
        let entry = HistoryEntry(
            input: "text with \"quotes\"",
            output: "output",
            mode: .grammar
        )
        
        // When
        let csv = entry.csvRow
        
        // Then
        // Quotes should be doubled
        XCTAssertTrue(csv.contains("\"\""))
    }
    
    func testHistoryEntryCSVHeader() {
        // Given
        let header = HistoryEntry.csvHeader
        
        // Then
        XCTAssertTrue(header.contains("timestamp"))
        XCTAssertTrue(header.contains("app"))
        XCTAssertTrue(header.contains("input"))
        XCTAssertTrue(header.contains("output"))
        XCTAssertTrue(header.contains("mode"))
        XCTAssertTrue(header.contains("language_from"))
        XCTAssertTrue(header.contains("language_to"))
        XCTAssertTrue(header.contains("custom_words_ignored"))
        XCTAssertTrue(header.contains("replacement_done"))
    }
    
    // MARK: - JSON Export Tests
    
    func testHistoryEntryJSONExport() {
        // Given
        let entry = HistoryEntry(
            input: "test input",
            output: "test output",
            mode: .translate,
            appName: "TestApp",
            success: true,
            sourceLanguage: "en",
            targetLanguage: "vi"
        )
        
        // When
        let json = entry.jsonDictionary
        
        // Then
        XCTAssertEqual(json["input"] as? String, "test input")
        XCTAssertEqual(json["output"] as? String, "test output")
        XCTAssertEqual(json["mode"] as? String, "translate")
        XCTAssertEqual(json["source_language"] as? String, "en")
        XCTAssertEqual(json["target_language"] as? String, "vi")
    }
    
    func testLearningExportFormat() {
        // Given
        let entry = HistoryEntry(
            input: "test input",
            output: "corrected output",
            mode: .grammar
        )
        
        // When
        let learning = entry.learningExportDictionary
        
        // Then
        XCTAssertEqual(learning["input"], "test input")
        XCTAssertEqual(learning["correction"], "corrected output")
        XCTAssertTrue(learning["explanation"]?.contains("grammar") ?? false)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyStringsInCSV() {
        // Given
        let entry = HistoryEntry(
            input: "",
            output: "",
            mode: .grammar
        )
        
        // When
        let csv = entry.csvRow
        
        // Then
        // Should not crash and should produce valid CSV
        XCTAssertFalse(csv.isEmpty)
    }
    
    func testUnicodeInCSV() {
        // Given
        let entry = HistoryEntry(
            input: "Hello, World!",
            output: "Xin chao!",
            mode: .translate,
            targetLanguage: "Vietnamese"
        )
        
        // When
        let csv = entry.csvRow
        
        // Then
        XCTAssertTrue(csv.contains("Xin chao!"))
    }
    
    func testCustomWordsListInCSV() {
        // Given
        let entry = HistoryEntry(
            input: "test",
            output: "test",
            mode: .grammar,
            customWordsUsed: ["word1", "word2", "word3"]
        )
        
        // When
        let csv = entry.csvRow
        
        // Then
        XCTAssertTrue(csv.contains("word1;word2;word3"))
    }
}

