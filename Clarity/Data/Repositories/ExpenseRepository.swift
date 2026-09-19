// ExpenseRepository.swift
// Data layer implementation of the repository contract

import FirebaseAuth
import Foundation
import OSLog

@MainActor
final class ExpenseRepository: ExpenseRepositoryProtocol {
    private let remoteDataSource: FirebaseExpenseDataSource
    private let swiftDataSource: SwiftDataExpenseDataSource
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "ExpenseRepo")

    /// Margen antes de dar la lectura remota por perdida y servir cache local.
    private static let remoteReadTimeout: TimeInterval = 8
    /// Antigüedad de la última sincronización a partir de la cual se lanza otra.
    private static let maxAgePorDefecto: TimeInterval = 300
    /// Pasado este tiempo, una sincronización que no ha vuelto se da por
    /// perdida: sin cobertura Firestore puede no contestar nunca, y no debe
    /// impedir las siguientes hasta reiniciar la app.
    private static let margenSincronizacionColgada: TimeInterval = 60

    /// Cuándo empezó la sincronización de fondo en marcha, si la hay.
    private var sincronizacionEnMarchaDesde: Date?

    init(remote: FirebaseExpenseDataSource, swiftData: SwiftDataExpenseDataSource) {
        self.remoteDataSource = remote
        self.swiftDataSource = swiftData
    }

    // MARK: - Read
    
    func getExpenses(policy: CachePolicy) async throws -> [Expense] {
        switch policy {
        case .cacheFirst(let maxAge):
            // Check SwiftData
            let cached = try swiftDataSource.fetchExpenses()

            if !cached.isEmpty {
                logger.debug("Returning SwiftData expenses")
                sincronizarEnSegundoPlanoSiToca(maxAge: maxAge)
                return cached
            }
            
            logger.debug("SwiftData empty, fetching remote")
            return try await fetchAndCache()
            
        case .networkFirst:
            do {
                return try await fetchAndCache()
            } catch {
                logger.warning("Network failed, checking SwiftData: \(error.localizedDescription)")
                let cached = try swiftDataSource.fetchExpenses()
                if !cached.isEmpty {
                    return cached
                }
                throw error
            }
            
        case .cacheOnly:
            return try swiftDataSource.fetchExpenses()
        }
    }
    
    func getExpenses() async throws -> [Expense] {
        try await getExpenses(policy: .cacheFirst(maxAge: Self.maxAgePorDefecto))
    }

    func getExpenses(from startDate: String, to endDate: String) async throws -> [Expense] {
        do {
            let remote = remoteDataSource
            return try await withTimeout(Self.remoteReadTimeout) {
                try await remote.getExpenses(from: startDate, to: endDate)
            }
        } catch {
            // Offline: filtra la cache local por el mismo rango (comparación
            // lexicográfica válida porque date es "yyyy-MM-dd").
            logger.warning("Range fetch failed, falling back to cache: \(error.localizedDescription)")
            let cached = try swiftDataSource.fetchExpenses()
            return cached.filter { $0.date >= startDate && $0.date <= endDate }
        }
    }
    
    // MARK: - Paginated Fetch
    
    func getExpensesPaginated(page: Int, filter: ExpenseFilter?) async throws -> PageResult {
        // HYBRID APPROACH: If page query, we try to fetch ALL to satisfy user request "pedir todo"
        // But we keep the signature.
        // Actually, let's use the new getExpenses(filter:) logic for "page 0" and return all.
        // Infinite scroll will just receive empty on page 1.
        
        guard page == 0 else {
            return PageResult(expenses: [], hasMore: false)
        }

        // Sin filtro o con "Todos" el remoto no acota: devuelve el historial
        // entero, y la Home lo pedía en cada carga y en cada tirón para
        // refrescar de quien tiene "Todos" como filtro predeterminado. Eso
        // mismo está en la caché una vez se ha bajado entera, y la
        // sincronización de fondo la mantiene al día. El resto de filtros
        // siguen yendo a remoto: acotan por fecha y cuestan lo que enseñan.
        if filter == nil || filter?.dateRange == .allTime {
            let cacheVacia = ((try? swiftDataSource.count()) ?? 0) == 0
            let ultimaCompleta = UserDefaults.standard.double(forKey: ExpenseSyncPolicy.lastFullSyncKey)
            if ExpenseSyncPolicy.respondeDesdeCache(
                filter: filter, cacheVacia: cacheVacia, ultimaCompleta: ultimaCompleta),
               let cached = try? swiftDataSource.fetchExpenses() {
                sincronizarEnSegundoPlanoSiToca(maxAge: Self.maxAgePorDefecto)
                // Igual que el remoto: todo, por fecha descendente. Lo demás
                // del filtro (categorías, métodos de pago…) lo aplica quien
                // llama, como con la respuesta de Firestore.
                return PageResult(expenses: ExpenseSyncPolicy.enOrdenRemoto(cached), hasMore: false)
            }
        }

        do {
            // Timeout: sin cobertura Firestore puede no resolver nunca y la Home
            // se quedaba en blanco en vez de caer a la cache local (issue #32).
            let remote = remoteDataSource
            let expenses = try await withTimeout(Self.remoteReadTimeout) {
                try await remote.getExpenses(filter: filter)
            }

            if !expenses.isEmpty {
                // Bulk save to local cache (might be heavy if >1000, but simplest path)
                Task { try? await saveToLocal(expenses) }
            }

            return PageResult(expenses: expenses, hasMore: false) // No more pages, we fetched all.
        } catch {
            logger.warning("Paginated fetch failed, falling back to cache: \(error.localizedDescription)")
            let cached = try swiftDataSource.fetchExpenses()
            let filtered = filter?.apply(to: cached) ?? cached
            guard !filtered.isEmpty || !cached.isEmpty else { throw error }
            return PageResult(expenses: filtered, hasMore: false)
        }
    }
    
    // MARK: - Write
    
    func addExpense(_ expense: Expense) async throws -> String {
        // 1. Add to remote
        let id = try await remoteDataSource.addExpense(expense)
        
        // 2. Add to local
        var expenseWithId = expense
        expenseWithId.id = id
        olvidarMarcasSiLaCacheEstaVacia()
        try swiftDataSource.addExpense(expenseWithId)
        
        return id
    }
    
    func deleteExpense(id: String) async throws {
        try await remoteDataSource.deleteExpense(id: id)
        try swiftDataSource.deleteExpense(id)
    }
    
    func updateExpense(_ expense: Expense) async throws {
        try await remoteDataSource.updateExpense(expense)
        try swiftDataSource.updateExpense(expense)
    }
    
    // MARK: - Helpers
    
    private func fetchAndCache() async throws -> [Expense] {
        let remote = try await remoteDataSource.getExpenses()
        try await saveToLocal(remote)
        return remote
    }
    
    /// Lanza la sincronización de fondo si la última es más vieja que
    /// `maxAge`: antes se bajaba el historial de Firestore en cada arranque,
    /// aunque se hubiera hecho hacía un minuto.
    ///
    /// Y una sola a la vez: al arrancar la piden casi a la par la Home, las
    /// gráficas y "Añadir gasto", y cada una bajaba lo mismo por su cuenta.
    private func sincronizarEnSegundoPlanoSiToca(maxAge: TimeInterval) {
        let ahora = Date()
        let ultima = UserDefaults.standard.double(forKey: ExpenseSyncPolicy.lastSyncKey)
        guard ahora.timeIntervalSince1970 - ultima > maxAge else { return }
        if let desde = sincronizacionEnMarchaDesde,
           ahora.timeIntervalSince(desde) < Self.margenSincronizacionColgada { return }

        sincronizacionEnMarchaDesde = ahora
        Task {
            try? await syncFromRemote()
            // Si se dio por colgada y hay otra más nueva, la marca es suya.
            if sincronizacionEnMarchaDesde == ahora { sincronizacionEnMarchaDesde = nil }
        }
    }

    private func syncFromRemote() async throws {
        // Capturar uid antes del await para detectar cambio de usuario durante el sync
        // (evita escribir datos del usuario A en cache local del usuario B tras sign-out/in).
        let uidAtStart = Auth.auth().currentUser?.uid

        // Lo normal es la ventana reciente; el historial entero, una vez por
        // semana, para que acaben llegando las ediciones hechas desde otro
        // dispositivo en gastos antiguos. Ver `ExpenseSyncPolicy`.
        let defaults = UserDefaults.standard
        let completa = ExpenseSyncPolicy.tocaCompleta(
            ultimaCompleta: defaults.double(forKey: ExpenseSyncPolicy.lastFullSyncKey),
            ahora: Date().timeIntervalSince1970)
        let ventana = completa ? nil : ExpenseSyncPolicy.ventana(para: Date())
        logger.debug("Background syncing (\(completa ? "historial entero" : "ventana", privacy: .public))...")

        // Solo del servidor: una respuesta servida de la caché de Firestore no
        // es una sincronización, y marcaría como completa una caché a medias.
        let remote: [Expense]
        if let ventana {
            remote = try await remoteDataSource.getExpenses(
                from: ventana.desde, to: ventana.hasta, soloServidor: true)
        } else {
            remote = try await remoteDataSource.getExpenses(soloServidor: true)
        }

        let uidAfter = Auth.auth().currentUser?.uid
        guard uidAtStart == uidAfter, uidAfter != nil else {
            logger.warning("syncFromRemote: user changed mid-sync, discarding remote payload")
            return
        }
        // Se purgan los locales que ya no existen en remoto (borrados desde
        // otro dispositivo), pero solo dentro de lo que se ha pedido y si la
        // respuesta trae un número razonable de gastos: una respuesta a medias
        // no debe borrar la caché.
        try swiftDataSource.volcarSincronizacion(remote, ventana: ventana)

        let ahora = Date().timeIntervalSince1970
        defaults.set(ahora, forKey: ExpenseSyncPolicy.lastSyncKey)
        if completa { defaults.set(ahora, forKey: ExpenseSyncPolicy.lastFullSyncKey) }
        logger.debug("Background sync complete")
    }

    private func saveToLocal(_ expenses: [Expense]) async throws {
        olvidarMarcasSiLaCacheEstaVacia()
        // En bloque y con un solo save: ver `upsertAll`.
        try swiftDataSource.upsertAll(expenses)
    }

    /// Una caché vacía no refleja ninguna sincronización. Si quedan marcas de
    /// otra vida del almacén (se recreó por corrupción, o no se limpiaron al
    /// salir), lo primero que entre —el mes que guarda la Home— pasaría por
    /// historial completo: "Todos" enseñaría un mes y lo antiguo tardaría una
    /// semana en bajar.
    private func olvidarMarcasSiLaCacheEstaVacia() {
        guard (try? swiftDataSource.count()) == 0 else { return }
        ExpenseSyncPolicy.olvidarMarcas()
    }
}
