// RegisterView.swift
// Registration screen

import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) var authViewModel

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
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.top, Spacing.lg)

                    // Form: los campos juntos en una tarjeta de vidrio, como en el login
                    VStack(spacing: Spacing.md) {
                        // Name
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Nombre")
                                .font(.clarityCaption)
                                .foregroundStyle(Color.textSecondary)

                            TextField("Tu nombre", text: $name)
                                .textContentType(.name)
                                .campoRegistro()
                        }

                        // Email
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Email")
                                .font(.clarityCaption)
                                .foregroundStyle(Color.textSecondary)

                            TextField("tu@email.com", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .campoRegistro()
                        }

                        // Password
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Contraseña")
                                .font(.clarityCaption)
                                .foregroundStyle(Color.textSecondary)

                            SecureField("Mínimo 6 caracteres", text: $password)
                                .textContentType(.newPassword)
                                .campoRegistro()
                        }

                        // Confirm Password
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Confirmar Contraseña")
                                .font(.clarityCaption)
                                .foregroundStyle(Color.textSecondary)

                            SecureField("Repite la contraseña", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .campoRegistro()
                        }

                        // Password match indicator
                        if !confirmPassword.isEmpty && password != confirmPassword {
                            Text("Las contraseñas no coinciden")
                                .font(.clarityCaption)
                                .foregroundStyle(Color.error)
                        }
                    }
                    .padding(Spacing.md)
                    .glassCard(cornerRadius: CornerRadius.xlarge)
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
                    .buttonStyle(.principalClarity)
                    .disabled(!isValidForm || isLoading)
                    .padding(.horizontal, Spacing.lg)

                    // Terms
                    Text("Al registrarte aceptas nuestros Términos de Servicio y Política de Privacidad")
                        .font(.clarityCaption)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                }
            }
            .fondoClarity()
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

private extension View {
    /// Campo sobre la tarjeta de vidrio: un velo suave en vez del borde
    /// redondeado del sistema, que encima del vidrio parecía una caja opaca.
    /// El mismo aspecto que los campos del login.
    func campoRegistro() -> some View {
        textFieldStyle(.plain)
            .padding(.horizontal, Spacing.sm)
            .frame(height: Spacing.buttonHeight)
            .background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
            )
    }
}

#Preview {
    RegisterView()
        .environment(AuthViewModel())
}
