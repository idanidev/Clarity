// HomeView.swift
// La Home (#65): la cifra del mes, las tarjetas y la lista de gastos en un
// solo desplazamiento, y ningún cuadro vacío. Hasta la 2.4 las gráficas eran
// una segunda página que se pasaba deslizando; desde #73 son tarjetas más de
// la rejilla, y los puntos de página se fueron con ella.

import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    private var userDataManager = UserDataManager.shared

    @State private var expenseToEdit: Expense?
    /// Desde dónde se abrió la edición, para que la hoja crezca desde ahí (hasta iOS 26).
    @State private var origenEdicion = "gasto"
    /// Las transiciones de zoom de una tarjeta a su pantalla, y de una fila a su
    /// hoja de edición hasta iOS 26 (ver `transicionZoomDeHoja`: en iOS 27 la
    /// hoja con teclado se presenta sin zoom).
    @Namespace private var zoom
    @State private var showFilterSheet = false
    /// El modo edición de las tarjetas, como el de la pantalla de inicio.
    @State private var edicion = HomeEdicion()
    @State private var showAddExpense = false
    /// El buscador se abre desde la barra y ocupa su fila encima de la lista:
    /// el `.searchable` nativo se abría encima de la primera tarjeta porque el
    /// desplazamiento no le hacía hueco.
    @State private var buscando = false
    @FocusState private var buscadorEnfocado: Bool
    /// Pantalla a la que se navega desde una tarjeta.
    @State private var rutaPush: HomeDestino?
    /// Sube para pedir a Resumen que baje hasta la lista de gastos.
    @State private var irALista = 0
    /// Sube para pedir a Resumen que baje hasta la primera gráfica.
    @State private var irAGraficas = 0
    /// Para saltar a otra pestaña (Metas). Lo pone MainTabView, que es quien las tiene.
    var abrirPestana: (Int) -> Void = { _ in }

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
                #if DEBUG
                // Modo demo (capturas): la página o el modo pedidos con `-demoPantalla`.
                if ModoDemo.activo {
                    switch ModoDemo.pantalla {
                    case .graficas:
                        // Con la lista ya montada: hasta entonces no hay fila a la que bajar.
                        Task {
                            try? await Task.sleep(for: .milliseconds(800))
                            irAGraficas += 1
                        }
                    case .edicion: edicion.entrar()
                    case .home, .metas: break
                    }
                }
                #endif
                // Si el documento ya había llegado antes de montarse la Home,
                // su aviso no se vuelve a oír: se mira aquí.
                viewModel.sincronizarDisposicion()
                await viewModel.loadIfNeeded()
            }
            // Cambios desde otras pantallas (ingreso extra en Ajustes, nómina, huchas…)
            // → recarga SOLO el budget para que el ahorro quede al día. NO recarga la
            // lista de gastos: borrar un gasto postea esta misma notificación y recargar
            // la lista durante la animación de swipe crasheaba la List.
            .onReceive(NotificationCenter.default.publisher(for: .expenseDidChange)) { _ in
                Task { await viewModel.reloadBudget() }
            }
            // Un gasto guardado fuera (un cargo recurrente): se inserta en su
            // sitio, sin recargar la lista.
            .onReceive(NotificationCenter.default.publisher(for: .gastoAnadido)) { aviso in
                if let gasto = aviso.object as? Expense { viewModel.incorporarGastoDeFuera(gasto) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .gastoQuitado)) { aviso in
                if let id = (aviso.object as? Expense)?.id { viewModel.removeExpense(id: id) }
            }
            // El documento puede llegar después de que la Home ya esté montada.
            .onReceive(NotificationCenter.default.publisher(for: .userDocumentDidLoad)) { _ in
                viewModel.applyDefaultFilterIfNeeded()
                // La disposición de la cuenta: si es más reciente que la del
                // iPhone (se editó en otro dispositivo), manda esa.
                viewModel.sincronizarDisposicion()
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
            // La galería del «+» del modo edición: todas las tarjetas, con su
            // vista previa, y la pila inteligente.
            .sheet(isPresented: $edicion.mostrandoGaleria) {
                GaleriaTarjetasSheet(viewModel: viewModel)
                    .presentationDetents([.large])
            }
            // VoiceRecordingSheet removed - migrated to inline VoiceExpenseButton
            // VoiceConfirmationSheet is now handled by VoiceExpenseButton directly
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
    }

    // MARK: - Contenido

    private var contenido: some View {
        VStack(spacing: 0) {
            // Barra y buscador en un mismo contenedor de vidrio: en iOS 26 el
            // buscador sale de la barra como una gota en vez de aparecer sin más.
            // Espaciado pequeño para que las cápsulas no se fundan entre sí.
            VStack(spacing: 0) {
                Group {
                    if edicion.activa { barraEdicion } else { barraSuperior }
                }
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
                } else if viewModel.gastosDelMes.isEmpty && viewModel.aportacionesDelMes.isEmpty
                            && viewModel.searchText.isEmpty && !viewModel.cargandoMes {
                    // Solo con el mes ya cargado. Mientras llega uno nuevo se
                    // queda la lista: cambiarla por este cartel y volver a
                    // montarla entera era el tirón de cada cambio de mes.
                    emptyStateView
                } else {
                    // La lista llega hasta el borde y pasa por debajo de la barra
                    // de pestañas; deja su hueco al final.
                    ZStack(alignment: .bottom) {
                        // En edición, la lista sigue montada debajo —al salir se
                        // vuelve a la misma posición— pero ni se ve ni se toca.
                        resumen
                            .opacity(edicion.activa ? 0 : 1)
                            .allowsHitTesting(!edicion.activa)
                            .accessibilityHidden(edicion.activa)
                        if edicion.activa {
                            EdicionHomeView(viewModel: viewModel, edicion: edicion,
                                            margenSuperior: Spacing.xxs, zoom: zoom)
                                .transition(.opacity)
                        }
                    }
                    // El teclado solo cuenta si es el del buscador. El de una
                    // hoja (añadir o editar gasto) encogía la lista que
                    // queda debajo y subía la cabecera sobre el reloj.
                    .ignoresSafeArea(buscando ? .container : .all, edges: .bottom)
                }
            }
        }
        .animation(.snappy(duration: 0.3), value: buscando)
        .animation(.snappy(duration: AnimationDuration.normal), value: edicion.activa)
    }

    /// La barra en edición, como en la pantalla de inicio: «+» a la izquierda
    /// para la galería y «Hecho» a la derecha.
    private var barraEdicion: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            botonBarra("plus", "Añadir tarjeta") {
                Migas.deja("home: abre galería")
                edicion.mostrandoGaleria = true
            }
            .glassCard(cornerRadius: 21, interactivo: true)
            Spacer(minLength: 4)
            Button {
                edicion.salir()
                HapticManager.shared.selection()
            } label: {
                // Mango con texto Deep Berry: el botón principal de la pantalla.
                Text("Hecho")
                    .font(.headline)
                    .foregroundStyle(Color.clarityBerry)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(Color.clarityMango, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(TarjetaButtonStyle())
        }
        // El mismo alto que la barra normal, para que la Home no salte al entrar.
        .frame(minHeight: 50)
        .transition(.opacity)
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
        case .graficas:
            // A la primera gráfica puesta; sin ninguna, a la galería, que es donde se añaden.
            if viewModel.idFilaDeLaPrimeraGrafica != nil {
                irAGraficas += 1
            } else {
                edicion.entrar()
                edicion.mostrandoGaleria = true
            }
        case .gastos:
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

    /// La Home entera: la cifra del mes, las tarjetas (gráficas incluidas) y la
    /// lista de gastos, en un solo desplazamiento.
    private var resumen: some View {
        ResumenPage(
            viewModel: viewModel,
            margenSuperior: Spacing.xxs,
            irALista: irALista,
            irAGraficas: irAGraficas,
            zoom: zoom,
            onEditar: { gasto, origen in
                origenEdicion = origen
                expenseToEdit = gasto
            },
            onDestino: irA,
            edicion: edicion
        )
        // No hereda el hueco de la barra: la lista deja el suyo.
        .sinHuecoBarraInferior()
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

#Preview {
    NavigationStack { HomeView() }
}
