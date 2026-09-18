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
    /// La barra de pestañas flotante: el carrusel llega hasta el borde y deja su hueco.
    @Environment(\.medidaBarraInferior) private var barra
    @State private var expenseToEdit: Expense?
    /// Desde dónde se abrió la edición, para que la hoja crezca desde ahí (hasta iOS 26).
    @State private var origenEdicion = "gasto"
    /// Las transiciones de zoom de una tarjeta a su pantalla. Solo en lo que se
    /// abre con push: una hoja con teclado presentada con zoom se colgaba en iOS 26.
    @Namespace private var zoom
    @State private var showFilterSheet = false
    @State private var showPersonalizar = false
    @State private var showAddExpense = false
    /// El buscador se abre desde la barra y ocupa su fila encima del carrusel:
    /// el `.searchable` nativo se abría encima de la primera tarjeta porque el
    /// carrusel horizontal no le hacía hueco.
    @State private var buscando = false
    @FocusState private var buscadorEnfocado: Bool
    /// Pantalla a la que se navega desde una tarjeta.
    @State private var rutaPush: HomeDestino?
    /// Sube para pedir a Resumen que baje hasta la lista de gastos.
    @State private var irALista = 0
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
            // Más intenso que en el resto: el brillo cae detrás de la barra del
            // mes y con la intensidad normal apenas se veía.
            .background(HomeFondo(intensidad: .home))
            // Enhorabuena si el mes anterior se cerró dentro del presupuesto.
            .overlay {
                if let cierre = viewModel.cierreDeMesPendiente {
                    CelebracionClarity(
                        icono: "checkmark.seal.fill",
                        titulo: "Cerraste \(cierre.mes) dentro del presupuesto",
                        detalle: "Te sobraron \(Formatters.currency(cierre.sobrante)). Buen mes.",
                        onCerrar: { viewModel.marcarCierreCelebrado() }
                    )
                }
            }
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
                .transicionZoomDeHoja(id: origenEdicion, en: zoom)
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
                // Una hoja no tiene barra de pestañas debajo, y sus filas de
                // chips a lo ancho crecían con el hueco heredado.
                .sinHuecoBarraInferior()
            }
            .sheet(isPresented: $showPersonalizar) {
                PersonalizarHomeSheet(viewModel: viewModel)
                    .presentationDetents([.large])
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
            .task { await viewModel.loadNormal() }
            .task { await viewModel.comprobarCierreDeMes() }
            .navigationDestination(item: $rutaPush) { destino in
                switch destino {
                case .recurrentes:
                    RecurringExpensesView()
                        .transicionZoom(id: "destino-recurrentes", en: zoom)
                case .deudas:
                    DebtsView()
                        .transicionZoom(id: "destino-deudas", en: zoom)
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
            // Barra y buscador en un mismo contenedor de vidrio: en iOS 26 el
            // buscador sale de la barra como una gota en vez de aparecer sin más.
            // Espaciado pequeño para que las cápsulas no se fundan entre sí.
            VStack(spacing: 0) {
                barraSuperior
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.xxs)
                    .padding(.bottom, Spacing.xs)

                if buscando { barraBusqueda }
            }
            .contenedorDeVidrio(espaciado: 4)

            ZStack(alignment: .bottom) {
                if viewModel.state == .loading && viewModel.allExpenses.isEmpty {
                    loadingView
                } else if case .error(let error) = viewModel.state {
                    errorView(error.localizedDescription)
                } else if viewModel.gastosDelMes.isEmpty && viewModel.searchText.isEmpty && !viewModel.cargandoMes {
                    // Solo con el mes ya cargado. Mientras llega uno nuevo se
                    // queda el carrusel: cambiarlo por este cartel y volver a
                    // montarlo entero era el tirón de cada cambio de mes.
                    emptyStateView
                } else {
                    // Las páginas llegan hasta el borde y pasan por debajo de la
                    // barra de pestañas; cada una deja su hueco al final. Los
                    // puntos se colocan desde ese mismo borde, justo encima de la
                    // barra: con el carrusel ignorando el área segura, un relleno
                    // sobre el área segura los dejaba tapados por ella.
                    ZStack(alignment: .bottom) {
                        carrusel
                        HomePuntos(actual: pagina)
                            .padding(.bottom, barra.total + 6)
                    }
                    .ignoresSafeArea(.container, edges: .bottom)
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
            .glassCard(cornerRadius: 21, interactivo: true)

            HStack(spacing: 0) {
                botonBarra(buscando ? "magnifyingglass.circle.fill" : "magnifyingglass", buscando ? "Cerrar búsqueda" : "Buscar") {
                    buscando.toggle()
                    if !buscando { viewModel.searchText = "" }
                }
                // Filtros de verdad, no el mes: con `hasActiveFilters` bastaba
                // cambiar de mes para que saliera la X de limpiar.
                if viewModel.filtroActivo {
                    botonBarra("xmark.circle.fill", "Limpiar filtros") {
                        viewModel.limpiarFiltros()
                        HapticManager.shared.notification(.success)
                    }
                }
                botonBarra(viewModel.filtroActivo ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle", "Filtros") {
                    showFilterSheet = true
                }
                .tint(viewModel.filtroActivo ? DesignTokens.Colors.accent : .primary)
            }
            .glassCard(cornerRadius: 21, interactivo: true)
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
                // Al cambiar de icono (lupa abierta, filtro puesto) se transforma
                // en vez de saltar.
                .contentTransition(.symbolEffect(.replace))
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
        case .gastos:
            withAnimation(.snappy) { pagina = .resumen }
            irALista += 1
        case .metas: abrirPestana(1)
        case .recurrentes, .deudas: rutaPush = destino
        }
    }

    private var esMesActual: Bool { Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month) }

    /// Sin `withAnimation`: animar el cambio de mes animaba a la vez cada fila
    /// de la lista, cada barra y cada sector, y se notaba el tirón. Lo que tiene
    /// que moverse —el título, las cifras— lleva su propia transición.
    private func cambiarMes(_ delta: Int) {
        guard let nuevo = Calendar.current.date(byAdding: .month, value: delta, to: viewModel.selectedMonth),
              delta < 0 || nuevo <= Date() else { return }
        viewModel.selectedMonth = nuevo
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

    /// Las páginas, a lo ancho, encajando de una en una.
    ///
    /// `TabView` paginado, no dos ScrollView anidados: el TabView bloquea el
    /// eje y solo se mueve a los lados. Con el ScrollView horizontal, un gesto
    /// en diagonal movía las dos cosas a la vez. Lo que rompía iOS 26 no era
    /// el TabView anidado sino los shaders sobre el vidrio (ver Efectos.swift).
    ///
    /// Las páginas ya no se alejan ni se apagan al deslizar: escalar y apagar
    /// una página llena de vidrio obligaba a recalcular cada tarjeta en cada
    /// frame del gesto, y era el tirón al pasar a Gráficas.
    private var carrusel: some View {
        TabView(selection: $pagina) {
            ForEach(HomePagina.allCases) { p in
                pagina(p, margenSuperior: Spacing.xxs)
                    .tag(p)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // El paginado no hereda el hueco de la barra: cada página deja el suyo.
        .sinHuecoBarraInferior()
    }

    @ViewBuilder
    private func pagina(_ p: HomePagina, margenSuperior: CGFloat) -> some View {
        switch p {
        case .resumen:
            ResumenPage(
                viewModel: viewModel,
                margenSuperior: margenSuperior,
                irALista: irALista,
                zoom: zoom,
                onEditar: { gasto, origen in
                    origenEdicion = origen
                    expenseToEdit = gasto
                },
                onDestino: irA,
                onPersonalizar: { showPersonalizar = true }
            )
        case .graficas:
            GraficasPage(viewModel: viewModel, margenSuperior: margenSuperior, activa: pagina == .graficas)
        }
    }

    // MARK: - View States

    /// Una forma que respira mientras llegan los gastos, en lugar de bloques grises.
    private var loadingView: some View {
        CargaClarity(texto: "Cargando tus gastos")
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
                        mes = m
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
                        // Solo el título se anima al cambiar de mes.
                        .animation(.snappy, value: nombre)
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
    case resumen, graficas
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
        // Una cápsula oscura detrás: los puntos flotan sobre la lista que pasa
        // por debajo y sin fondo se mezclaban con el texto de las tarjetas.
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.35), in: Capsule())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: actual)
        .accessibilityHidden(true)
    }
}


#Preview {
    NavigationStack { HomeView() }
}
