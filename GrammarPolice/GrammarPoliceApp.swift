//
//  GrammarPoliceApp.swift
//  GrammarPolice
//
//  Created by Tass Dinh on 29/12/2025.
//

import SwiftUI
import SwiftData
import Combine

@main
struct GrammarPoliceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
