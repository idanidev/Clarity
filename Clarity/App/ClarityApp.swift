// ClarityApp.swift
// Main entry point for Clarity iOS App

import SwiftUI
import FirebaseCore
import AppIntents

@main
struct ClarityApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        Task {
            ClarityShortcuts.updateAppShortcutParameters()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
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
