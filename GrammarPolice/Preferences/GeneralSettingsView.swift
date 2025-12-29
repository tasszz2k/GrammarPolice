//
//  GeneralSettingsView.swift
//  GrammarPolice
//
//  General settings: launch at login, hotkeys, clipboard restore
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @StateObject private var grammarRecorder = HotkeyRecorder()
    @StateObject private var translateRecorder = HotkeyRecorder()
    
    @State private var isRecordingGrammar = false
    @State private var isRecordingTranslate = false
    @State private var accessibilityEnabled = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }
                ))
                
                Toggle("Restore Clipboard After Copy", isOn: Binding(
                    get: { settings.restoreClipboard },
                    set: { settings.restoreClipboard = $0 }
                ))
                .help("Restore the original clipboard content after using copy fallback")
            } header: {
                Text("Startup")
            }
            
            Section {
                HStack {
                    Text("Grammar Correction:")
                    Spacer()
                    
                    if isRecordingGrammar {
                        Text("Press new hotkey...")
                            .foregroundColor(.secondary)
                            .italic()
                        
                        Button("Cancel") {
                            grammarRecorder.stopRecording()
                            isRecordingGrammar = false
                        }
                    } else {
                        Text(settings.grammarHotkey.displayString)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                        
                        Button("Change") {
                            isRecordingGrammar = true
                            grammarRecorder.startRecording { hotkey in
                                if let hotkey = hotkey {
                                    settings.grammarHotkey = hotkey
                                }
                                isRecordingGrammar = false
                            }
                        }
                    }
                }
                
                HStack {
                    Text("Translate:")
                    Spacer()
                    
                    if isRecordingTranslate {
                        Text("Press new hotkey...")
                            .foregroundColor(.secondary)
                            .italic()
                        
                        Button("Cancel") {
                            translateRecorder.stopRecording()
                            isRecordingTranslate = false
                        }
                    } else {
                        Text(settings.translateHotkey.displayString)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                        
                        Button("Change") {
                            isRecordingTranslate = true
                            translateRecorder.startRecording { hotkey in
                                if let hotkey = hotkey {
                                    settings.translateHotkey = hotkey
                                }
                                isRecordingTranslate = false
                            }
                        }
                    }
                }
            } header: {
                Text("Hotkeys")
            }
            
            Section {
                HStack {
                    Image(systemName: accessibilityEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(accessibilityEnabled ? .green : .red)
                    
                    Text(accessibilityEnabled ? "Accessibility Enabled" : "Accessibility Not Enabled")
                    
                    Spacer()
                    
                    Button("Open System Settings") {
                        openAccessibilitySettings()
                    }
                }
                
                Text("GrammarPolice requires Accessibility permission to read and replace selected text.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Permissions")
            }
            
            Section {
                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        settings.resetToDefaults()
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            checkAccessibility()
        }
    }
    
    private func checkAccessibility() {
        accessibilityEnabled = AXSelectionService.shared.isAccessibilityEnabled
    }
    
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    GeneralSettingsView()
        .frame(width: 500, height: 400)
}

