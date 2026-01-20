// ClarityApp.swift
// Main entry point for Clarity iOS App

import SwiftUI
import FirebaseCore
import AppIntents
import TipKit

@main
struct ClarityApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authViewModel = AuthViewModel()
    
    @AppStorage("app.theme") private var selectedTheme: String = "system"
    
    init() {
        Task {
            ClarityShortcuts.updateAppShortcutParameters()
            
            // Configure Tips
            try? Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
        }
    }
    
    @State private var feedbackManager = FeedbackManager.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                ContentView()
                
                // Global Feedback Overlay
                if let message = feedbackManager.currentMessage {
                    FeedbackOverlay(message: message) {
                        feedbackManager.dismiss()
                    }
                }
            }
            .environment(authViewModel)
            .environment(feedbackManager) // Optional if using singleton directly, but good practice
            .preferredColorScheme(colorScheme)
            .task {
                authViewModel.startListening()
            }
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch selectedTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

// AppDelegate for Firebase and Push Notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
