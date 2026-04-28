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
                    Text("Usa \(lockManager.biometryTypeName) para continuar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

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
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .onAppear {
            Task { await lockManager.unlock() }
        }
    }
}
