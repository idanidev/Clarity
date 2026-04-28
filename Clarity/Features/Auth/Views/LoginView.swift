// LoginView.swift
// Login screen — rediseño glassmorphism 2026

import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showRegister = false
    @State private var showForgotPassword = false
    @State private var showPassword = false

    // Animaciones de entrada
    @State private var headerVisible = false
    @State private var formVisible = false
    @State private var actionsVisible = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Fondo: OLED + glow violeta sutil arriba
                Color.bgPrimary.ignoresSafeArea()

                RadialGradient(
                    colors: [Color.clarityPrimary.opacity(0.18), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 420
                )
                .ignoresSafeArea()

                GeometryReader { geo in
                    VStack(spacing: 0) {

                        // MARK: — Cabecera
                        VStack(spacing: Spacing.sm) {
                            Image("HomeIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 88, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: Color.clarityPrimary.opacity(0.55), radius: 28, y: 10)

                            Text("Clarity")
                                .font(.clarityLargeTitle)
                                .foregroundStyle(Color.clarityGradient)

                            Text("Gestión inteligente de gastos")
                                .font(.claritySubheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, geo.safeAreaInsets.top + Spacing.lg)
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : -16)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: headerVisible)

                        Spacer(minLength: Spacing.xl)

                        // MARK: — Formulario glass
                        VStack(spacing: Spacing.sm) {
                            AuthTextField(
                                icon: "envelope",
                                placeholder: "tu@email.com",
                                text: $email,
                                contentType: .emailAddress,
                                keyboardType: .emailAddress
                            )

                            AuthTextField(
                                icon: "lock",
                                placeholder: "Contraseña",
                                text: $password,
                                contentType: .password,
                                isSecure: true,
                                showPassword: $showPassword
                            )

                            HStack {
                                Spacer()
                                Button("¿Olvidaste tu contraseña?") {
                                    showForgotPassword = true
                                }
                                .font(.clarityCaption)
                                .foregroundStyle(Color.clarityPrimary)
                            }
                            .padding(.horizontal, Spacing.xs)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .opacity(formVisible ? 1 : 0)
                        .offset(y: formVisible ? 0 : 12)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: formVisible)

                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .font(.clarityCaption)
                                .foregroundStyle(Color.error)
                                .padding(.horizontal, Spacing.lg)
                                .padding(.top, Spacing.xs)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Spacer(minLength: Spacing.lg)

                        // MARK: — Botones de acción
                        VStack(spacing: Spacing.sm) {
                            Button(action: login) {
                                Group {
                                    if isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Iniciar sesión con email")
                                            .font(.clarityHeadline)
                                    }
                                }
                            }
                            .buttonStyle(.clarityProminent)
                            .disabled(!isValidForm || isLoading)

                            HStack(spacing: Spacing.sm) {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(Color.white.opacity(0.08))
                                Text("o continúa con")
                                    .font(.clarityCaption)
                                    .foregroundStyle(.tertiary)
                                    .fixedSize()
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(Color.white.opacity(0.08))
                            }

                            // Apple primero
                            SignInWithAppleButton(.signIn) { request in
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = authViewModel.prepareAppleSignIn()
                            } onCompletion: { result in
                                handleAppleSignIn(result)
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: Spacing.buttonHeight)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))

                            // Google después
                            Button {
                                Task {
                                    do {
                                        try await authViewModel.signInWithGoogle()
                                    } catch {}
                                }
                            } label: {
                                HStack(spacing: Spacing.xs) {
                                    GoogleIcon()
                                        .frame(width: 18, height: 18)
                                    Text("Continuar con Google")
                                        .font(.clarityHeadline)
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: Spacing.buttonHeight)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                        .padding(.horizontal, Spacing.lg)
                        .opacity(actionsVisible ? 1 : 0)
                        .offset(y: actionsVisible ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: actionsVisible)

                        Spacer(minLength: Spacing.md)

                        HStack(spacing: Spacing.xxs) {
                            Text("¿No tienes cuenta?")
                                .foregroundStyle(.secondary)
                            Button("Regístrate") {
                                showRegister = true
                            }
                            .foregroundStyle(Color.clarityPrimary)
                            .fontWeight(.semibold)
                        }
                        .font(.claritySubheadline)
                        .opacity(actionsVisible ? 1 : 0)
                        .animation(.easeIn(duration: 0.3).delay(0.4), value: actionsVisible)
                        .padding(.bottom, Spacing.lg)
                    }
                    .frame(width: geo.size.width)
                }
            }
            .onAppear {
                headerVisible = true
                formVisible = true
                actionsVisible = true
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
            .alert("Recuperar contraseña", isPresented: $showForgotPassword) {
                TextField("Email", text: $email)
                Button("Enviar") {
                    Task {
                        do {
                            try await authViewModel.resetPassword(email: email)
                            FeedbackManager.shared.show(.success, title: "Email enviado", message: "Revisa tu bandeja de entrada")
                        } catch {
                            FeedbackManager.shared.show(.error, title: "Error", message: error.safeUserMessage)
                        }
                    }
                }
                Button("Cancelar", role: .cancel) {}
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
            } catch {}
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
                    } catch {}
                    isLoading = false
                }
            }
        case .failure:
            isLoading = false
        }
    }
}

// MARK: — Campo glass con icono leading
private struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    @Binding var showPassword: Bool

    init(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType? = nil,
        keyboardType: UIKeyboardType = .default,
        isSecure: Bool = false,
        showPassword: Binding<Bool> = .constant(false)
    ) {
        self.icon = icon
        self.placeholder = placeholder
        self._text = text
        self.contentType = contentType
        self.keyboardType = keyboardType
        self.isSecure = isSecure
        self._showPassword = showPassword
    }

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: IconSize.medium, weight: .medium))
                .foregroundStyle(focused ? Color.clarityPrimary : Color.textTertiary)
                .frame(width: 20)
                .animation(.easeInOut(duration: AnimationDuration.fast), value: focused)

            Group {
                if isSecure && !showPassword {
                    SecureField(placeholder, text: $text)
                        .textContentType(contentType)
                } else {
                    TextField(placeholder, text: $text)
                        .textContentType(contentType)
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            .focused($focused)
            .font(.clarityBody)

            if isSecure {
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: IconSize.small, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: Spacing.buttonHeight)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.inputRadius)
                .stroke(
                    focused ? Color.clarityPrimary.opacity(0.6) : Color.white.opacity(0.08),
                    lineWidth: focused ? 1.5 : 1
                )
                .animation(.easeInOut(duration: AnimationDuration.fast), value: focused)
        )
    }
}

// MARK: — Icono Google "G" en círculo blanco
private struct GoogleIcon: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.white)
            Text("G")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "#4285F4"),
                            Color(hex: "#34A853"),
                            Color(hex: "#FBBC05"),
                            Color(hex: "#EA4335"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}
