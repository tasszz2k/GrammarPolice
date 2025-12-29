//
//  HistoryStore.swift
//  GrammarPolice
//
//  SwiftData-based history storage with export functionality
//

import Foundation
import SwiftData

@MainActor
final class HistoryStore {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - CRUD Operations
    
    func addEntry(_ entry: HistoryEntry) {
        modelContext.insert(entry)
        
        do {
            try modelContext.save()
            LoggingService.shared.log("History entry saved", level: .debug)
        } catch {
            LoggingService.shared.log("Failed to save history entry: \(error)", level: .error)
        }
    }
    
    func addEntry(
        input: String,
        output: String,
        mode: HistoryMode,
        appBundleIdentifier: String,
        appName: String,
        success: Bool,
        replacementDone: Bool,
        customWordsUsed: [String],
        sourceLanguage: String = "en",
        targetLanguage: String = "",
        llmBackend: String,
        llmLatencyMs: Int
    ) {
        let entry = HistoryEntry(
            input: input,
            output: output,
            mode: mode,
            appBundleIdentifier: appBundleIdentifier,
            appName: appName,
            success: success,
            replacementDone: replacementDone,
            customWordsUsed: customWordsUsed,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            llmBackend: llmBackend,
            llmLatencyMs: llmLatencyMs
        )
        
        addEntry(entry)
    }
    
    func fetchAllEntries() -> [HistoryEntry] {
        let descriptor = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            LoggingService.shared.log("Failed to fetch history entries: \(error)", level: .error)
            return []
        }
    }
    
    func fetchEntries(limit: Int) -> [HistoryEntry] {
        var descriptor = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            LoggingService.shared.log("Failed to fetch history entries: \(error)", level: .error)
            return []
        }
    }
    
    func fetchEntries(mode: HistoryMode) -> [HistoryEntry] {
        let modeString = mode.rawValue
        let predicate = #Predicate<HistoryEntry> { entry in
            entry.mode == modeString
        }
        
        let descriptor = FetchDescriptor<HistoryEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            LoggingService.shared.log("Failed to fetch history entries: \(error)", level: .error)
            return []
        }
    }
    
    func deleteEntry(_ entry: HistoryEntry) {
        modelContext.delete(entry)
        
        do {
            try modelContext.save()
        } catch {
            LoggingService.shared.log("Failed to delete history entry: \(error)", level: .error)
        }
    }
    
    func deleteEntries(_ entries: [HistoryEntry]) {
        for entry in entries {
            modelContext.delete(entry)
        }
        
        do {
            try modelContext.save()
        } catch {
            LoggingService.shared.log("Failed to delete history entries: \(error)", level: .error)
        }
    }
    
    // MARK: - Purge Old Entries
    
    func purgeEntriesOlderThan(days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let predicate = #Predicate<HistoryEntry> { entry in
            entry.timestamp < cutoffDate
        }
        
        let descriptor = FetchDescriptor<HistoryEntry>(predicate: predicate)
        
        do {
            let oldEntries = try modelContext.fetch(descriptor)
            for entry in oldEntries {
                modelContext.delete(entry)
            }
            try modelContext.save()
            LoggingService.shared.log("Purged \(oldEntries.count) entries older than \(days) days", level: .info)
        } catch {
            LoggingService.shared.log("Failed to purge old entries: \(error)", level: .error)
        }
    }
    
    func deleteAllEntries() {
        do {
            try modelContext.delete(model: HistoryEntry.self)
            try modelContext.save()
            LoggingService.shared.log("All history entries deleted", level: .info)
        } catch {
            LoggingService.shared.log("Failed to delete all entries: \(error)", level: .error)
        }
    }
    
    // MARK: - Export
    
    func exportToCSV(entries: [HistoryEntry]? = nil) -> String {
        let entriesToExport = entries ?? fetchAllEntries()
        
        var csv = HistoryEntry.csvHeader + "\n"
        for entry in entriesToExport {
            csv += entry.csvRow + "\n"
        }
        
        return csv
    }
    
    func exportToJSON(entries: [HistoryEntry]? = nil) -> String {
        let entriesToExport = entries ?? fetchAllEntries()
        
        let jsonArray = entriesToExport.map { $0.jsonDictionary }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonArray, options: [.prettyPrinted, .sortedKeys])
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            LoggingService.shared.log("Failed to export to JSON: \(error)", level: .error)
            return "[]"
        }
    }
    
    func exportForLearning(entries: [HistoryEntry]? = nil) -> String {
        let entriesToExport = entries ?? fetchAllEntries()
        
        let learningArray = entriesToExport.map { $0.learningExportDictionary }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: learningArray, options: [.prettyPrinted])
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            LoggingService.shared.log("Failed to export for learning: \(error)", level: .error)
            return "[]"
        }
    }
    
    // MARK: - Statistics
    
    func getStatistics() -> HistoryStatistics {
        let allEntries = fetchAllEntries()
        
        let grammarCount = allEntries.filter { $0.mode == HistoryMode.grammar.rawValue }.count
        let translateCount = allEntries.filter { $0.mode == HistoryMode.translate.rawValue }.count
        let successCount = allEntries.filter { $0.success }.count
        let replacementCount = allEntries.filter { $0.replacementDone }.count
        
        let avgLatency: Double
        if allEntries.isEmpty {
            avgLatency = 0
        } else {
            avgLatency = Double(allEntries.map { $0.llmLatencyMs }.reduce(0, +)) / Double(allEntries.count)
        }
        
        return HistoryStatistics(
            totalEntries: allEntries.count,
            grammarCorrections: grammarCount,
            translations: translateCount,
            successfulOperations: successCount,
            directReplacements: replacementCount,
            averageLatencyMs: avgLatency
        )
    }
}

// MARK: - Statistics Model

struct HistoryStatistics {
    let totalEntries: Int
    let grammarCorrections: Int
    let translations: Int
    let successfulOperations: Int
    let directReplacements: Int
    let averageLatencyMs: Double
}

