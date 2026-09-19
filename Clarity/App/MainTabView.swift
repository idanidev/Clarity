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
    /// Toques por pestaña: cada uno hace rebotar su icono.
    @State private var toquesPestana: [Int: Int] = [:]
    /// El formulario de añadir crece desde el "+" (solo hasta iOS 26: ver `transicionZoomDeHoja`).
    @Namespace private var zoomBarra
    /// Lo que ocupa la barra flotante. Cada pestaña deja ese hueco al final y el
    /// carrusel de la Home, que llega hasta el borde, lo lee del entorno.
    @State private var medidaBarra = MedidaBarraInferior(alto: 66, margenInferior: 34)
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
        // La barra de pestañas del diseño —píldora de vidrio con los cuatro
        // iconos y el micro al lado— flota encima de las pestañas. Antes iba en
        // su propia franja debajo del TabView y el contenido se cortaba en seco
        // contra ella. Ahora cada pestaña deja su hueco como área segura desde
        // dentro —puesto por fuera del TabView, iOS 26 no lo respetaba— y lo que
        // pasa por debajo se funde con el velo.
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView(viewModel: homeViewModel, abrirPestana: { selectedTab = $0 })
                }
                .huecoBarraInferior(medidaBarra.alto)
                .toolbar(.hidden, for: .tabBar)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Gastos")
                }
                .tag(0)

                NavigationStack {
                    FinancialDashboardView()
                }
                .huecoBarraInferior(medidaBarra.alto)
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
                .huecoBarraInferior(medidaBarra.alto)
                .toolbar(.hidden, for: .tabBar)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Ajustes")
                }
                .tag(3)
            }
            .tint(Color.clarityPrimary)
            .modifier(iPadTabViewModifier())

            VeloBarraInferior(alto: medidaBarra.total + 30)

            barraInferior
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    medidaBarra.alto = $0
                    // Agrupadas: si esto entra en bucle, una sola miga con el
                    // recuento en vez de llenar el rastro.
                    Migas.deja("barra: alto=\(Int($0))", agrupando: "barra.alto")
                }
        }
        // El área segura de abajo, medida desde algo que llega hasta el borde.
        // Solo el margen del dispositivo (0 o 34): cuando una hoja saca el
        // teclado, aquí llega su alto (318, 345…) y meterlo en `medidaBarra`
        // recolocaba las cuatro pestañas de debajo en plena presentación.
        .background {
            Color.clear
                .ignoresSafeArea()
                .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: {
                    // La miga, antes del filtro: interesa también lo descartado.
                    Migas.deja("barra: margen=\(Int($0))\($0 < 100 ? "" : " (descartado)")", agrupando: "barra.margen")
                    guard $0 < 100 else { return }
                    medidaBarra.margenInferior = $0
                }
        }
        // Detrás de todo, la aurora: el vidrio de la píldora necesita algo que
        // refractar también en las pestañas con fondo propio.
        .background(HomeFondo())
        .environment(\.medidaBarraInferior, medidaBarra)
        // Sheets and alerts
        .sheet(isPresented: $showManualExpense) {
            // Con un dictado al que le faltó el importe, la descripción llega
            // puesta. Se lee del coordinador (una referencia) y no de un `@State`
            // de aquí: el contenido de una hoja `isPresented` puede quedarse con
            // el valor que tenía el estado antes de presentarse.
            AddExpenseSheet(descripcionInicial: voiceCoordinator.borradorManual ?? "") {
                Task { await homeViewModel.refresh() }
                NotificationCenter.default.post(name: .expenseDidChange, object: nil)
                NotificationsView.cancelInactivityReminder()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(CornerRadius.large)
            // Con zoom en iOS 18–26 y hoja normal en iOS 27+: cada versión con
            // lo que funciona en ella. Ver `transicionZoomDeHoja`.
            .transicionZoomDeHoja(id: "pestana-2", en: zoomBarra)
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
        // Registro de cuelgues: la hoja se abre desde el "+", el widget y una URL.
        .onChange(of: showManualExpense) { _, abierta in
            Migas.deja(abierta ? "hoja añadir: se presenta" : "hoja añadir: se cierra")
            // El borrador dictado vale para una hoja: la siguiente abre en blanco.
            if !abierta { voiceCoordinator.descartarBorradorManual() }
        }
        // Dictado con frase pero sin importe (Siri o el micro de la barra): al
        // formulario manual con la descripción puesta, en vez de un alert que
        // tiraba la frase.
        .onChange(of: voiceCoordinator.borradorManual) { _, borrador in
            guard borrador != nil else { return }
            // Con el formulario ya abierto no se pisa lo que se esté escribiendo.
            guard !showManualExpense else {
                voiceCoordinator.descartarBorradorManual()
                return
            }
            Task { @MainActor in
                await cerrarHojasAbiertas()
                showManualExpense = true
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
                    categoryIsGuess: voiceCoordinator.categoryIsGuess,
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
                    await prepararConfirmacionDeFuera()
                    voiceCoordinator.populateFromApplePay(merchant: merchant, amount: amount)
                } else if let phrase = inputPhrase, !phrase.isEmpty {
                    await prepararConfirmacionDeFuera()
                    // Solo Siri y los Atajos abren la app con `input`: el micro
                    // de dentro llama al coordinator directamente.
                    voiceCoordinator.marcarOrigenSiri()
                    voiceCoordinator.handleTranscript(phrase, categories: userDataManager.categories)
                } else {
                    abrirFormularioSiNoHayNadaAbierto()
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
            .glassCard(cornerRadius: 30, interactivo: true)
            .frame(maxWidth: .infinity)

            SimpleVoiceButton(
                viewModel: homeViewModel,
                categories: UserDataManager.shared.categories,
                disparoGrabar: arrancarVoz,
                // Mismo destino que una frase de Siri sin importe: el formulario.
                alFaltarImporte: { voiceCoordinator.proponerBorradorManual(desde: $0) }
            )
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.xxs)
    }

    private func pestana(_ tag: Int, _ icono: String, _ nombre: String) -> some View {
        let activa = selectedTab == tag
        return Button {
            if tag == 2 { Migas.deja("barra: pulsa +") }
            selectedTab = tag  // la 2 la intercepta el onChange y abre el formulario
            toquesPestana[tag, default: 0] += 1
            HapticManager.shared.selection()
        } label: {
            Image(systemName: icono)
                .font(.system(size: 20, weight: activa ? .semibold : .regular))
                .foregroundStyle(activa ? Color.clarityPrimary : Color.textSecondary)
                // Rebota al tocarlo, como los iconos del sistema.
                .symbolEffect(.bounce, value: toquesPestana[tag, default: 0])
                // El "+" gira a una "x" mientras el formulario está abierto.
                .rotationEffect(.degrees(tag == 2 && showManualExpense ? 45 : 0))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background {
                    if activa {
                        Capsule().fill(Color.clarityPrimary.opacity(0.18))
                    }
                }
                .contentShape(Rectangle())
                .origenZoom(id: "pestana-\(tag)", en: zoomBarra)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nombre)
        .accessibilityAddTraits(activa ? .isSelected : [])
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: showManualExpense)
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
                // Con una hoja delante el micro arrancaba detrás, grabando a
                // ciegas. Quien pulsa «Dictar gasto» quiere dictar: se cierra lo
                // que hubiera y luego se arranca.
                await cerrarHojasAbiertas()
                selectedTab = 0
                arrancarVoz += 1
            }
            return
        }
        guard defaults.bool(forKey: "widget_open_add_expense") else { return }
        defaults.removeObject(forKey: "widget_open_add_expense")
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            abrirFormularioSiNoHayNadaAbierto()
        }
    }
}

