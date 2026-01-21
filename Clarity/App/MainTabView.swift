// MainTabView.swift
// Main tab navigation with native iOS TabView and radial menu

import SwiftUI
import TipKit

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showManualExpense = false
    @State private var showRecurring = false
    private var userDataManager = UserDataManager.shared
    @State private var homeViewModel = DependencyContainer.shared.makeHomeViewModel()

    // Centralized managers
    @State private var coordinator = AppCoordinator()
    @State private var feedbackManager = FeedbackManager.shared

    // Voice components
    @State private var speechManager = SpeechRecognitionManager()
    @State private var voiceCoordinator = VoiceExpenseCoordinator()
    
    init() {
        // Configure Glassmorphic Tab Bar
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        
        // Item appearance
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.5)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
        
        itemAppearance.selected.iconColor = UIColor(Color.clarityPrimary)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.clarityPrimary)]
        
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        ZStack {
            // TabView
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView(viewModel: homeViewModel)
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
                
                // Espacio para botón central
                Color.clear
                    .tabItem {
                        Image(systemName: "plus")
                        Text("Añadir")
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
        // Sheets and alerts
        // Sheets and alerts
        // VoiceRecordingSheet removed (inline UI)
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
                                viewModel: homeViewModel
                            )
                            UserDataManager.shared.completeOnboarding()
                        }
                    },
                    onCancel: {
                        voiceCoordinator.reset()
                    }
                )
            }
        }
        .sheet(isPresented: $showManualExpense) {
            AddExpenseSheet {
                Task { await homeViewModel.refresh() }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(CornerRadius.large)
        }
        .sheet(isPresented: $showRecurring) {
            NavigationStack {
                RecurringExpensesView()
            }
            .presentationDetents([.large])
            .presentationBackground(.regularMaterial)
        }
        .alert("Error de Voz", isPresented: $voiceCoordinator.showError) {
            Button("OK", role: .cancel) {
                voiceCoordinator.clearError()
            }
        } message: {
            Text(voiceCoordinator.errorMessage ?? "Error desconocido")
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                selectedTab = oldValue
                showManualExpense = true
            } else {
                previousTab = newValue
            }
        }
        .overlay(alignment: .top) {
            if voiceCoordinator.showSuccessToast {
                SuccessToast(message: voiceCoordinator.successMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if let message = feedbackManager.currentMessage {
                FeedbackOverlay(message: message) {
                    feedbackManager.dismiss()
                }
            }
        }
        .task {
            await userDataManager.loadUserData()
        }
        .onOpenURL { url in
            if url.scheme == "clarity" && url.host == "add-expense" {
                // Parse optional input parameter
                var inputPhrase: String?
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                   let queryItems = components.queryItems {
                    inputPhrase = queryItems.first(where: { $0.name == "input" })?.value
                }
                
                // Small delay to ensure clean state transition if coming from background
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let phrase = inputPhrase, !phrase.isEmpty {
                        // Use the existing voice logic to parse the text
                        voiceCoordinator.handleTranscript(phrase, categories: userDataManager.categories)
                    } else {
                        // Fallback to manual entry
                        showManualExpense = true
                    }
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthViewModel())
}
