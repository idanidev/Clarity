// AuthViewModel.swift
// Authentication state management

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
import AuthenticationServices
import Observation

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading = true
    var currentUser: User?
    var userDocument: UserDocument?
    var errorMessage: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
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
                    await self?.fetchUserDocument(userId: user.uid)
                    // Load and cache user data (categories, etc.)
                    if let doc = self?.userDocument {
                        UserDataManager.shared.setUserDocument(doc)
                    }
                    await UserDataManager.shared.loadUserData()
                }
                
                self?.isLoading = false
            }
        }
    }
    
    private func fetchUserDocument(userId: String) async {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if document.exists {
                userDocument = try document.data(as: UserDocument.self)
            }
        } catch {
            print("Error fetching user document: \(error)")
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
        
        try db.collection("users").document(user.uid).setData(from: userDoc)
    }
    
    func signOut() {
        do {
            // Clear cached user data
            UserDataManager.shared.clearCache()
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
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
            rawNonce: nil,
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
    
    private func mapAuthError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            return "Contraseña incorrecta"
        case AuthErrorCode.invalidEmail.rawValue:
            return "Email inválido"
        case AuthErrorCode.userNotFound.rawValue:
            return "Usuario no encontrado"
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "Este email ya está registrado"
        case AuthErrorCode.weakPassword.rawValue:
            return "La contraseña es muy débil"
        case AuthErrorCode.networkError.rawValue:
            return "Error de conexión. Comprueba tu internet"
        default:
            return error.localizedDescription
        }
    }
}
