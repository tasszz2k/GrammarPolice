//
//  LoggingService.swift
//  GrammarPolice
//
//  File-based logging with rotation support
//

import Foundation
import os.log

enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    var prefix: String {
        switch self {
        case .debug: return "[DEBUG]"
        case .info: return "[INFO]"
        case .warning: return "[WARNING]"
        case .error: return "[ERROR]"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

final class LoggingService {
    static let shared = LoggingService()
    
    private let logDirectory: URL
    private let maxLogFiles = 5
    private let maxLogFileSize: UInt64 = 5 * 1024 * 1024  // 5MB
    private let dateFormatter: DateFormatter
    private let timestampFormatter: DateFormatter
    private let osLog = OSLog(subsystem: "com.tasszz2k.GrammarPolice", category: "general")
    private let queue = DispatchQueue(label: "com.grammarpolice.logging", qos: .utility)
    
    private var currentLogFile: URL?
    private var logBuffer: [String] = []
    private let bufferLimit = 10
    
    private init() {
        // Setup log directory
        let libraryLogs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("GrammarPolice", isDirectory: true)
        
        self.logDirectory = libraryLogs
        
        // Setup date formatters
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // Create log directory if needed
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        // Initialize current log file
        currentLogFile = getOrCreateTodayLogFile()
        
        // Perform rotation check
        queue.async { [weak self] in
            self?.rotateLogsIfNeeded()
        }
    }
    
    // MARK: - Public Logging Methods
    
    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let shouldLog: Bool
        
        // Check if debug logging is enabled (use cached value to avoid main actor access)
        if level == .debug {
            shouldLog = UserDefaults.standard.bool(forKey: "debugLoggingEnabled")
        } else {
            shouldLog = true
        }
        
        guard shouldLog else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let timestamp = timestampFormatter.string(from: Date())
        let logMessage = "\(timestamp) \(level.prefix) [\(fileName):\(line)] \(function) - \(message)"
        
        // Log to os_log
        os_log("%{public}@", log: osLog, type: level.osLogType, message)
        
        // Log to file
        queue.async { [weak self] in
            self?.writeToFile(logMessage)
        }
    }
    
    func logHotkeyPress(sourceApp: String, selectedTextLength: Int, mode: String) {
        log("Hotkey pressed - App: \(sourceApp), TextLength: \(selectedTextLength), Mode: \(mode)", level: .info)
    }
    
    func logLLMRequest(backend: String, maskedTokensCount: Int) {
        log("LLM request - Backend: \(backend), MaskedTokens: \(maskedTokensCount)", level: .info)
    }
    
    func logLLMResponse(backend: String, latencyMs: Int, success: Bool) {
        let status = success ? "success" : "failure"
        log("LLM response - Backend: \(backend), Latency: \(latencyMs)ms, Status: \(status)", level: .info)
    }
    
    func logReplacement(success: Bool, method: String) {
        log("Text replacement - Success: \(success), Method: \(method)", level: .info)
    }
    
    // MARK: - File Operations
    
    private func getOrCreateTodayLogFile() -> URL {
        let todayString = dateFormatter.string(from: Date())
        let fileName = "grammarpolice-\(todayString).log"
        return logDirectory.appendingPathComponent(fileName)
    }
    
    private func writeToFile(_ message: String) {
        guard let logFile = currentLogFile else { return }
        
        logBuffer.append(message)
        
        // Flush buffer when limit is reached
        if logBuffer.count >= bufferLimit {
            flushBuffer(to: logFile)
        }
    }
    
    private func flushBuffer(to logFile: URL) {
        guard !logBuffer.isEmpty else { return }
        
        let content = logBuffer.joined(separator: "\n") + "\n"
        logBuffer.removeAll()
        
        if FileManager.default.fileExists(atPath: logFile.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                fileHandle.seekToEndOfFile()
                if let data = content.data(using: .utf8) {
                    fileHandle.write(data)
                }
                try? fileHandle.close()
            }
        } else {
            try? content.write(to: logFile, atomically: true, encoding: .utf8)
        }
        
        // Check if rotation is needed
        checkAndRotateCurrentFile()
    }
    
    private func checkAndRotateCurrentFile() {
        guard let logFile = currentLogFile else { return }
        
        if let attributes = try? FileManager.default.attributesOfItem(atPath: logFile.path),
           let fileSize = attributes[.size] as? UInt64,
           fileSize > maxLogFileSize {
            rotateLogsIfNeeded()
        }
    }
    
    private func rotateLogsIfNeeded() {
        do {
            let logFiles = try FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "log" }
                .sorted { url1, url2 in
                    let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate
                    let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate
                    return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
                }
            
            // Remove oldest files if we have too many
            if logFiles.count > maxLogFiles {
                for file in logFiles.dropFirst(maxLogFiles) {
                    try FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            os_log("Failed to rotate logs: %{public}@", log: osLog, type: .error, error.localizedDescription)
        }
    }
    
    // MARK: - Log Retrieval
    
    func getRecentLogs(limit: Int = 100) -> [String] {
        // Flush buffer first
        if let logFile = currentLogFile {
            queue.sync {
                flushBuffer(to: logFile)
            }
        }
        
        guard let logFile = currentLogFile,
              let content = try? String(contentsOf: logFile, encoding: .utf8) else {
            return []
        }
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return Array(lines.suffix(limit))
    }
    
    func getAllLogFiles() -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "log" }
                .sorted { url1, url2 in
                    let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate
                    let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate
                    return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
                }
        } catch {
            return []
        }
    }
    
    func exportLogs() -> String {
        var allLogs = ""
        
        for file in getAllLogFiles() {
            if let content = try? String(contentsOf: file, encoding: .utf8) {
                allLogs += "=== \(file.lastPathComponent) ===\n"
                allLogs += content
                allLogs += "\n\n"
            }
        }
        
        return allLogs
    }
    
    func clearAllLogs() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            for file in self.getAllLogFiles() {
                try? FileManager.default.removeItem(at: file)
            }
            
            self.currentLogFile = self.getOrCreateTodayLogFile()
            self.log("Logs cleared", level: .info)
        }
    }
}

