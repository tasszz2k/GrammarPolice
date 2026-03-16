//
//  AutoExportService.swift
//  GrammarPolice
//
//  Automatic monthly export of learning data on the 1st of each month
//

import Foundation
import SwiftData

enum ExportResult {
    case success(filename: String, entryCount: Int)
    case noEntries
    case error(String)
}

@MainActor
final class AutoExportService {
    
    static private(set) var shared: AutoExportService?
    
    private let modelContainer: ModelContainer
    private var exportTimer: Timer?
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        Self.shared = self
    }
    
    func start() {
        guard SettingsManager.shared.autoExportEnabled else {
            LoggingService.shared.log("Auto-export is disabled", level: .debug)
            return
        }
        
        guard !SettingsManager.shared.autoExportFolderPath.isEmpty else {
            LoggingService.shared.log("Auto-export folder not configured", level: .warning)
            return
        }
        
        checkAndPerformCatchUpExport()
        scheduleNextExport()
    }
    
    func stop() {
        exportTimer?.invalidate()
        exportTimer = nil
    }
    
    func exportNow() -> ExportResult {
        let settings = SettingsManager.shared
        let folderPath = settings.autoExportFolderPath
        
        guard !folderPath.isEmpty else {
            return .error("Export folder not configured")
        }
        
        let prefix = settings.autoExportPrefix.isEmpty ? "learning_data" : settings.autoExportPrefix
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        
        let monthString = String(format: "%04d_%02d", year, month)
        let filename = "\(prefix)_\(monthString).json"
        let fileURL = URL(fileURLWithPath: folderPath).appendingPathComponent(filename)
        
        let folderURL = URL(fileURLWithPath: folderPath)
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            } catch {
                return .error("Failed to create export folder: \(error.localizedDescription)")
            }
        }
        
        let store = HistoryStore(modelContext: modelContainer.mainContext)
        let entries = store.fetchEntries(forYear: year, month: month)
        
        if entries.isEmpty {
            return .noEntries
        }
        
        let json = store.exportForLearning(entries: entries)
        
        do {
            try json.write(to: fileURL, atomically: true, encoding: .utf8)
            SettingsManager.shared.lastAutoExportDate = Date()
            LoggingService.shared.log("Manual export: \(entries.count) entries to \(filename)", level: .info)
            return .success(filename: filename, entryCount: entries.count)
        } catch {
            return .error("Failed to write export file: \(error.localizedDescription)")
        }
    }
    
    private func checkAndPerformCatchUpExport() {
        let calendar = Calendar.current
        let now = Date()
        
        guard let firstOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return
        }
        
        if let lastExport = SettingsManager.shared.lastAutoExportDate,
           lastExport >= firstOfCurrentMonth {
            LoggingService.shared.log("Auto-export already done for current period", level: .debug)
            return
        }
        
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: firstOfCurrentMonth) else {
            return
        }
        
        let year = calendar.component(.year, from: previousMonth)
        let month = calendar.component(.month, from: previousMonth)
        
        performExport(forYear: year, month: month)
    }
    
    private func performExport(forYear year: Int, month: Int) {
        let settings = SettingsManager.shared
        let folderPath = settings.autoExportFolderPath
        let prefix = settings.autoExportPrefix.isEmpty ? "learning_data" : settings.autoExportPrefix
        
        let monthString = String(format: "%04d_%02d", year, month)
        let filename = "\(prefix)_\(monthString).json"
        let fileURL = URL(fileURLWithPath: folderPath).appendingPathComponent(filename)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            LoggingService.shared.log("Auto-export file already exists: \(filename), skipping", level: .warning)
            SettingsManager.shared.lastAutoExportDate = Date()
            return
        }
        
        let folderURL = URL(fileURLWithPath: folderPath)
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            } catch {
                LoggingService.shared.log("Failed to create auto-export folder: \(error)", level: .error)
                return
            }
        }
        
        let store = HistoryStore(modelContext: modelContainer.mainContext)
        let entries = store.fetchEntries(forYear: year, month: month)
        
        if entries.isEmpty {
            LoggingService.shared.log("No entries for \(monthString), skipping auto-export", level: .info)
            SettingsManager.shared.lastAutoExportDate = Date()
            return
        }
        
        let json = store.exportForLearning(entries: entries)
        
        do {
            try json.write(to: fileURL, atomically: true, encoding: .utf8)
            SettingsManager.shared.lastAutoExportDate = Date()
            LoggingService.shared.log("Auto-exported \(entries.count) entries to \(filename)", level: .info)
        } catch {
            LoggingService.shared.log("Failed to write auto-export file: \(error)", level: .error)
        }
    }
    
    private func scheduleNextExport() {
        exportTimer?.invalidate()
        
        let calendar = Calendar.current
        let now = Date()
        
        guard let firstOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let firstOfNextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfCurrentMonth) else {
            return
        }
        
        let interval = firstOfNextMonth.timeIntervalSince(now)
        
        LoggingService.shared.log("Next auto-export scheduled in \(Int(interval / 3600)) hours", level: .debug)
        
        exportTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndPerformCatchUpExport()
                self?.scheduleNextExport()
            }
        }
    }
}
