// ClarityApp.swift
// Main entry point for Clarity iOS App

import AppIntents
import FirebaseCore
import FirebaseFirestore
import SwiftUI
import TipKit

@main
struct ClarityApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authViewModel = AuthViewModel()

    @AppStorage("app.theme") private var selectedTheme: String = "system"

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
            .environment(feedbackManager)  // Optional if using singleton directly, but good practice
            .preferredColorScheme(colorScheme)
            .task {
                authViewModel.startListening()

                // Run after Firebase is configured (AppDelegate.didFinishLaunching)
                ClarityShortcuts.updateAppShortcutParameters()
                try? Tips.configure([
                    .displayFrequency(.immediate),
                    .datastoreLocation(.applicationDefault),
                ])
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
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // Layer 1: Enable Firestore offline persistence (disk cache for all reads)
        let firestoreSettings = FirestoreSettings()
        firestoreSettings.cacheSettings = PersistentCacheSettings(
            sizeBytes: FirestoreCacheSizeUnlimited as NSNumber
        )
        Firestore.firestore().settings = firestoreSettings

        return true
    }
}
