//
//  HistoryView.swift
//  GrammarPolice
//
//  History viewer with export and purge functionality
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HistoryEntry.timestamp, order: .reverse) private var entries: [HistoryEntry]
    
    @State private var selectedEntries: Set<HistoryEntry.ID> = []
    @State private var searchText = ""
    @State private var filterMode: HistoryMode?
    @State private var showingPurgeAlert = false
    @State private var purgeDays = 30
    @State private var detailEntry: HistoryEntry?
    
    var filteredEntries: [HistoryEntry] {
        var result = entries
        
        if let mode = filterMode {
            result = result.filter { $0.mode == mode.rawValue }
        }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.input.localizedCaseInsensitiveContains(searchText) ||
                $0.output.localizedCaseInsensitiveContains(searchText) ||
                $0.appName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                
                Picker("Filter:", selection: $filterMode) {
                    Text("All").tag(nil as HistoryMode?)
                    Text("Grammar").tag(HistoryMode.grammar as HistoryMode?)
                    Text("Translate").tag(HistoryMode.translate as HistoryMode?)
                }
                .frame(width: 150)
                
                Spacer()
                
                Menu("Export") {
                    Button("Export All as CSV") {
                        exportCSV(entries: nil)
                    }
                    Button("Export All as JSON") {
                        exportJSON(entries: nil)
                    }
                    Button("Export for Learning") {
                        exportLearning(entries: nil)
                    }
                    
                    if !selectedEntries.isEmpty {
                        Divider()
                        Button("Export Selected as CSV") {
                            exportCSV(entries: getSelectedEntries())
                        }
                        Button("Export Selected as JSON") {
                            exportJSON(entries: getSelectedEntries())
                        }
                    }
                }
                
                Button("Purge") {
                    showingPurgeAlert = true
                }
            }
            .padding()
            
            Divider()
            
            // Stats
            if !entries.isEmpty {
                let stats = getStatistics()
                HStack(spacing: 16) {
                    StatBadge(title: "Total", value: "\(stats.totalEntries)")
                    StatBadge(title: "Grammar", value: "\(stats.grammarCorrections)")
                    StatBadge(title: "Translate", value: "\(stats.translations)")
                    StatBadge(title: "Success", value: "\(stats.successfulOperations)")
                    StatBadge(title: "Avg Latency", value: "\(Int(stats.averageLatencyMs))ms")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
            }
            
            // Entry list
            if filteredEntries.isEmpty {
                ContentUnavailableView {
                    Label("No History", systemImage: "clock")
                } description: {
                    Text("Your grammar corrections and translations will appear here.")
                }
            } else {
                List(selection: $selectedEntries) {
                    ForEach(filteredEntries) { entry in
                        HistoryEntryRow(entry: entry)
                            .tag(entry.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                detailEntry = entry
                            }
                    }
                    .onDelete(perform: deleteEntries)
                }
                .listStyle(.inset)
            }
            
            // Footer
            HStack {
                Text("\(filteredEntries.count) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !selectedEntries.isEmpty {
                    Text("(\(selectedEntries.count) selected)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
        }
        .sheet(item: $detailEntry) { entry in
            HistoryDetailView(entry: entry) {
                detailEntry = nil
            }
        }
        .alert("Purge History", isPresented: $showingPurgeAlert) {
            TextField("Days", value: $purgeDays, format: .number)
            Button("Purge") {
                purgeOldEntries()
            }
            Button("Delete All", role: .destructive) {
                deleteAllEntries()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete entries older than \(purgeDays) days, or delete all entries.")
        }
    }
    
    private func getSelectedEntries() -> [HistoryEntry] {
        return filteredEntries.filter { selectedEntries.contains($0.id) }
    }
    
    private func getStatistics() -> HistoryStatistics {
        let grammarCount = entries.filter { $0.mode == HistoryMode.grammar.rawValue }.count
        let translateCount = entries.filter { $0.mode == HistoryMode.translate.rawValue }.count
        let successCount = entries.filter { $0.success }.count
        let avgLatency = entries.isEmpty ? 0.0 : Double(entries.map { $0.llmLatencyMs }.reduce(0, +)) / Double(entries.count)
        
        return HistoryStatistics(
            totalEntries: entries.count,
            grammarCorrections: grammarCount,
            translations: translateCount,
            successfulOperations: successCount,
            directReplacements: entries.filter { $0.replacementDone }.count,
            averageLatencyMs: avgLatency
        )
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredEntries[index])
        }
        try? modelContext.save()
    }
    
    private func purgeOldEntries() {
        let store = HistoryStore(modelContext: modelContext)
        store.purgeEntriesOlderThan(days: purgeDays)
    }
    
    private func deleteAllEntries() {
        let store = HistoryStore(modelContext: modelContext)
        store.deleteAllEntries()
    }
    
    private func exportCSV(entries: [HistoryEntry]?) {
        let store = HistoryStore(modelContext: modelContext)
        let csv = store.exportToCSV(entries: entries)
        saveExport(content: csv, filename: "history.csv", type: .commaSeparatedText)
    }
    
    private func exportJSON(entries: [HistoryEntry]?) {
        let store = HistoryStore(modelContext: modelContext)
        let json = store.exportToJSON(entries: entries)
        saveExport(content: json, filename: "history.json", type: .json)
    }
    
    private func exportLearning(entries: [HistoryEntry]?) {
        let store = HistoryStore(modelContext: modelContext)
        let json = store.exportForLearning(entries: entries)
        saveExport(content: json, filename: "learning_data.json", type: .json)
    }
    
    private func saveExport(content: String, filename: String, type: UTType) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [type]
        savePanel.nameFieldStringValue = filename
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

// MARK: - History Entry Row

struct HistoryEntryRow: View {
    let entry: HistoryEntry
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.mode == "grammar" ? "text.badge.checkmark" : "globe")
                    .foregroundColor(entry.mode == "grammar" ? .blue : .green)
                
                Text(entry.appName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(dateFormatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if entry.replacementDone {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            Text(MaskingService.scrubOrphanTokens(in: entry.input))
                .font(.body)
                .lineLimit(1)

            Text(MaskingService.scrubOrphanTokens(in: entry.output))
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(1)

            if !entry.exploreContent.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "book")
                        .font(.caption2)
                    Text("Explore")
                        .font(.caption2)
                }
                .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - History Detail View

struct HistoryDetailView: View {
    let entry: HistoryEntry
    let onClose: () -> Void

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: entry.mode == "grammar" ? "text.badge.checkmark" : "globe")
                    .foregroundColor(entry.mode == "grammar" ? .blue : .green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.mode == "grammar" ? "Grammar Correction" : "Translation")
                        .font(.headline)
                    Text("\(entry.appName) · \(dateFormatter.string(from: entry.timestamp))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Close") { onClose() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detailSection(title: "Input", body: MaskingService.scrubOrphanTokens(in: entry.input))
                    detailSection(
                        title: entry.mode == "grammar" ? "Corrected" : "Translation",
                        body: MaskingService.scrubOrphanTokens(in: entry.output)
                    )

                    if !entry.exploreContent.isEmpty {
                        detailSection(title: "Explore", body: entry.exploreContent)
                    }

                    metadataSection
                }
                .padding()
            }
        }
        .frame(width: 640, height: 560)
    }

    private func detailSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .bold()
                .foregroundColor(.secondary)
            ScrollView {
                Text(body)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 220)
            .padding(8)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(6)
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Metadata")
                .font(.subheadline)
                .bold()
                .foregroundColor(.secondary)
            Group {
                metaRow("App", value: "\(entry.appName) (\(entry.appBundleIdentifier))")
                metaRow("Mode", value: entry.mode)
                if !entry.targetLanguage.isEmpty {
                    metaRow("Target language", value: entry.targetLanguage)
                }
                metaRow("Backend", value: entry.llmBackend)
                metaRow("Latency", value: "\(entry.llmLatencyMs) ms")
                metaRow("Replaced", value: entry.replacementDone ? "yes" : "no")
                metaRow("Success", value: entry.success ? "yes" : "no")
                if !entry.customWordsUsed.isEmpty {
                    metaRow("Custom words", value: entry.customWordsUsed.joined(separator: ", "))
                }
            }
            .font(.caption)
        }
    }

    private func metaRow(_ key: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(key):")
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    HistoryView()
}

