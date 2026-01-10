// MainTabView.swift
// Main tab navigation with integrated radial button - Swift 6 compliant

import SwiftUI

@MainActor
struct MainTabView: View {
    
    // MARK: - State
    @State private var selectedTab: TabType = .expenses
    @State private var coordinator: ExpenseCoordinator
    
    // MARK: - Dependencies
    @StateObject private var speechManager = SpeechRecognitionManager()
    @StateObject private var voiceCoordinator = VoiceExpenseCoordinator()
    @State private var dashboardViewModel = DashboardViewModel()
    @State private var userDataManager = UserDataManager.shared
    
    // MARK: - Init
    init() {
        let speech = SpeechRecognitionManager()
        let voice = VoiceExpenseCoordinator()
        _coordinator = State(initialValue: ExpenseCoordinator(
            speechManager: speech,
            voiceCoordinator: voice
        ))
        _speechManager = StateObject(wrappedValue: speech)
        _voiceCoordinator = StateObject(wrappedValue: voice)
    }
    
    // MARK: - Body
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Expenses
            NavigationStack {
                ExpensesView()
            }
            .tabItem {
                Label(TabType.expenses.title, systemImage: TabType.expenses.icon)
            }
            .tag(TabType.expenses)
            
            // Tab 2: Budgets
            NavigationStack {
                BudgetsView()
            }
            .tabItem {
                Label(TabType.budgets.title, systemImage: TabType.budgets.icon)
            }
            .tag(TabType.budgets)
            
            // Tab 3: CENTER - Add Expense (Radial Button)
            ZStack {
                Color.clear
                EnhancedVoiceButton(
                    onVoiceTap: { Task { await coordinator.handleVoiceInput() } },
                    onManualTap: coordinator.handleManualInput,
                    onRecurringTap: coordinator.handleRecurringInput
                )
            }
            .tabItem {
                Image(systemName: "mic.fill")
            }
            .tag(TabType.addExpense)
            
            // Tab 4: Assistant
            NavigationStack {
                AIAssistantView()
            }
            .tabItem {
                Label(TabType.assistant.title, systemImage: TabType.assistant.icon)
            }
            .tag(TabType.assistant)
            
            // Tab 5: Settings
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(TabType.settings.title, systemImage: TabType.settings.icon)
            }
            .tag(TabType.settings)
        }
        .tint(Color.clarityPrimary)
        .sheet(item: $coordinator.activeSheet) { sheet in
            sheetView(for: sheet)
        }
        .alert("Error de Voz", isPresented: $voiceCoordinator.showError) {
            Button("OK", role: .cancel) {
                voiceCoordinator.clearError()
            }
        } message: {
            Text(voiceCoordinator.errorMessage ?? "Error desconocido")
        }
        .overlay(alignment: .top) {
            if voiceCoordinator.showSuccessToast {
                SuccessToast(message: voiceCoordinator.successMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: speechManager.didStopDueToSilence) { _, stopped in
            handleSilenceDetection(stopped: stopped)
        }
        .task {
            await userDataManager.loadUserData()
        }
    }
    
    // MARK: - Content Builders
    @ViewBuilder
    private func sheetView(for sheet: SheetType) -> some View {
        switch sheet {
        case .voiceRecording:
            VoiceRecordingSheet(
                speechManager: speechManager,
                onComplete: { [weak voiceCoordinator, weak userDataManager] transcript in
                    guard let voiceCoordinator, let userDataManager else { return }
                    voiceCoordinator.handleTranscript(
                        transcript,
                        categories: userDataManager.categories
                    )
                }
            )
            
        case .voiceConfirmation(let expense, let wasFullyDetected):
            VoiceConfirmationSheet(
                expense: expense,
                wasFullyDetected: wasFullyDetected,
                categories: userDataManager.categories,
                speechManager: speechManager,
                onConfirm: { [weak voiceCoordinator, weak dashboardViewModel] confirmed in
                    guard let voiceCoordinator, let dashboardViewModel else { return }
                    Task {
                        await voiceCoordinator.saveExpense(
                            confirmed,
                            viewModel: dashboardViewModel
                        )
                    }
                },
                onCancel: { [weak voiceCoordinator] in
                    voiceCoordinator?.reset()
                }
            )
            
        case .manualExpense:
            AddExpenseSheet { [weak dashboardViewModel] in
                guard let dashboardViewModel else { return }
                Task { await dashboardViewModel.refresh() }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(CornerRadius.large)
            
        case .recurringExpenses:
            NavigationStack {
                RecurringExpensesView()
            }
            .presentationDetents([.large])
            .presentationBackground(.regularMaterial)
        }
    }
    
    // MARK: - Helpers
    
    private func handleSilenceDetection(stopped: Bool) {
        guard stopped, voiceCoordinator.showRecording else { return }
        
        let fullTranscript = (speechManager.transcript + " " + speechManager.interimTranscript)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        speechManager.stopRecording()
        voiceCoordinator.showRecording = false
        voiceCoordinator.handleTranscript(fullTranscript, categories: userDataManager.categories)
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
