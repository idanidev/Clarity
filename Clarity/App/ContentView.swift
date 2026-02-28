// ContentView.swift
// Root view that handles auth state

import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) var authViewModel
    private let userDataManager = UserDataManager.shared

    var body: some View {
        Group {
            if authViewModel.isLoading {
                LoadingView()
            } else if authViewModel.isAuthenticated {
                if userDataManager.hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView {
                        userDataManager.completeOnboarding()
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
