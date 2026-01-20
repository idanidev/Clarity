// ContentView.swift
// Root view that handles auth state

import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) var authViewModel

    var body: some View {
        Group {
            if authViewModel.isLoading {
                LoadingView()
            } else if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.bouncy(duration: 0.25), value: authViewModel.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
}
