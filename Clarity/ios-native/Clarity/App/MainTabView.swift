// MainTabView.swift
// Main tab navigation with native iOS TabView and center add button

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showAddExpense = false
    @State private var showVoiceInput = false
    
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
            .offset(y: -26)
            
            // Floating mic button (bottom right, above tab bar)
            FloatingMicButton {
                showVoiceInput = true
            }
            .padding(.trailing, Spacing.md)
            .padding(.bottom, 100)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet {
                // Refresh after adding
            }
        }
        .sheet(isPresented: $showVoiceInput) {
            VoiceInputSheet()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Intercept center tab selection and show add sheet instead
            if newValue == 2 {
                selectedTab = oldValue
                showAddExpense = true
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Voice Input Sheet
struct VoiceInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.clarityPrimary.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color.clarityPrimary)
                }
                
                Text("Dicta tu gasto")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Por ejemplo: \"Café en Starbucks 4 euros\"")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.bgPrimary)
            .navigationTitle("Entrada por Voz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
