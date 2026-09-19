// LockScreenView.swift
// Pantalla de bloqueo biométrico que se superpone sobre la app.

import SwiftUI

struct LockScreenView: View {
    let lockManager: AppLockManager

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.clarityPrimary)

                VStack(spacing: 8) {
                    Text("Clarity bloqueada")
                        .font(.title2.bold())
                    Text("Usa \(lockManager.biometryTypeName) o el código del iPhone para continuar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                // Los dos botones y el aviso, juntos: el espaciado de 32 de la
                // columna los dejaría demasiado sueltos.
                VStack(spacing: Spacing.xs) {
                    Button {
                        Task { await lockManager.unlock() }
                    } label: {
                        Label("Desbloquear con \(lockManager.biometryTypeName)",
                              systemImage: lockManager.biometryTypeName == "Face ID" ? "faceid" : "touchid")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.clarityPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // La salida cuando la biometría no sirve: Face ID bloqueado por
                    // intentos, mascarilla, o el iPhone usado desde el Mac.
                    Button("Usar código") {
                        Task { await lockManager.unlockConCodigo() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.clarityPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())

                    // Hueco reservado: que el aviso no mueva los botones al salir.
                    Text(lockManager.mensajeDeFallo ?? " ")
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .top)
                        .accessibilityHidden(lockManager.mensajeDeFallo == nil)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .onAppear {
            Task { await lockManager.unlock() }
        }
        // VoiceOver no mira la pantalla: el fallo se le dice.
        .onChange(of: lockManager.mensajeDeFallo) { _, mensaje in
            if let mensaje {
                AccessibilityNotification.Announcement(mensaje).post()
            }
        }
    }
}
