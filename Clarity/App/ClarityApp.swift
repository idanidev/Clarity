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
    /// El velo de privacidad está puesto. Se decide UNA vez, al salir de
    /// `.active`, y no en el `body`: `isBiometricEnabled` lee el llavero, que con
    /// el iPhone bloqueado no se deja leer y contesta «no». Si este `body` se
    /// reevaluara en segundo plano (basta el temporizador de un aviso), el velo
    /// se caería justo cuando hace falta.
    @State private var veloPuesto = false

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

                // Velo de privacidad: con el bloqueo activado, la miniatura del
                // selector de apps no enseña los importes. Va ligado a la fase y
                // no a `isLocked`: `.inactive` también salta con el Centro de
                // control, una alerta del sistema o el propio Face ID, y ahí el
                // velo se quita solo al volver, sin pedir nada (si toca
                // autenticarse lo decide `AppLockManager` al volver de segundo
                // plano).
                if veloPuesto {
                    VeloDePrivacidad()
                        // Sin transición: el sistema hace la foto de la miniatura
                        // enseguida, y a medio fundido se verían los importes.
                        .transition(.identity)
                        // Por encima también de los avisos (`FeedbackOverlay` va
                        // a 9999): un «50 € en Mercadona» a medio salir también
                        // es un importe.
                        .zIndex(10_000)
                }

                // App Lock Overlay
                if lockManager.isLocked {
                    LockScreenView(lockManager: lockManager)
                        // Entra de golpe y solo se funde al salir: al volver de
                        // segundo plano sustituye al velo en el mismo instante, y
                        // con un fundido de entrada se transparentaba la pantalla
                        // de debajo durante 0,2 s.
                        .transition(.asymmetric(insertion: .identity, removal: .opacity))
                        // Encima del velo: mientras Face ID pregunta la app está
                        // `.inactive`, y así se sigue viendo esta pantalla y no
                        // un parpadeo al velo.
                        .zIndex(10_001)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: lockManager.isLocked)
            .environment(authViewModel)
            .environment(feedbackManager)
            .environment(lockManager)
            .dynamicTypeSize(.xSmall ... .accessibility1)
            // Sin sesión, oscuro siempre: el login está pensado solo en oscuro.
            // Tiene que decidirse aquí, en la raíz: en iOS 27 el
            // `preferredColorScheme(.dark)` que llevaba el propio login no
            // ganaba a este y, con el móvil en claro, salía en claro.
            .preferredColorScheme(authViewModel.isAuthenticated ? colorScheme : .dark)
            .task {
                authViewModel.startListening()

                // Retención: cuenta la sesión, para pedir la reseña más adelante.
                ReviewRequestManager.shared.registerSession()
                #if DEBUG
                // En modo demo ni se engancha el destino de Firebase.
                if !ModoDemo.activo { AnalyticsBootstrap.configure() }
                #else
                AnalyticsBootstrap.configure()
                #endif
                // La reseña que deja pendiente abrir el resumen semanal no se
                // pide con la pantalla de bloqueo delante.
                RecordatoriosService.shared.estaBloqueada = { [lockManager] in lockManager.isLocked }

                // Integridad del dispositivo (solo en Release)
                #if !DEBUG
                let report = DeviceIntegrity.check()
                if report.isCompromised {
                    logger.warning("⚠️ Dispositivo comprometido: \(report.summary)")
                }
                #endif

                // Trabajo no crítico diferido tras el primer frame
                // (no bloquea el render inicial de la UI).
                Task.detached(priority: .utility) {
                    await MainActor.run {
                        ClarityShortcuts.updateAppShortcutParameters()
                        try? Tips.configure([
                            .displayFrequency(.immediate),
                            .datastoreLocation(.applicationDefault),
                        ])
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                switch newPhase {
                case .background:
                    // Lo normal es pasar antes por `.inactive`; por si acaso no.
                    if oldPhase == .active { veloPuesto = lockManager.isBiometricEnabled }
                    lockManager.sceneDidEnterBackground()
                    AnalyticsService.shared.endSession()
                    // Último momento seguro para dejar el resumen semanal y el
                    // diario con los datos al día antes de que salgan.
                    RecordatoriosService.shared.reprogramarAhora()
                case .inactive:
                    // Solo al SALIR de la app. Volviendo de segundo plano también
                    // se pasa por aquí, y el velo tiene que seguir como estaba.
                    if oldPhase == .active { veloPuesto = lockManager.isBiometricEnabled }
                case .active:
                    veloPuesto = false
                    lockManager.sceneWillEnterForeground()
                    AnalyticsService.shared.resumeSessionIfNeeded()
                    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                    Task { try? await UNUserNotificationCenter.current().setBadgeCount(0) }
                    removeStaleNotifications()
                    // Si se ha entrado tocando el resumen semanal (después de
                    // `sceneWillEnterForeground`, que es quien bloquea).
                    RecordatoriosService.shared.pedirResenaSiToca()
                @unknown default:
                    break
                }
            }
            .onChange(of: lockManager.isLocked) { _, bloqueada in
                if !bloqueada { RecordatoriosService.shared.pedirResenaSiToca() }
            }
        }
    }

    /// Elimina notificaciones locales con IDs antiguos (daily reminders, etc.)
    private func removeStaleNotifications() {
        let center = UNUserNotificationCenter.current()
        // Ojo: cualquier ID que la app programe debe estar en esa lista, o se
        // borra en el siguiente foreground (los de inactividad y el diario se
        // perdían así). Vive junto a quien programa el semanal y el diario.
        let validIDs = RecordatoriosService.Identificador.todos
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
        // Lo primero, para que el vigilante cubra también el arranque. Aquí solo
        // registra observadores: ver `Diagnosticos`.
        Diagnosticos.arranca()

        #if DEBUG
        // Modo demo (capturas): Firebase no se configura. Si algo llegara a
        // pedirlo, la app se para en vez de hablar con el proyecto real.
        if ModoDemo.activo {
            ModoDemo.preparar()
            return true
        }
        #endif

        FirebaseApp.configure()

        // Layer 1: Enable Firestore offline persistence (disk cache for all reads)
        let firestoreSettings = FirestoreSettings()
        firestoreSettings.cacheSettings = PersistentCacheSettings(
            sizeBytes: NSNumber(value: 100 * 1024 * 1024) // 100 MB limit
        )
        Firestore.firestore().settings = firestoreSettings

        // Para saber qué aviso se ha tocado. Tiene que estar puesto antes de
        // acabar el arranque: si no, el toque que abre la app en frío se pierde.
        // Sin `willPresent`, los avisos con la app delante siguen sin mostrarse,
        // igual que sin delegado.
        UNUserNotificationCenter.current().delegate = self

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

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Se ha tocado un aviso. Solo interesa el resumen de una semana con gastos, que
    /// deja pendiente pedir la reseña (ver `RecordatoriosService.avisoAbierto`).
    /// Del aviso se saca solo lo que se necesita antes de pasar al main actor.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let tipo = info[MarcaAviso.tipo] as? String
        let semanaConGastos = info[MarcaAviso.semanaConGastos] as? Bool ?? false
        await MainActor.run {
            RecordatoriosService.shared.avisoAbierto(tipo: tipo, semanaConGastos: semanaConGastos)
        }
    }
}
