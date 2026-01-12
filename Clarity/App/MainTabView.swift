// MainTabView.swift
// Main tab navigation with native iOS TabView and radial menu

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showRadialMenu = false
    @State private var showManualExpense = false
    @State private var showRecurring = false
    @State private var dragOffset: CGSize = .zero
    @State private var selectedMenuOption: RadialMenuOption? = nil
    @ObservedObject private var userDataManager = UserDataManager.shared
    @StateObject private var homeViewModel = DependencyContainer.shared.makeHomeViewModel()
    
    // Voice components
    @StateObject private var speechManager = SpeechRecognitionManager()
    @StateObject private var voiceCoordinator = VoiceExpenseCoordinator()
    
    init() {
        // Configure OLED Black Tab Bar
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1.0) // HARDCODED PURE BLACK
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.1) // Subtle border
        
        // Ensure strictly black in all modes
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // Menu geometry
    private let menuRadius: CGFloat = 80
    private let angleThreshold: Double = 35
    
    // Menu options enum
    enum RadialMenuOption: CaseIterable {
        case manual, voice, recurring
        
        var icon: String {
            switch self {
            case .manual: "pencil.line"
            case .voice: "mic.fill"
            case .recurring: "arrow.triangle.2.circlepath"
            }
        }
        
        var label: String {
            switch self {
            case .manual: "Manual"
            case .voice: "Voz"
            case .recurring: "Recurrente"
            }
        }
        
        var angle: Double {
            switch self {
            case .manual: -45
            case .voice: 0
            case .recurring: 45
            }
        }
        
        var color: Color {
            switch self {
            case .manual: .blue
            case .voice: .purple
            case .recurring: .orange
            }
        }
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
            
            // Invisible overlay on center tab for long press + drag
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 70, height: 50)
                        .contentShape(Rectangle()) // Ensure hit testing works
                        .gesture(
                            DragGesture(minimumDistance: 15, coordinateSpace: .local)
                                .onChanged { value in
                                    handleCenterTabDrag(value)
                                }
                                .onEnded { value in
                                    handleCenterTabDragEnd(value)
                                }
                        )
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.25)
                                .onEnded { _ in
                                    if !showRadialMenu {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            showRadialMenu = true
                                        }
                                        HapticManager.impact(.medium)
                                    }
                                }
                        )
                        .onTapGesture {
                            if !showRadialMenu {
                                HapticManager.selection()
                                showManualExpense = true
                            }
                        }
                    Spacer()
                }
                .padding(.bottom, 0) // Adjust if needed for safe area
            }
            
            // Radial Menu Overlay
            if showRadialMenu {
                radialMenuOverlay
            }
        }
        // Sheets and alerts
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
            } else {
                previousTab = newValue
            }
        }
        .onChange(of: speechManager.didStopDueToSilence) { _, stopped in
            if stopped && voiceCoordinator.showRecording {
                let fullTranscript = (speechManager.transcript + " " + speechManager.interimTranscript)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                speechManager.stopRecording()
                voiceCoordinator.showRecording = false
                voiceCoordinator.handleTranscript(fullTranscript, categories: userDataManager.categories)
            }
        }
        .overlay(alignment: .top) {
            if voiceCoordinator.showSuccessToast {
                SuccessToast(message: voiceCoordinator.successMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.selection, trigger: selectedMenuOption)
        .task {
            await userDataManager.loadUserData()
        }
        .onOpenURL { url in
            if url.scheme == "clarity" && url.host == "add-expense" {
                // Determine if we are in the middle of a transition or if menu is open
                if showRadialMenu {
                    closeMenu()
                }
                
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
    
    // MARK: - Radial Menu Overlay
    private var radialMenuOverlay: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    closeMenu()
                }
            
            // Menu positioned above tab bar
            VStack {
                Spacer()
                
                ZStack {
                    // Options
                    ForEach(RadialMenuOption.allCases, id: \.self) { option in
                        menuOptionView(option)
                            .offset(
                                x: sin(option.angle * .pi / 180) * menuRadius,
                                y: -cos(option.angle * .pi / 180) * menuRadius
                            )
                    }
                    
                    // Center indicator
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.clarityPrimary, Color.claritySecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: Color.clarityPrimary.opacity(0.4), radius: 8, y: 2)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .onTapGesture {
                        closeMenu()
                    }
                }
                .padding(.bottom, 80)
            }
        }
        .transition(.opacity)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: showRadialMenu)
    }
    
    private func menuOptionView(_ option: RadialMenuOption) -> some View {
        Button {
            executeOption(option)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(selectedMenuOption == option ? option.color.gradient : Color(.systemGray5).gradient)
                        .frame(width: 56, height: 56)
                        .shadow(
                            color: selectedMenuOption == option ? option.color.opacity(0.5) : .black.opacity(0.1),
                            radius: selectedMenuOption == option ? 10 : 4,
                            y: 2
                        )
                    
                    Image(systemName: option.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(selectedMenuOption == option ? .white : .primary)
                }
                .scaleEffect(selectedMenuOption == option ? 1.15 : 1.0)
                
                Text(option.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(selectedMenuOption == option ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2), value: selectedMenuOption)
    }
    
    // MARK: - Gesture Handlers
    private func handleCenterTabDrag(_ value: DragGesture.Value) {
        // Open menu on drag start
        if !showRadialMenu {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                showRadialMenu = true
            }
            HapticManager.impact(.medium)
        }
        
        dragOffset = value.translation
        
        // Calculate selection based on drag
        let distance = hypot(value.translation.width, value.translation.height)
        
        if distance < 25 {
            selectedMenuOption = nil
            return
        }
        
        // Y is inverted (negative = up)
        let angle = atan2(value.translation.width, -value.translation.height) * 180 / .pi
        
        if abs(angle - RadialMenuOption.manual.angle) < angleThreshold {
            selectedMenuOption = .manual
        } else if abs(angle - RadialMenuOption.voice.angle) < angleThreshold {
            selectedMenuOption = .voice
        } else if abs(angle - RadialMenuOption.recurring.angle) < angleThreshold {
            selectedMenuOption = .recurring
        } else {
            selectedMenuOption = nil
        }
    }
    
    private func handleCenterTabDragEnd(_ value: DragGesture.Value) {
        if let option = selectedMenuOption {
            executeOption(option)
        } else {
            // If very small movement, treat as tap (open menu only)
            let distance = hypot(value.translation.width, value.translation.height)
            if distance < 10 && !showRadialMenu {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    showRadialMenu = true
                }
                HapticManager.impact(.medium)
            }
        }
        
        dragOffset = .zero
    }
    
    private func executeOption(_ option: RadialMenuOption) {
        HapticManager.notification(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch option {
            case .manual: showManualExpense = true
            case .voice: voiceCoordinator.handleButtonTap(speechManager: speechManager)
            case .recurring: showRecurring = true
            }
            closeMenu()
        }
    }
    
    private func closeMenu() {
        withAnimation(.spring(response: 0.3)) {
            showRadialMenu = false
        }
        selectedMenuOption = nil
        dragOffset = .zero
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
