//
//  DebugSettingsView.swift
//  GrammarPolice
//
//  Debug logging settings and log viewer
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DebugSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    
    @State private var logs: [String] = []
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Settings
            Form {
                Section {
                    Toggle("Enable Debug Logging", isOn: Binding(
                        get: { settings.debugLoggingEnabled },
                        set: { settings.debugLoggingEnabled = $0 }
                    ))
                    
                    Stepper("Verbosity Level: \(settings.logVerbosity)", value: Binding(
                        get: { settings.logVerbosity },
                        set: { settings.logVerbosity = $0 }
                    ), in: 1...3)
                    
                    Text("Level 1: Errors and warnings only\nLevel 2: Include info messages\nLevel 3: Include debug messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Logging")
                }
            }
            .formStyle(.grouped)
            .frame(height: 180)
            
            Divider()
            
            // Log viewer
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recent Logs")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: refreshLogs) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                    
                    Button("Copy All") {
                        copyAllLogs()
                    }
                    .disabled(logs.isEmpty)
                    
                    Button("Export Logs") {
                        exportLogs()
                    }
                    
                    Button("Clear Logs") {
                        clearLogs()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                if logs.isEmpty {
                    ContentUnavailableView {
                        Label("No Logs", systemImage: "doc.text")
                    } description: {
                        Text("Enable debug logging to see log entries here.")
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(logs.indices, id: \.self) { index in
                                LogEntryRow(log: logs[index])
                            }
                        }
                        .padding(.horizontal)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
            }
        }
        .onAppear {
            refreshLogs()
        }
    }
    
    private func refreshLogs() {
        isRefreshing = true
        logs = LoggingService.shared.getRecentLogs(limit: 200)
        isRefreshing = false
    }
    
    private func exportLogs() {
        let allLogs = LoggingService.shared.exportLogs()
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "grammarpolice_logs.txt"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? allLogs.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func copyAllLogs() {
        let allLogs = logs.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(allLogs, forType: .string)
    }
    
    private func clearLogs() {
        LoggingService.shared.clearAllLogs()
        logs = []
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let log: String
    
    private var logLevel: LogDisplayLevel {
        if log.contains("[ERROR]") {
            return .error
        } else if log.contains("[WARNING]") {
            return .warning
        } else if log.contains("[DEBUG]") {
            return .debug
        } else {
            return .info
        }
    }
    
    var body: some View {
        Text(log)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(logLevel.color)
            .textSelection(.enabled)
    }
    
    enum LogDisplayLevel {
        case error, warning, info, debug
        
        var color: Color {
            switch self {
            case .error: return .red
            case .warning: return .orange
            case .info: return .primary
            case .debug: return .secondary
            }
        }
    }
}

#Preview {
    DebugSettingsView()
        .frame(width: 600, height: 500)
}

