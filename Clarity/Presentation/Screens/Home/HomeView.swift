// HomeView.swift
// La Home (#65): tres páginas que se pasan deslizando —resumen, gráficas,
// calendario— y ningún cuadro vacío. La barra flotante que había para elegir
// vista se fue: costaba 60 pt fijos sobre los gastos y los puntos de abajo
// dicen lo mismo sin ocupar nada.

import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    private var userDataManager = UserDataManager.shared

    /// Página visible del carrusel.
    @State private var pagina: HomePagina = .resumen
    @State private var expenseToEdit: Expense?
    @State private var showFilterSheet = false
    @State private var showAddExpense = false
    /// El buscador se abre desde la barra y ocupa su fila encima del carrusel:
    /// el `.searchable` nativo se abría encima de la primera tarjeta porque el
    /// carrusel horizontal no le hacía hueco.
    @State private var buscando = false
    @FocusState private var buscadorEnfocado: Bool
    /// Pantalla a la que se navega desde una tarjeta.
    @State private var rutaPush: HomeDestino?
    /// Para saltar a otra pestaña (Metas). Lo pone MainTabView, que es quien las tiene.
    var abrirPestana: (Int) -> Void = { _ in }
    @State private var voiceCoordinator = VoiceExpenseCoordinator()
    @State private var speechManager = SpeechRecognitionManager.shared

    @MainActor
    init(viewModel: HomeViewModel? = nil, abrirPestana: @escaping (Int) -> Void = { _ in }) {
        let vm = viewModel ?? DependencyContainer.shared.makeHomeViewModel()
        _viewModel = State(initialValue: vm)
        self.abrirPestana = abrirPestana
    }

    var body: some View {
        contenido
            .background(HomeFondo(mes: viewModel.selectedMonth))
            .trackScreen("home")
            .navigationTitle("")
            .refreshable { await viewModel.refresh() }
            .task {
                await viewModel.loadIfNeeded()
            }
            // Cambios desde otras pantallas (ingreso extra en Ajustes, nómina, huchas…)
            // → recarga SOLO el budget para que el ahorro quede al día. NO recarga la
            // lista de gastos: borrar un gasto postea esta misma notificación y recargar
            // la lista durante la animación de swipe crasheaba la List.
            .onReceive(NotificationCenter.default.publisher(for: .expenseDidChange)) { _ in
                Task { await viewModel.reloadBudget() }
            }
            // El documento puede llegar después de que la Home ya esté montada.
            .onReceive(NotificationCenter.default.publisher(for: .userDocumentDidLoad)) { _ in
                viewModel.applyDefaultFilterIfNeeded()
            }
            .sheet(item: $expenseToEdit) { expense in
                EditExpenseSheet(expense: expense) {
                    Task { await viewModel.refresh() }
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showAddExpense) {
                AddExpenseSheet {
                    Task { await viewModel.refresh() }
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showFilterSheet) {
                ExpenseFilterSheet(
                    filter: $viewModel.selectedFilter,
                    availableCategories: UserDataManager.shared.categoryNames,
                    onApply: {
                        // Trigger reload to fetch data if date range changed
                        Task { await viewModel.loadExpenses() }
                    }
                )
            }
            // VoiceRecordingSheet removed - migrated to inline VoiceExpenseButton
            // VoiceConfirmationSheet is now handled by VoiceExpenseButton directly
            .onChange(of: voiceCoordinator.errorMessage) { _, newValue in
                if let error = newValue {
                    FeedbackManager.shared.show(.error, title: "Error de Voz", message: error)
                    voiceCoordinator.clearError()
                }
            }
        // onChange for silence removed - logic moved to VoiceExpenseCoordinator inside Button
            .task { await viewModel.loadMetas() }
            .task { await viewModel.loadMesAnterior() }
            .navigationDestination(item: $rutaPush) { destino in
                switch destino {
                case .recurrentes: RecurringExpensesView()
                case .deudas: DebtsView()
                default: EmptyView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // La barra de navegación del sistema se queda fuera: la del diseño es
            // una píldora de vidrio con el mes y los iconos, y eso se pinta aquí.
            .toolbar(.hidden, for: .navigationBar)
            // Un toque al encajar cada página, como al pasar de pantalla de inicio.
            .sensoryFeedback(.selection, trigger: pagina)
    }

    // MARK: - Contenido

    private var contenido: some View {
        VStack(spacing: 0) {
            barraSuperior
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.xxs)
                .padding(.bottom, Spacing.xs)

            if buscando { barraBusqueda }

            ZStack(alignment: .bottom) {
                if viewModel.state == .loading && viewModel.allExpenses.isEmpty {
                    loadingView
                } else if case .error(let error) = viewModel.state {
                    errorView(error.localizedDescription)
                } else if viewModel.gastosDelMes.isEmpty && viewModel.searchText.isEmpty {
                    emptyStateView
                } else {
                    carrusel
                }
            }
        }
        .animation(.snappy(duration: 0.3), value: buscando)
    }

    /// La barra, a la manera de iOS: el mes como título grande a la izquierda
    /// —y menú para saltar a otro—, y a la derecha los controles agrupados en
    /// cápsulas de vidrio, flechas en una y acciones en otra.
    private var barraSuperior: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            HomeTituloMes(mes: $viewModel.selectedMonth)
            Spacer(minLength: 4)

            HStack(spacing: 0) {
                botonBarra("chevron.left", "Mes anterior") { cambiarMes(-1) }
                botonBarra("chevron.right", "Mes siguiente") { cambiarMes(1) }
                    .disabled(esMesActual)
                    .opacity(esMesActual ? 0.35 : 1)
            }
            .glassCard(cornerRadius: 21)

            HStack(spacing: 0) {
                botonBarra(buscando ? "magnifyingglass.circle.fill" : "magnifyingglass", buscando ? "Cerrar búsqueda" : "Buscar") {
                    buscando.toggle()
                    if !buscando { viewModel.searchText = "" }
                }
                if viewModel.selectedFilter.hasActiveFilters {
                    botonBarra("xmark.circle.fill", "Limpiar filtros") {
                        viewModel.selectedFilter = ExpenseFilter()
                        HapticManager.shared.notification(.success)
                    }
                }
                botonBarra(viewModel.selectedFilter.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle", "Filtros") {
                    showFilterSheet = true
                }
                .tint(viewModel.selectedFilter.hasActiveFilters ? DesignTokens.Colors.accent : .primary)
            }
            .glassCard(cornerRadius: 21)
        }
        .tint(.primary)
    }

    private func botonBarra(_ icono: String, _ etiqueta: String, accion: @escaping () -> Void) -> some View {
        Button {
            accion()
            HapticManager.shared.selection()
        } label: {
            Image(systemName: icono)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 40, height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(etiqueta)
    }

    /// Cada tarjeta lleva a donde se gestiona lo que enseña.
    private func irA(_ destino: HomeDestino) {
        HapticManager.shared.selection()
        switch destino {
        case .graficas: withAnimation(.snappy) { pagina = .graficas }
        case .gastos: withAnimation(.snappy) { pagina = .gastos }
        case .metas: abrirPestana(1)
        case .recurrentes, .deudas: rutaPush = destino
        }
    }

    private var esMesActual: Bool { Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month) }

    private func cambiarMes(_ delta: Int) {
        guard let nuevo = Calendar.current.date(byAdding: .month, value: delta, to: viewModel.selectedMonth),
              delta < 0 || nuevo <= Date() else { return }
        withAnimation(.snappy) { viewModel.selectedMonth = nuevo }
    }

    private var barraBusqueda: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Buscar gastos", text: $viewModel.searchText)
                .focused($buscadorEnfocado)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Borrar búsqueda")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .glassCard(cornerRadius: CornerRadius.small)
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear { buscadorEnfocado = true }
    }

    /// Las tres páginas, a lo ancho, encajando de una en una. Es un
    /// `ScrollView` paginado y no un `TabView`: la Home ya vive dentro del
    /// `TabView` de las pestañas y anidar otro es justo lo que iOS 26 rehízo con
    /// Liquid Glass —en el iPhone con 26 no pintaba nada—.
    private var carrusel: some View {
        // `TabView` paginado, no dos ScrollView anidados: el TabView bloquea el
        // eje y solo se mueve a los lados. Con el ScrollView horizontal, un gesto
        // en diagonal movía las dos cosas a la vez. Lo que rompía iOS 26 no era
        // el TabView anidado sino los shaders sobre el vidrio (ver Efectos.swift).
        VStack(spacing: 0) {
            TabView(selection: $pagina) {
                ForEach(HomePagina.allCases) { p in
                    pagina(p, margenSuperior: Spacing.xxs)
                        // Profundidad al deslizar: la página que se va se aleja y
                        // se apaga, la que llega se acerca. Solo escala y opacidad,
                        // que no rasterizan: el vidrio sigue siendo vidrio.
                        .visualEffect { content, proxy in
                            let ancho = max(proxy.size.width, 1)
                            let desplazamiento = min(max(proxy.frame(in: .global).minX / ancho, -1), 1)
                            return content
                                .scaleEffect(1 - abs(desplazamiento) * 0.08)
                                .opacity(1 - abs(desplazamiento) * 0.55)
                        }
                        .tag(p)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HomePuntos(actual: pagina)
                .frame(height: 22)
        }
    }

    @ViewBuilder
    private func pagina(_ p: HomePagina, margenSuperior: CGFloat) -> some View {
        switch p {
        case .resumen:
            ResumenPage(
                viewModel: viewModel,
                margenSuperior: margenSuperior,
                onEditar: { expenseToEdit = $0 },
                onVerGastos: { withAnimation(.snappy) { pagina = .gastos } },
                onDestino: irA
            )
        case .graficas:
            GraficasPage(viewModel: viewModel, margenSuperior: margenSuperior, activa: pagina == .graficas)
        case .gastos:
            GastosPage(viewModel: viewModel, margenSuperior: margenSuperior, onEditar: { expenseToEdit = $0 })
        }
    }

    // MARK: - View States
    private var loadingView: some View {
        ExpenseListSkeleton()
    }

    /// Qué se encuentra alguien que acaba de terminar el onboarding.
    ///
    /// Antes era un cartel sin salida: "Sin gastos · Añade tu primer gasto del
    /// mes". El usuario venía de que le prometieran que basta con hablar, y
    /// aterrizaba en una frase que le decía qué hacer pero no cómo: el micro
    /// está flotando en otra esquina y el `+` en la barra. De 21 que terminaban
    /// el onboarding, solo 14 llegaban a apuntar algo.
    ///
    /// Ahora la promesa y la acción están en el mismo sitio.
    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Spacer()

            Image(systemName: "wallet.bifold")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.clarityPrimary.opacity(0.7))

            Text("Aún no has apuntado nada")
                .scaledFont(size: 20, weight: .semibold)

            Text("Di «20 euros en gasolina» y aparecerá aquí, ya clasificado.")
                .scaledFont(size: 15)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xl)

            // El mismo gesto que enseña el onboarding, aquí y grande.
            SimpleVoiceButton(
                viewModel: viewModel,
                categories: UserDataManager.shared.categories
            )
            .scaleEffect(1.15)
            .padding(.top, DesignTokens.Spacing.xs)

            Button {
                AnalyticsService.shared.track(.emptyStateAction(method: "manual"))
                showAddExpense = true
                HapticManager.shared.selection()
            } label: {
                Text("Prefiero escribirlo")
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundStyle(Color.clarityPrimary)
            }
            .padding(.top, DesignTokens.Spacing.xxs)

            Spacer()
        }
        .task { AnalyticsService.shared.track(.emptyStateShown) }
    }

    private func errorView(_ msg: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(msg)
        } actions: {
            Button("Reintentar") {
                Task { await viewModel.loadExpenses() }
            }
        }
    }
}

