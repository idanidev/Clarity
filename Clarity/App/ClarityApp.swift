// ClarityApp.swift
// Main entry point for Clarity iOS App

import AppIntents
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import OSLog
import SwiftUI
import TipKit
import UserNotifications

private let logger = Logger(subsystem: "com.idanidev.clarity", category: "ClarityApp")

@main
struct ClarityApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authViewModel = AuthViewModel()
    @State private var lockManager = AppLockManager()

    @AppStorage("app.theme") private var selectedTheme: String = "system"

    @State private var feedbackManager = FeedbackManager.shared
    @Environment(\.scenePhase) private var scenePhase

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

                // App Lock Overlay
                if lockManager.isLocked {
                    LockScreenView(lockManager: lockManager)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: lockManager.isLocked)
            .environment(authViewModel)
            .environment(feedbackManager)
            .environment(lockManager)
            .dynamicTypeSize(.xSmall ... .accessibility1)
            .preferredColorScheme(colorScheme)
            .task {
                authViewModel.startListening()

                // Integridad del dispositivo (solo en Release)
                #if !DEBUG
                let report = DeviceIntegrity.check()
                if report.isCompromised {
                    logger.warning("⚠️ Dispositivo comprometido: \(report.summary)")
                }
                #endif

                // Run after Firebase is configured (AppDelegate.didFinishLaunching)
                ClarityShortcuts.updateAppShortcutParameters()
                try? Tips.configure([
                    .displayFrequency(.immediate),
                    .datastoreLocation(.applicationDefault),
                ])
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    lockManager.sceneDidEnterBackground()
                case .inactive:
                    break
                case .active:
                    lockManager.sceneWillEnterForeground()
                    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                    Task { try? await UNUserNotificationCenter.current().setBadgeCount(0) }
                    removeStaleNotifications()
                @unknown default:
                    break
                }
            }
        }
    }

    /// Elimina notificaciones locales con IDs antiguos (daily reminders, etc.)
    private func removeStaleNotifications() {
        let center = UNUserNotificationCenter.current()
        let validIDs: Set<String> = ["clarity.weekly.reminder", "clarity.endofmonth.reminder"]
        center.getPendingNotificationRequests { requests in
            let stale = requests.map(\.identifier).filter { !validIDs.contains($0) }
            if !stale.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: stale)
                logger.debug("🧹 Eliminadas \(stale.count) notificaciones antiguas: \(stale)")
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
            sizeBytes: NSNumber(value: 100 * 1024 * 1024) // 100 MB limit
        )
        Firestore.firestore().settings = firestoreSettings

        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}
