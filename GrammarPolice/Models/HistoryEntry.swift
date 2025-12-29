//
//  HistoryEntry.swift
//  GrammarPolice
//
//  SwiftData model for history entries
//

import Foundation
import SwiftData

enum HistoryMode: String, Codable {
    case grammar = "grammar"
    case translate = "translate"
}

@Model
final class HistoryEntry {
    var id: UUID
    var input: String
    var output: String
    var mode: String
    var timestamp: Date
    var appBundleIdentifier: String
    var appName: String
    var success: Bool
    var replacementDone: Bool
    var customWordsUsed: [String]
    var sourceLanguage: String
    var targetLanguage: String
    var llmBackend: String
    var llmLatencyMs: Int
    
    init(
        id: UUID = UUID(),
        input: String,
        output: String,
        mode: HistoryMode,
        timestamp: Date = Date(),
        appBundleIdentifier: String = "",
        appName: String = "",
        success: Bool = true,
        replacementDone: Bool = false,
        customWordsUsed: [String] = [],
        sourceLanguage: String = "en",
        targetLanguage: String = "",
        llmBackend: String = "OpenAI",
        llmLatencyMs: Int = 0
    ) {
        self.id = id
        self.input = input
        self.output = output
        self.mode = mode.rawValue
        self.timestamp = timestamp
        self.appBundleIdentifier = appBundleIdentifier
        self.appName = appName
        self.success = success
        self.replacementDone = replacementDone
        self.customWordsUsed = customWordsUsed
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.llmBackend = llmBackend
        self.llmLatencyMs = llmLatencyMs
    }
    
    var historyMode: HistoryMode {
        return HistoryMode(rawValue: mode) ?? .grammar
    }
    
    // MARK: - CSV Export
    
    static let csvHeader = "timestamp,app,input,output,mode,language_from,language_to,custom_words_ignored,replacement_done"
    
    var csvRow: String {
        let dateFormatter = ISO8601DateFormatter()
        
        func escapeCSV(_ value: String) -> String {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
                return "\"\(escaped)\""
            }
            return escaped
        }
        
        return [
            escapeCSV(dateFormatter.string(from: timestamp)),
            escapeCSV(appName),
            escapeCSV(input),
            escapeCSV(output),
            escapeCSV(mode),
            escapeCSV(sourceLanguage),
            escapeCSV(targetLanguage),
            escapeCSV(customWordsUsed.joined(separator: ";")),
            String(replacementDone)
        ].joined(separator: ",")
    }
    
    // MARK: - JSON Export
    
    var jsonDictionary: [String: Any] {
        let dateFormatter = ISO8601DateFormatter()
        return [
            "id": id.uuidString,
            "timestamp": dateFormatter.string(from: timestamp),
            "app_bundle_identifier": appBundleIdentifier,
            "app_name": appName,
            "input": input,
            "output": output,
            "mode": mode,
            "source_language": sourceLanguage,
            "target_language": targetLanguage,
            "custom_words_used": customWordsUsed,
            "replacement_done": replacementDone,
            "success": success,
            "llm_backend": llmBackend,
            "llm_latency_ms": llmLatencyMs
        ]
    }
    
    // MARK: - Learning Export Format
    
    var learningExportDictionary: [String: String] {
        return [
            "input": input,
            "correction": output,
            "explanation": "Mode: \(mode)"
        ]
    }
}