// MARK: - Hojas que no se pisan

/// SwiftUI no presenta una hoja mientras otra del mismo nivel sigue en
/// pantalla: la segunda se pierde sin aviso. Lo que llega de fuera (Siri, el
/// widget, el Botón de Acción) no sabe qué hay abierto, así que se decide aquí:
///
/// - Si trae datos (una frase de Siri, un pago) o es una orden de dictar, se
///   cierra lo abierto y se espera a que se vaya. Perder un gasto ya dictado es
///   peor que cerrar un formulario a medias, y quien pide dictar quiere dictar.
/// - Si solo pide abrir el formulario y ya hay algo delante, no se hace nada:
///   la petición no lleva nada que perder y el usuario está con otra cosa.
private extension MainTabView {
    var hayHojaAbierta: Bool {
        if case .confirming = voiceCoordinator.state { return true }
        return showManualExpense || showRecurring || voiceCoordinator.showVoicePaywall
            || voiceCoordinator.showError
    }

    func abrirFormularioSiNoHayNadaAbierto() {
        guard !hayHojaAbierta else { return }
        showManualExpense = true
    }

    /// Cierra las hojas (y el alert de voz) de esta vista y espera lo que tarda
    /// la animación de cierre. Sin nada abierto no espera.
    func cerrarHojasAbiertas() async {
        guard hayHojaAbierta else { return }
        Migas.deja("hojas: se cierran para atender una petición de fuera")
        showManualExpense = false
        showRecurring = false
        voiceCoordinator.showVoicePaywall = false
        voiceCoordinator.clearError()
        if case .confirming = voiceCoordinator.state { voiceCoordinator.reset() }
        // El cierre de una hoja dura ~0,35–0,5 s; presentar antes de que acabe
        // es volver al problema. Tiempo fijo y no `onDismiss`: son cuatro hojas
        // y un alert, y un retardo corto se entiende mejor que cinco avisos.
        try? await Task.sleep(for: .milliseconds(600))
    }

    /// Lo que necesita una confirmación que llega de fuera antes de presentarse:
    /// el sitio libre y las categorías del usuario. En frío, `categories` aún
    /// puede ser la lista de fábrica que el gestor deja en memoria al nacer, y
    /// la frase se resolvería contra categorías que el usuario quizá no tiene.
    func prepararConfirmacionDeFuera() async {
        await cerrarHojasAbiertas()
        await userDataManager.esperarCategoriasDelUsuario()
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
