//
//  ExportSettingsView.swift
//  GrammarPolice
//
//  Auto-export settings for monthly learning data export
//

import SwiftUI
import AppKit

struct ExportSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    
    private var filenamePreview: String {
        let prefix = settings.autoExportPrefix.isEmpty ? "learning_data" : settings.autoExportPrefix
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM"
        let dateString = formatter.string(from: Date())
        return "\(prefix)_\(dateString).json"
    }
    
    private var lastExportString: String {
        guard let date = settings.lastAutoExportDate else {
            return "Never"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Automatic Export", isOn: Binding(
                    get: { settings.autoExportEnabled },
                    set: { settings.autoExportEnabled = $0 }
                ))
                
                Text("Automatically export learning data on the 1st of each month")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Auto Export")
            }
            
            if settings.autoExportEnabled {
                Section {
                    HStack {
                        Text("Folder:")
                        
                        Text(settings.autoExportFolderPath.isEmpty ? "Not set" : settings.autoExportFolderPath)
                            .foregroundColor(settings.autoExportFolderPath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button("Browse...") {
                            selectFolder()
                        }
                    }
                    
                    TextField("Filename Prefix:", text: Binding(
                        get: { settings.autoExportPrefix },
                        set: { settings.autoExportPrefix = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Text("Preview:")
                            .foregroundColor(.secondary)
                        Text(filenamePreview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Export Configuration")
                }
                
                Section {
                    HStack {
                        Text("Last Export:")
                        Spacer()
                        Text(lastExportString)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Status")
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Export Folder"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                settings.autoExportFolderPath = url.path
            }
        }
    }
}

#Preview {
    ExportSettingsView()
        .frame(width: 500, height: 400)
}
