//
//  CustomWord.swift
//  GrammarPolice
//
//  Model for custom words that should be preserved during grammar correction
//

import Foundation
import SwiftUI

struct CustomWord: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var word: String
    var caseSensitive: Bool
    var wholeWordMatch: Bool
    var createdAt: Date
    
    init(id: UUID = UUID(), word: String, caseSensitive: Bool = false, wholeWordMatch: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.word = word
        self.caseSensitive = caseSensitive
        self.wholeWordMatch = wholeWordMatch
        self.createdAt = createdAt
    }
    
    // MARK: - CSV Export/Import
    
    static let csvHeader = "id,word,case_sensitive,whole_word_match,created_at"
    
    var csvRow: String {
        let dateFormatter = ISO8601DateFormatter()
        let escapedWord = word.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(id.uuidString)\",\"\(escapedWord)\",\(caseSensitive),\(wholeWordMatch),\"\(dateFormatter.string(from: createdAt))\""
    }
    
    static func fromCSVRow(_ row: String) -> CustomWord? {
        let components = parseCSVRow(row)
        guard components.count >= 5 else { return nil }
        
        let dateFormatter = ISO8601DateFormatter()
        
        guard let id = UUID(uuidString: components[0]),
              let caseSensitive = Bool(components[2].lowercased()),
              let wholeWordMatch = Bool(components[3].lowercased()),
              let createdAt = dateFormatter.date(from: components[4]) else {
            return nil
        }
        
        return CustomWord(
            id: id,
            word: components[1],
            caseSensitive: caseSensitive,
            wholeWordMatch: wholeWordMatch,
            createdAt: createdAt
        )
    }
    
    private static func parseCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var i = row.startIndex
        
        while i < row.endIndex {
            let char = row[i]
            
            if char == "\"" {
                if inQuotes {
                    let nextIndex = row.index(after: i)
                    if nextIndex < row.endIndex && row[nextIndex] == "\"" {
                        current.append("\"")
                        i = nextIndex
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
            
            i = row.index(after: i)
        }
        
        result.append(current)
        return result
    }
}

// MARK: - Custom Words Manager

final class CustomWordsManager {
    static let shared = CustomWordsManager()
    
    private let fileURL: URL
    private var words: [CustomWord] = []
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("GrammarPolice", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        fileURL = appFolder.appendingPathComponent("custom_words.json")
        loadWords()
    }
    
    var allWords: [CustomWord] {
        return words
    }
    
    func addWord(_ word: CustomWord) {
        words.append(word)
        saveWords()
    }
    
    func updateWord(_ word: CustomWord) {
        if let index = words.firstIndex(where: { $0.id == word.id }) {
            words[index] = word
            saveWords()
        }
    }
    
    func deleteWord(_ word: CustomWord) {
        words.removeAll { $0.id == word.id }
        saveWords()
    }
    
    func deleteWord(at offsets: IndexSet) {
        words.remove(atOffsets: offsets)
        saveWords()
    }
    
    // MARK: - Persistence
    
    private func loadWords() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            words = try JSONDecoder().decode([CustomWord].self, from: data)
        } catch {
            LoggingService.shared.log("Failed to load custom words: \(error)", level: .error)
        }
    }
    
    private func saveWords() {
        do {
            let data = try JSONEncoder().encode(words)
            try data.write(to: fileURL)
        } catch {
            LoggingService.shared.log("Failed to save custom words: \(error)", level: .error)
        }
    }
    
    // MARK: - Import/Export
    
    func exportToCSV() -> String {
        var csv = CustomWord.csvHeader + "\n"
        for word in words {
            csv += word.csvRow + "\n"
        }
        return csv
    }
    
    func importFromCSV(_ csvContent: String) -> Int {
        let lines = csvContent.components(separatedBy: .newlines)
        var importedCount = 0
        
        for (index, line) in lines.enumerated() {
            if index == 0 { continue }  // Skip header
            if line.isEmpty { continue }
            
            if let word = CustomWord.fromCSVRow(line) {
                if !words.contains(where: { $0.word.lowercased() == word.word.lowercased() }) {
                    words.append(word)
                    importedCount += 1
                }
            }
        }
        
        if importedCount > 0 {
            saveWords()
        }
        
        return importedCount
    }
}

