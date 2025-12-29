//
//  CustomWordsView.swift
//  GrammarPolice
//
//  Custom words management with import/export
//

import SwiftUI
import UniformTypeIdentifiers

struct CustomWordsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    
    @State private var words: [CustomWord] = []
    @State private var selectedWord: CustomWord?
    @State private var isAddingWord = false
    @State private var newWord = ""
    @State private var newWordCaseSensitive = false
    @State private var newWordWholeWord = true
    @State private var searchText = ""
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    @State private var importResult: String?
    
    var filteredWords: [CustomWord] {
        if searchText.isEmpty {
            return words
        }
        return words.filter { $0.word.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                
                Spacer()
                
                Button(action: { showingImportPicker = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                
                Button(action: exportWords) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                
                Button(action: { isAddingWord = true }) {
                    Label("Add", systemImage: "plus")
                }
            }
            .padding()
            
            // Settings
            HStack {
                Toggle("Case Sensitive (default)", isOn: Binding(
                    get: { settings.caseSensitiveMatching },
                    set: { settings.caseSensitiveMatching = $0 }
                ))
                
                Toggle("Whole Word Match (default)", isOn: Binding(
                    get: { settings.wholeWordMatching },
                    set: { settings.wholeWordMatching = $0 }
                ))
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
            
            // Word list
            List(selection: $selectedWord) {
                ForEach(filteredWords) { word in
                    HStack {
                        Text(word.word)
                            .font(.body)
                        
                        Spacer()
                        
                        if word.caseSensitive {
                            Text("Aa")
                                .font(.caption)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        if word.wholeWordMatch {
                            Text("\\b")
                                .font(.caption)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    .tag(word)
                    .contextMenu {
                        Button("Delete") {
                            deleteWord(word)
                        }
                    }
                }
                .onDelete(perform: deleteWords)
            }
            .listStyle(.inset)
            
            // Footer
            HStack {
                Text("\(words.count) custom words")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let result = importResult {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .sheet(isPresented: $isAddingWord) {
            addWordSheet
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .onAppear {
            loadWords()
        }
    }
    
    private var addWordSheet: some View {
        VStack(spacing: 16) {
            Text("Add Custom Word")
                .font(.headline)
            
            TextField("Word or phrase", text: $newWord)
                .textFieldStyle(.roundedBorder)
            
            Toggle("Case Sensitive", isOn: $newWordCaseSensitive)
            Toggle("Whole Word Match", isOn: $newWordWholeWord)
            
            HStack {
                Button("Cancel") {
                    isAddingWord = false
                    resetNewWord()
                }
                
                Spacer()
                
                Button("Add") {
                    addWord()
                }
                .disabled(newWord.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    private func loadWords() {
        words = CustomWordsManager.shared.allWords
    }
    
    private func addWord() {
        let word = CustomWord(
            word: newWord,
            caseSensitive: newWordCaseSensitive,
            wholeWordMatch: newWordWholeWord
        )
        CustomWordsManager.shared.addWord(word)
        loadWords()
        isAddingWord = false
        resetNewWord()
    }
    
    private func resetNewWord() {
        newWord = ""
        newWordCaseSensitive = settings.caseSensitiveMatching
        newWordWholeWord = settings.wholeWordMatching
    }
    
    private func deleteWord(_ word: CustomWord) {
        CustomWordsManager.shared.deleteWord(word)
        loadWords()
    }
    
    private func deleteWords(at offsets: IndexSet) {
        CustomWordsManager.shared.deleteWord(at: offsets)
        loadWords()
    }
    
    private func exportWords() {
        let csv = CustomWordsManager.shared.exportToCSV()
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "custom_words.csv"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try csv.write(to: url, atomically: true, encoding: .utf8)
                    importResult = "Exported successfully"
                } catch {
                    importResult = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let count = CustomWordsManager.shared.importFromCSV(content)
                importResult = "Imported \(count) words"
                loadWords()
            } catch {
                importResult = "Import failed: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            importResult = "Import failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    CustomWordsView()
        .frame(width: 500, height: 400)
}

