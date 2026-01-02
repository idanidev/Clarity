// AuthViewModel.swift
// Authentication state management

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var currentUser: User?
    @Published var userDocument: UserDocument?
    @Published var errorMessage: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
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
            uid: user.uid,
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
