// RegisterView.swift
// Registration screen

import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Header
                    VStack(spacing: Spacing.sm) {
                        Text("Crear Cuenta")
                            .font(.clarityTitle)
                        
                        Text("Empieza a controlar tus gastos")
                            .font(.claritySubheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, Spacing.lg)
                    
                    // Form
                    VStack(spacing: Spacing.md) {
                        // Name
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Nombre")
                                .font(.clarityCaption)
                                .foregroundStyle(.secondary)
                            
                            TextField("Tu nombre", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                        }
                        
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
                            
                            SecureField("Mínimo 6 caracteres", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.newPassword)
                        }
                        
                        // Confirm Password
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Confirmar Contraseña")
                                .font(.clarityCaption)
                                .foregroundStyle(.secondary)
                            
                            SecureField("Repite la contraseña", text: $confirmPassword)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.newPassword)
                        }
                        
                        // Password match indicator
                        if !confirmPassword.isEmpty && password != confirmPassword {
                            Text("Las contraseñas no coinciden")
                                .font(.clarityCaption)
                                .foregroundStyle(Color.error)
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
                    
                    // Register Button
                    Button(action: {
                        register()
                    }) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Crear Cuenta")
                        }
                    }
                    .buttonStyle(.clarityProminent)
                    .disabled(!isValidForm || isLoading)
                    .padding(.horizontal, Spacing.lg)
                    
                    // Terms
                    Text("Al registrarte aceptas nuestros Términos de Servicio y Política de Privacidad")
                        .font(.clarityCaption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isValidForm: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }
    
    private func register() {
        isLoading = true
        Task {
            do {
                try await authViewModel.signUp(email: email, password: password, displayName: name)
                dismiss()
            } catch {
                // Error handled in ViewModel
            }
            isLoading = false
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthViewModel())
}
