//
//  PreferencesView.swift
//  GrammarPolice
//
//  Main preferences window with tab navigation
//

import SwiftUI
import SwiftData

struct PreferencesView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            GrammarSettingsView()
                .tabItem {
                    Label("Grammar", systemImage: "text.badge.checkmark")
                }
            
            LLMSettingsView()
                .tabItem {
                    Label("LLM", systemImage: "brain")
                }
            
            CustomWordsView()
                .tabItem {
                    Label("Custom Words", systemImage: "textformat.abc")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            
            DebugSettingsView()
                .tabItem {
                    Label("Debug", systemImage: "ladybug")
                }
        }
        .frame(minWidth: 600, minHeight: 450)
        .padding()
    }
}

#Preview {
    PreferencesView()
}

