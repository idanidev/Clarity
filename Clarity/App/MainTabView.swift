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
            // 5 tabs: Gastos | Metas | [+] | IA | Ajustes
            TabView(selection: $selectedTab) {
                NavigationStack {
                    ExpensesView()
                }
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Gastos")
                }
                .tag(0)
                
                NavigationStack {
                    BudgetsView()
                }
                .tabItem {
                    Image(systemName: "target")
                    Text("Metas")
                }
                .tag(1)
                
                // Center add button (inline with tab bar)
                Color.clear
                    .tabItem {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                    }
                    .tag(2)
                
                NavigationStack {
                    AIAssistantView()
                }
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("IA")
                }
                .tag(3)
                
                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Ajustes")
                }
                .tag(4)
            }
            .tint(Color.clarityPrimary)
            
            // Voice Expense Button (bottom right)
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
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.regularMaterial)  // Liquid Glass
            .presentationCornerRadius(CornerRadius.large)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Intercept add button tap
            if newValue == 2 {
                selectedTab = oldValue
                showAddExpense = true
            }
        }
        .task {
            await userDataManager.loadUserData()
        }
        }
    }
}


#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}

