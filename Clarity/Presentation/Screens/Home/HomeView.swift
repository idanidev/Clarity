// HomeView.swift
// La Home (#65): tres páginas que se pasan deslizando —resumen, gráficas,
// calendario— y ningún cuadro vacío. La barra flotante que había para elegir
// vista se fue: costaba 60 pt fijos sobre los gastos y los puntos de abajo
// dicen lo mismo sin ocupar nada.

import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    private var userDataManager = UserDataManager.shared

    /// Página visible del carrusel. Opcional porque `scrollPosition` lo pide.
    @State private var pagina: HomePagina? = .resumen
    @State private var expenseToEdit: Expense?
    @State private var showFilterSheet = false
    @State private var showAddExpense = false
    /// El buscador se abre desde la barra y ocupa su fila encima del carrusel:
    /// el `.searchable` nativo se abría encima de la primera tarjeta porque el
    /// carrusel horizontal no le hacía hueco.
    @State private var buscando = false
    @FocusState private var buscadorEnfocado: Bool
    @State private var voiceCoordinator = VoiceExpenseCoordinator()
    @State private var speechManager = SpeechRecognitionManager.shared

    @MainActor
    init(viewModel: HomeViewModel? = nil) {
        let vm = viewModel ?? DependencyContainer.shared.makeHomeViewModel()
        _viewModel = State(initialValue: vm)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { barra }
            // Un toque al encajar cada página, como al pasar de pantalla de inicio.
            .sensoryFeedback(.selection, trigger: pagina)
    }

    // MARK: - Contenido

    private var contenido: some View {
        VStack(spacing: 0) {
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

                botonDeVoz
            }
        }
        .animation(.snappy(duration: 0.3), value: buscando)
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
        // El carrusel horizontal extiende su contenido bajo la barra de
        // navegación y no se lo inseta, así que la barra pisaba la primera
        // tarjeta. Aquí se mide el área segura superior —estado más barra— y
        // cada página deja ese margen en su propio desplazamiento: la primera
        // tarjeta nace debajo de la barra y, al desplazar, pasa por debajo.
        GeometryReader { geo in
            let margen = geo.safeAreaInsets.top + Spacing.xs
            VStack(spacing: 0) {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(HomePagina.allCases) { p in
                            pagina(p, margenSuperior: margen)
                                .frame(width: geo.size.width, height: geo.size.height + geo.safeAreaInsets.top - 22)
                                .id(p)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $pagina)
                .scrollIndicators(.hidden)

                HomePuntos(actual: pagina ?? .resumen)
                    .frame(height: 22)
            }
            .ignoresSafeArea(edges: .top)
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
                onVerGastos: { withAnimation(.snappy) { pagina = .gastos } }
            )
        case .graficas:
            GraficasPage(viewModel: viewModel, margenSuperior: margenSuperior)
        case .gastos:
            GastosPage(viewModel: viewModel, margenSuperior: margenSuperior, onEditar: { expenseToEdit = $0 })
        }
    }

    private var botonDeVoz: some View {
        HStack {
            Spacer()
            SimpleVoiceButton(viewModel: viewModel, categories: userDataManager.categories)
        }
        .padding(.trailing, Spacing.md)
        .padding(.bottom, Spacing.xl)
    }

    // MARK: - Barra de navegación: mes en el centro, filtros a la derecha

    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HomeMesControl(mes: $viewModel.selectedMonth)
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: Spacing.xs) {
                Button {
                    buscando.toggle()
                    if !buscando { viewModel.searchText = "" }
                    HapticManager.shared.selection()
                } label: {
                    Image(systemName: buscando ? "magnifyingglass.circle.fill" : "magnifyingglass")
                }
                .accessibilityLabel(buscando ? "Cerrar búsqueda" : "Buscar")

                if viewModel.selectedFilter.hasActiveFilters {
                    Button {
                        viewModel.selectedFilter = ExpenseFilter()
                        HapticManager.shared.notification(.success)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .accessibilityLabel("Limpiar filtros")
                }
                Button {
                    showFilterSheet = true
                    HapticManager.shared.selection()
                } label: {
                    Image(systemName: viewModel.selectedFilter.hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filtros")
            }
            .tint(viewModel.selectedFilter.hasActiveFilters ? DesignTokens.Colors.accent : DesignTokens.Colors.textPrimary)
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

/// El mes, compacto para caber en una barra de navegación: flechas a los lados
/// y el nombre como menú para saltar a cualquiera de los últimos doce.
private struct HomeMesControl: View {
    @Binding var mes: Date
    private let cal = Calendar.current

    private var esActual: Bool { cal.isDate(mes, equalTo: Date(), toGranularity: .month) }

    var body: some View {
        HStack(spacing: 2) {
            Button { cambiar(-1) } label: {
                Image(systemName: "chevron.left").font(.subheadline.weight(.semibold)).frame(width: 30, height: 30)
            }
            .accessibilityLabel("Mes anterior")

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
                VStack(spacing: 0) {
                    Text(Formatters.monthYear(from: mes).capitalized)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    if esActual {
                        Text("mes actual").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 150)
            }

            Button { cambiar(1) } label: {
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).frame(width: 30, height: 30)
            }
            .disabled(esActual)
            .accessibilityLabel("Mes siguiente")
        }
        .tint(.primary)
    }

    private func cambiar(_ delta: Int) {
        guard let nuevo = cal.date(byAdding: .month, value: delta, to: mes), nuevo <= Date() || delta < 0 else { return }
        withAnimation(.snappy) { mes = nuevo }
        HapticManager.shared.selection()
    }
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
