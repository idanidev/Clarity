// ContentView.swift
// Root view that handles auth state

import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) var authViewModel
    private let userDataManager = UserDataManager.shared
    /// Sin documento ni caché tras 3 s —sin red en un móvil nuevo—, se decide
    /// igual: onboarding, que es lo que tocaría a un usuario sin nada.
    @State private var esperaAgotada = false

    var body: some View {
        Group {
            if authViewModel.isLoading {
                LoadingView()
            } else if authViewModel.isAuthenticated {
                if userDataManager.hasCompletedOnboarding {
                    MainTabView()
                } else if userDataManager.onboardingResuelto || esperaAgotada {
                    OnboardingView {
                        userDataManager.completeOnboarding()
                    }
                } else {
                    // Aún no se sabe si el onboarding está hecho: mejor un
                    // instante de carga que enseñarlo y quitarlo.
                    LoadingView()
                        .task {
                            try? await Task.sleep(for: .seconds(3))
                            esperaAgotada = true
                        }
                }
            } else {
                LoginView()
            }
        }
        .animation(.bouncy(duration: 0.25), value: authViewModel.isAuthenticated)
        .animation(.bouncy(duration: 0.25), value: userDataManager.hasCompletedOnboarding)
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
}