// MARK: - Mes en la barra

/// El mes como título grande, al estilo de las barras de iOS, y menú para
/// saltar a cualquiera de los últimos doce.
private struct HomeTituloMes: View {
    @Binding var mes: Date
    private let cal = Calendar.current

    private var esActual: Bool { cal.isDate(mes, equalTo: Date(), toGranularity: .month) }
    private var nombre: String { Formatters.fullMonthName(from: mes).capitalized }
    private var anio: String { String(cal.component(.year, from: mes)) }

    var body: some View {
        Menu {
            ForEach(0..<12, id: \.self) { offset in
                if let m = cal.date(byAdding: .month, value: -offset, to: Date()) {
                    Button {
                        withAnimation(.snappy) { mes = m }
                        HapticManager.shared.selection()
                    } label: {
                        if cal.isDate(m, equalTo: mes, toGranularity: .month) {
                            Label(Formatters.monthYear(from: m).capitalized, systemImage: "checkmark")
                        } else {
                            Text(Formatters.monthYear(from: m).capitalized)
                        }
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(nombre)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .tracking(-0.6)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.textSecondary)
                }
                Text(esActual ? "\(anio) · mes actual" : anio)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.leading, 4)
        }
        .tint(.primary)
        .accessibilityLabel("Cambiar de mes, ahora \(nombre) \(anio)")
    }
}

// MARK: - Destinos

/// A dónde lleva cada tarjeta de la Home.
enum HomeDestino: Hashable {
    case graficas, gastos, metas, recurrentes, deudas
}

// MARK: - Páginas

enum HomePagina: CaseIterable, Identifiable, Hashable {
    case resumen, graficas, gastos
    var id: Self { self }
}

/// Los puntos de página. El activo se alarga, como en la pantalla de inicio.
private struct HomePuntos: View {
    let actual: HomePagina

    var body: some View {
        HStack(spacing: 7) {
            ForEach(HomePagina.allCases) { p in
                Capsule()
                    .fill(p == actual ? Color.clarityPrimary : Color.primary.opacity(0.22))
                    .frame(width: p == actual ? 22 : 5, height: 5)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: actual)
        .accessibilityHidden(true)
    }
}


#Preview {
    NavigationStack { HomeView() }
}
