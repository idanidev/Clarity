// LoginView.swift
// Login screen

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showRegister = false
    @State private var showForgotPassword = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Logo & Title
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 90))
                            .foregroundStyle(Color.clarityGradient)
                        
                        Text("Clarity")
                            .font(.clarityLargeTitle)
                            .foregroundStyle(Color.clarityGradient)
                        
                        Text("Gestión inteligente de gastos")
                            .font(.claritySubheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, Spacing.xxl)
                    
                    // Form
                    VStack(spacing: Spacing.md) {
                        // Email
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Email")
                                .font(.clarityCaption)
                                .foregroundStyle(.secondary)
                            
                            TextField("tu@email.com", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        
                        // Password
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Contraseña")
                                .font(.clarityCaption)
                                .foregroundStyle(.secondary)
                            
                            SecureField("••••••••", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.password)
                        }
                        
                        // Forgot Password
                        HStack {
                            Spacer()
                            Button("¿Olvidaste tu contraseña?") {
                                showForgotPassword = true
                            }
                            .font(.clarityCaption)
                            .foregroundStyle(Color.clarityPrimary)

                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    
                    // Error Message
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.clarityCaption)
                            .foregroundStyle(Color.error)
                            .padding(.horizontal)
                    }
                    
                    // Login Button
                    VStack(spacing: Spacing.md) {
                        Button(action: {
                            login()
                        }) {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Iniciar Sesión")
                            }
                        }
                        .buttonStyle(.clarityProminent)
                        .disabled(!isValidForm || isLoading)
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(.secondary.opacity(0.3))
                            Text("o")
                                .font(.clarityCaption)
                                .foregroundStyle(.secondary)
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(.secondary.opacity(0.3))
                        }
                        
                        // Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: Spacing.buttonHeight)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                        
                        // Google Sign In (placeholder)
                        Button {
                            // Google Sign In requires additional setup
                        } label: {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                Text("Continuar con Google")
                            }
                            .font(.clarityHeadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: Spacing.buttonHeight)
                            .background(Color.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    
                    // Register Link
                    HStack {
                        Text("¿No tienes cuenta?")
                            .foregroundStyle(.secondary)
                        Button("Regístrate") {
                            showRegister = true
                        }
                        .foregroundStyle(Color.clarityPrimary)
                        .fontWeight(.semibold)
                    }
                    .font(.claritySubheadline)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
            .alert("Recuperar Contraseña", isPresented: $showForgotPassword) {
                TextField("Email", text: $email)
                Button("Enviar") {
                    Task {
                        try? await authViewModel.resetPassword(email: email)
                    }
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Introduce tu email para recibir un enlace de recuperación")
            }
        }
    }
    
    private var isValidForm: Bool {
        !email.isEmpty && !password.isEmpty && password.count >= 6
    }
    
    private func login() {
        isLoading = true
        Task {
            do {
                try await authViewModel.signIn(email: email, password: password)
            } catch {
                // Error handled in ViewModel
            }
            isLoading = false
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        isLoading = true
        
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    do {
                        try await authViewModel.signInWithApple(credential: appleIDCredential)
                    } catch {
                        // Error handled in ViewModel
                    }
                    isLoading = false
                }
            }
        case .failure(let error):
            print("❌ Apple Sign In error: \(error.localizedDescription)")
            isLoading = false
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}
