// MainTabView.swift
// Main tab navigation with native iOS TabView and center add button

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showVoiceInput = false
    @State private var showAddOptions = false
    @State private var showManualExpense = false
    @State private var showRecurring = false
    @ObservedObject private var userDataManager = UserDataManager.shared
    @State private var dashboardViewModel = DashboardViewModel()
    
    // Voice components
    @StateObject private var speechManager = SpeechRecognitionManager()
    @StateObject private var voiceCoordinator = VoiceExpenseCoordinator()
    
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
                
                // Center add button (Primary Action = Voice)
                Color.clear
                    .tabItem {
                        Image(systemName: "mic.badge.plus")
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
        }
        // Tab bar button actions handled by onChange
        // Voice Recording Sheet
        .sheet(isPresented: $voiceCoordinator.showRecording) {
            VoiceRecordingSheet(
                speechManager: speechManager,
                onComplete: { transcript in
                    voiceCoordinator.handleTranscript(
                        transcript,
                        categories: userDataManager.categories
                    )
                }
            )
        }
        // Voice Confirmation Sheet
        .sheet(isPresented: $voiceCoordinator.showConfirmation) {
            if let expense = voiceCoordinator.pendingExpense {
                VoiceConfirmationSheet(
                    expense: expense,
                    wasFullyDetected: voiceCoordinator.wasFullyDetected,
                    categories: userDataManager.categories,
                    speechManager: speechManager,
                    onConfirm: { confirmed in
                        Task {
                            await voiceCoordinator.saveExpense(
                                confirmed,
                                viewModel: dashboardViewModel
                            )
                        }
                    },
                    onCancel: {
                        voiceCoordinator.reset()
                    }
                )
            }
        }
        // Manual Expense Sheet
        .sheet(isPresented: $showManualExpense) {
            AddExpenseSheet {
                Task { await dashboardViewModel.refresh() }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(CornerRadius.large)
        }
        // Recurring Expenses Sheet
        .sheet(isPresented: $showRecurring) {
            NavigationStack {
                RecurringExpensesView()
            }
            .presentationDetents([.large])
            .presentationBackground(.regularMaterial)
        }
        // Options Dialog (Long Press on +)
        .confirmationDialog("Añadir gasto", isPresented: $showAddOptions, titleVisibility: .visible) {
            Button("🎤 Añadir con voz") {
                voiceCoordinator.handleButtonTap(speechManager: speechManager)
            }
            Button("✏️ Añadir manualmente") {
                showManualExpense = true
            }
            Button("🔁 Gasto recurrente") {
                showRecurring = true
            }
            Button("Cancelar", role: .cancel) {}
        }
        // Error Alert
        .alert("Error de Voz", isPresented: $voiceCoordinator.showError) {
            Button("OK", role: .cancel) {
                voiceCoordinator.clearError()
            }
        } message: {
            Text(voiceCoordinator.errorMessage ?? "Error desconocido")
        }
        // Handle Tab Change - show options when + is tapped
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                // Revert to previous tab and show options
                selectedTab = oldValue
                showAddOptions = true
                HapticManager.selection()
            } else {
                previousTab = newValue
            }
        }
        // Handle silence detection
        .onChange(of: speechManager.didStopDueToSilence) { _, stopped in
            if stopped && voiceCoordinator.showRecording {
                let fullTranscript = (speechManager.transcript + " " + speechManager.interimTranscript)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                speechManager.stopRecording()
                voiceCoordinator.showRecording = false
                voiceCoordinator.handleTranscript(fullTranscript, categories: userDataManager.categories)
            }
        }
        // Success Toast
        .overlay(alignment: .top) {
            if voiceCoordinator.showSuccessToast {
                SuccessToast(message: voiceCoordinator.successMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task {
            await userDataManager.loadUserData()
        }
    }
}


#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}

