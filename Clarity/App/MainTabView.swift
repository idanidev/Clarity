// MainTabView.swift
// Main tab navigation with native iOS TabView and center add button

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showAddExpense = false
    @ObservedObject private var userDataManager = UserDataManager.shared
    @StateObject private var dashboardViewModel = DashboardViewModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Native TabView with 5 tabs (center one is dummy for spacing)
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Image(systemName: "tablecells")
                        Text("Tabla")
                    }
                    .tag(0)
                
                ChartsView()
                    .tabItem {
                        Image(systemName: "chart.pie.fill")
                        Text("Gráfico")
                    }
                    .tag(1)
                
                // Dummy center tab (hidden by the floating button)
                Color.clear
                    .tabItem {
                        Text(" ")
                    }
                    .tag(2)
                
                AIAssistantView()
                    .tabItem {
                        Image(systemName: "sparkles")
                        Text("Asistente")
                    }
                    .tag(3)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("Ajustes")
                    }
                    .tag(4)
            }
            .tint(Color.clarityPrimary)
            
            // Floating center "+" button (over the center tab)
            Button {
                showAddExpense = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.brandGradient)
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.clarityPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -8)
            
            // New Voice Expense Button (bottom right)
            VoiceExpenseButton(
                viewModel: dashboardViewModel,
                categories: userDataManager.categories
            )
            .padding(.trailing, 20)
            .padding(.bottom, 100)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet {
                // Refresh after adding
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Intercept center tab selection and show add sheet instead
            if newValue == 2 {
                selectedTab = oldValue
                showAddExpense = true
            }
        }
        .task {
            await userDataManager.loadUserData()
        }
        .preferredColorScheme(.dark)
    }
}


#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}

