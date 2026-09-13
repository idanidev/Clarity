// MainTabView.swift
// Main tab navigation with native iOS TabView and radial menu

import SwiftUI
import TipKit

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showManualExpense = false
    /// Sube cuando el control "Dictar gasto" abre la app: el micro arranca solo.
    @State private var arrancarVoz = 0
    @State private var showRecurring = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    private var userDataManager = UserDataManager.shared
    @State private var homeViewModel = DependencyContainer.shared.makeHomeViewModel()

    // Centralized managers
    @State private var coordinator = AppCoordinator()

    // Voice components
    @State private var speechManager = SpeechRecognitionManager.shared
    @State private var voiceCoordinator = VoiceExpenseCoordinator()

    init() {
        // Configure Glassmorphic Tab Bar (adapts to light/dark mode)
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)

        // Item appearance - adapts to color scheme
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.secondaryLabel
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel
        ]

        itemAppearance.selected.iconColor = UIColor(Color.clarityPrimary)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.clarityPrimary)
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack {
            // La barra de pestañas del diseño —píldora de vidrio con los cuatro
            // iconos y el micro al lado— ocupa su sitio debajo del TabView. Se
            // probó como inset del área segura y en iOS 26 el contenido de la
            // pestaña no lo respetaba: pisaba la última fila y los puntos.
            VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView(viewModel: homeViewModel, abrirPestana: { selectedTab = $0 })
                }
                .toolbar(.hidden, for: .tabBar)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Gastos")
                }
                .tag(0)

                NavigationStack {
                    FinancialDashboardView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tabItem {
                    Image(systemName: "target")
                    Text("Metas")
                }
                .tag(1)

                // Espacio para botón central
                Color.clear
                    .toolbar(.hidden, for: .tabBar)
                    .tabItem {
                        Image(systemName: "plus")
                        Text("Añadir")
                    }
                    .tag(2)

                // Aquí vivía la pestaña "IA". Enseñaba un "Próximamente" y
                // nada más: una función anunciada en la barra que al tocarla no
                // hace nada es contenido de relleno, motivo habitual de rechazo
                // en App Review (guideline 2.1), y de paso prometía al usuario
                // algo que la app no tiene. Cuando la IA vuelva, vuelve la
                // pestaña con `AIAdvisorView()`.
                NavigationStack {
                    SettingsView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Ajustes")
                }
                .tag(3)
            }
            .tint(Color.clarityPrimary)
            .modifier(iPadTabViewModifier())

            barraInferior
            }
            // Detrás de todo, la aurora: el vidrio de la píldora necesita algo que
            // refractar también en las pestañas con fondo propio.
            .background(HomeFondo(mes: homeViewModel.selectedMonth))
        }
        // Sheets and alerts
        .sheet(isPresented: $showManualExpense) {
            AddExpenseSheet {
                Task { await homeViewModel.refresh() }
                NotificationCenter.default.post(name: .expenseDidChange, object: nil)
                NotificationsView.cancelInactivityReminder()
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
        .sheet(isPresented: $voiceCoordinator.showVoicePaywall) {
            ProPaywallView(reason: .voiceLimit)
        }
        .alert(
            "Error de Voz",
            isPresented: Binding(
                get: { voiceCoordinator.showError },
                set: { if !$0 { voiceCoordinator.clearError() } }
            )
        ) {
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
        .safeAreaInset(edge: .top, spacing: 0) {
            OfflineBanner()
        }
        .overlay(alignment: .top) {
            if voiceCoordinator.showSuccessToast {
                SuccessToast(message: voiceCoordinator.successMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture {
                        // Tap para cerrar ya y seguir metiendo gastos
                        withAnimation(.snappy) { voiceCoordinator.showSuccessToast = false }
                    }
            }
        }
        .task {
            await userDataManager.loadUserData()

            // Refresh notification content (fixes stale/empty bodies)
            NotificationsView.refreshOnLaunch()

            // Check inactivity — notify if 7+ days without expenses
            let lastExpenseDate = userDataManager.expenses.first?.dateAsDate
            NotificationsView.scheduleInactivityReminderIfNeeded(lastExpenseDate: lastExpenseDate)

            // Run recurring check and backup in parallel — both are independent
            async let recurring = LocalRecurringExpenseManager.shared.checkAndCreatePendingExpenses()
            async let backup = BackupManager.shared.checkAndCreateAutoBackup()
            await recurring
            await backup
        }
        .sheet(
            isPresented: Binding(
                get: {
                    if case .confirming = voiceCoordinator.state { return true }
                    return false
                },
                set: { show in
                    if !show { voiceCoordinator.reset() }
                }
            )
        ) {
            if let expense = voiceCoordinator.pendingExpense {
                VoiceConfirmationSheet(
                    expense: expense,
                    wasFullyDetected: voiceCoordinator.wasFullyDetected,
                    categories: userDataManager.categories,
                    speechManager: speechManager,
                    onConfirm: { confirmed in
                        Task {
                            await voiceCoordinator.saveExpense(confirmed, viewModel: homeViewModel)
                        }
                    },
                    onCancel: {
                        voiceCoordinator.reset()
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(CornerRadius.large)
            }
        }
        // En un arranque en frío desde el control no hay cambio de fase que
        // escuchar: se mira también al aparecer.
        .onAppear { checkWidgetAddExpenseFlag() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkWidgetAddExpenseFlag()
            }
        }
        .onOpenURL { url in
            guard url.scheme == "clarity", url.host == "add-expense",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            else { return }

            let queryItems = components.queryItems ?? []
            let merchant = queryItems.first(where: { $0.name == "merchant" })?.value
            let amountStr = queryItems.first(where: { $0.name == "amount" })?.value
            let inputPhrase = queryItems.first(where: { $0.name == "input" })?.value

            // Small delay to ensure clean state transition if coming from background
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                if let merchant, !merchant.isEmpty,
                   let amountStr, let amount = Double(amountStr) {
                    voiceCoordinator.populateFromApplePay(merchant: merchant, amount: amount)
                } else if let phrase = inputPhrase, !phrase.isEmpty {
                    // Solo Siri y los Atajos abren la app con `input`: el micro
                    // de dentro llama al coordinator directamente.
                    voiceCoordinator.marcarOrigenSiri()
                    voiceCoordinator.handleTranscript(phrase, categories: userDataManager.categories)
                } else {
                    showManualExpense = true
                }
            }
        }
    }
    // MARK: - Barra inferior

    private var barraInferior: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 0) {
                pestana(0, "list.bullet", "Gastos")
                pestana(1, "target", "Metas")
                pestana(2, "plus", "Añadir")
                pestana(3, "gearshape.fill", "Ajustes")
            }
            .padding(5)
            .glassCard(cornerRadius: 30)
            .frame(maxWidth: .infinity)

            SimpleVoiceButton(viewModel: homeViewModel, categories: UserDataManager.shared.categories, disparoGrabar: arrancarVoz)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.xxs)
    }

    private func pestana(_ tag: Int, _ icono: String, _ nombre: String) -> some View {
        let activa = selectedTab == tag
        return Button {
            selectedTab = tag  // la 2 la intercepta el onChange y abre el formulario
            HapticManager.shared.selection()
        } label: {
            Image(systemName: icono)
                .font(.system(size: 20, weight: activa ? .semibold : .regular))
                .foregroundStyle(activa ? Color.clarityPrimary : Color.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background {
                    if activa {
                        Capsule().fill(Color.clarityPrimary.opacity(0.18))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nombre)
        .accessibilityAddTraits(activa ? .isSelected : [])
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
    }
}


// MARK: - Widget Add Expense Flag

private extension MainTabView {
    func checkWidgetAddExpenseFlag() {
        guard let defaults = UserDefaults(suiteName: "group.com.idanidev.clarity") else { return }
        // Control "Dictar gasto" (Centro de Control, pantalla bloqueada, Botón de Acción).
        if defaults.bool(forKey: "widget_start_voice") {
            defaults.removeObject(forKey: "widget_start_voice")
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                selectedTab = 0
                arrancarVoz += 1
            }
            return
        }
        guard defaults.bool(forKey: "widget_open_add_expense") else { return }
        defaults.removeObject(forKey: "widget_open_add_expense")
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            showManualExpense = true
        }
    }
}

// MARK: - iPad Sidebar Adaptation

private struct iPadTabViewModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        if sizeClass == .regular, #available(iOS 18.0, *) {
            content.tabViewStyle(.sidebarAdaptable)
        } else {
            content
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthViewModel())
}
