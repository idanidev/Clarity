// AuthViewModel.swift
// Authentication state management

import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import SwiftData

import AuthenticationServices
import CryptoKit
import GoogleSignIn
import OSLog
import Observation
import UIKit

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading = true
    var currentUser: User?
    var userDocument: UserDocument?
    var errorMessage: String?

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private let logger = Logger(subsystem: "com.idanidev.clarity", category: "AuthViewModel")
    @ObservationIgnored
    private lazy var db = Firestore.firestore()
    
    init() {
        // Validation moved to startListening to ensure Firebase is configured
    }
    
    // deinit removed to avoid MainActor isolation issues.
    // Listener uses weak self and will auto-cleanup/ignore updates if self is gone.
    
    func startListening() {
        if authStateListener == nil {
            setupAuthStateListener()
        }
    }
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil

                if let user = user {
                    // Wipe local data si cambió userId (cuenta distinta a última sesión)
                    let lastUserId = UserDefaults.standard.string(forKey: "auth.lastUserId")
                    if lastUserId != nil && lastUserId != user.uid {
                        self?.wipeLocalData()
                    }
                    UserDefaults.standard.set(user.uid, forKey: "auth.lastUserId")

                    await self?.fetchUserDocument(userId: user.uid)
                    if let doc = self?.userDocument {
                        UserDataManager.shared.setUserDocument(doc)
                    }
                    await UserDataManager.shared.loadUserData()
                }

                self?.isLoading = false
            }
        }
    }

    private func wipeLocalData() {
        do {
            let context = SwiftDataService.shared.context
            try context.delete(model: ExpenseModel.self)
            try context.save()
        } catch {
            logger.error("wipeLocalData: SwiftData wipe failed: \(error.localizedDescription)")
        }
        UserDataManager.shared.clearCache()
        UserDataManager.shared.expenses = []
        UserDataManager.shared.userDocument = nil
        WidgetDataManager.shared.clearWidgetData()
    }

    private func fetchUserDocument(userId: String) async {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if document.exists {
                userDocument = try document.data(as: UserDocument.self)
            }
        } catch {
            logger.error("Error fetching user document: \(error)")
        }
    }
    
    // MARK: - Auth Methods
    
    func signIn(email: String, password: String) async throws {
        errorMessage = nil
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }
    
    func signUp(email: String, password: String, displayName: String) async throws {
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            
            // Create user document
            try await createUserDocument(user: result.user, displayName: displayName)
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }
    
    private func createUserDocument(user: User, displayName: String) async throws {
        let userDoc = UserDocument(
            email: user.email ?? "",
            displayName: displayName,
            role: "user",
            createdAt: Date(),
            updatedAt: Date(),
            settings: .default,
            aiQuotas: .free,
            subscription: nil
        )
        
        try await db.collection("users").document(user.uid).setData(from: userDoc)
    }
    
    func signOut() {
        // 1. Sign out Firebase first (stop listeners using cache)
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        // 2. Wipe local SwiftData expenses (per-user data, must not leak)
        do {
            let context = SwiftDataService.shared.context
            try context.delete(model: ExpenseModel.self)
            try context.save()
        } catch {
            logger.error("signOut: failed wiping SwiftData: \(error.localizedDescription)")
        }

        // 3. Wipe Firestore persistent cache (otherwise other user reads stale docs)
        Firestore.firestore().clearPersistence { error in
            if let error = error {
                Logger(subsystem: "com.idanidev.clarity", category: "AuthViewModel")
                    .error("signOut: clearPersistence failed: \(error.localizedDescription)")
            }
        }

        // 4. Reset in-memory user state
        UserDataManager.shared.clearCache()
        UserDataManager.shared.expenses = []
        UserDataManager.shared.userDocument = nil
        userDocument = nil
        currentUser = nil

        // 5. Limpiar widget (sin esto seguía mostrando totales del usuario anterior)
        WidgetDataManager.shared.clearWidgetData()
    }
    
    func updateDisplayName(_ newName: String) async throws {
        guard let user = Auth.auth().currentUser else { return }

        // 1. Update Firebase Auth profile
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = newName
        try await changeRequest.commitChanges()

        // 2. Update Firestore user document
        try await db.collection("users").document(user.uid)
            .updateData(["displayName": newName, "updatedAt": FieldValue.serverTimestamp()])

        // 3. Update local state
        userDocument?.displayName = newName
        if let doc = userDocument {
            UserDataManager.shared.setUserDocument(doc)
        }
    }

    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    /// Elimina permanentemente la cuenta del usuario: Firestore data + Firebase Auth account.
    /// Requerido por App Store Review Guidelines 5.1.1(v).
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let db = Firestore.firestore()

        // 1. Borrar subcolecciones reales del usuario (path: users/{uid}/<sub>).
        // Tolera fallos por reglas: si alguna subcolección no es listable, sigue.
        let userRef = db.collection("users").document(userId)
        for sub in ["expenses", "monthlyBudgets", "monthly_budgets", "recurringExpenses", "goals", "categories", "backups", "theme"] {
            do {
                let snap = try await userRef.collection(sub).getDocuments()
                for doc in snap.documents {
                    try? await doc.reference.delete()
                }
            } catch {
                logger.warning("deleteAccount: skip \(sub) — \(error.localizedDescription)")
            }
        }

        // 2. Borrar documento principal (categorías viven aquí como map field)
        try? await userRef.delete()

        // 3. Limpiar cache local
        UserDataManager.shared.clearCache()

        // 4. Borrar cuenta de Firebase Auth (requiere sesión reciente; si falla pide re-login)
        try await user.delete()
    }
    
    /// Prepare nonce before starting Apple Sign-In flow.
    /// Call this and set the hashed nonce on the ASAuthorizationAppleIDRequest.
    func prepareAppleSignIn() -> String {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        return Self.sha256(nonce)
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        errorMessage = nil

        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            errorMessage = "Error obteniendo token de Apple"
            throw NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Token not available"])
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: currentNonce,
            fullName: credential.fullName
        )
        
        do {
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            
            // Check if this is a new user
            let isNewUser = result.additionalUserInfo?.isNewUser ?? false
            
            if isNewUser {
                // Get display name from Apple (only available on first sign in)
                var displayName = ""
                if let fullName = credential.fullName {
                    let givenName = fullName.givenName ?? ""
                    let familyName = fullName.familyName ?? ""
                    displayName = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
                }
                
                if displayName.isEmpty {
                    displayName = result.user.email?.components(separatedBy: "@").first ?? "Usuario"
                }
                
                // Update display name
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try? await changeRequest.commitChanges()
                
                // Create user document
                try await createUserDocument(user: result.user, displayName: displayName)
            }
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }
    
    // MARK: - Google Sign-In

    func signInWithGoogle() async throws {
        errorMessage = nil

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Configuración de Google no disponible"
            throw NSError(domain: "GoogleSignIn", code: -1)
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let rootVC = Self.topViewController() else {
            errorMessage = "No se pudo presentar Google Sign-In"
            throw NSError(domain: "GoogleSignIn", code: -2)
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Token de Google no disponible"
                throw NSError(domain: "GoogleSignIn", code: -3)
            }
            let accessToken = result.user.accessToken.tokenString

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            let isNewUser = authResult.additionalUserInfo?.isNewUser ?? false

            if isNewUser {
                let profile = result.user.profile
                var displayName = profile?.name ?? ""
                if displayName.isEmpty {
                    displayName = authResult.user.email?.components(separatedBy: "@").first ?? "Usuario"
                }
                let changeRequest = authResult.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try? await changeRequest.commitChanges()
                try await createUserDocument(user: authResult.user, displayName: displayName)
            }
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }

    private static func topViewController(_ base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
        if let nav = root as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(presented)
        }
        return root
    }

    private func mapAuthError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue,
             AuthErrorCode.invalidCredential.rawValue:
            return "Email o contraseña incorrectos"
        case AuthErrorCode.invalidEmail.rawValue:
            return "Email no válido"
        case AuthErrorCode.userNotFound.rawValue:
            return "Esta cuenta no existe"
        case AuthErrorCode.userDisabled.rawValue:
            return "Esta cuenta está deshabilitada"
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "Este email ya está registrado"
        case AuthErrorCode.weakPassword.rawValue:
            return "La contraseña debe tener al menos 6 caracteres"
        case AuthErrorCode.networkError.rawValue:
            return "Sin conexión. Comprueba tu internet."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Demasiados intentos. Espera unos minutos."
        case AuthErrorCode.requiresRecentLogin.rawValue:
            return "Por seguridad, vuelve a iniciar sesión"
        case AuthErrorCode.operationNotAllowed.rawValue:
            return "Este método de inicio de sesión no está disponible"
        case AuthErrorCode.accountExistsWithDifferentCredential.rawValue:
            return "Ya existe una cuenta con este email usando otro método (prueba con Google/Apple)"
        case AuthErrorCode.credentialAlreadyInUse.rawValue:
            return "Esta credencial ya está vinculada a otra cuenta"
        case AuthErrorCode.userTokenExpired.rawValue:
            return "Sesión caducada. Vuelve a iniciar sesión."
        case AuthErrorCode.webContextCancelled.rawValue,
             AuthErrorCode.webContextAlreadyPresented.rawValue:
            return "Inicio de sesión cancelado"
        default:
            // Fallback genérico en español (evita mensajes Firebase en inglés)
            return "No se ha podido completar la operación. Inténtalo de nuevo."
        }
    }

    // MARK: - Nonce Helpers

    private static func randomNonceString(length: Int = 32) -> String {
        guard length > 0 else { return "" }
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
