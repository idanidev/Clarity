// BackupManager.swift
// Sistema de backup y restauración completo para datos de usuario

import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog
import SwiftUI

// MARK: - Backup-Safe Model Types
// JSONEncoder no puede serializar @DocumentID (lanza encodingIsNotSupported).
// Usamos estas structs intermedias sin @DocumentID para el backup.
//
// `nonisolated` + `Sendable`: la copia se serializa en una tarea aparte (ver
// `BackupChunking`), no en el hilo principal. Las conversiones desde y hacia
// los modelos de Firestore sí se quedan en el main actor, que es donde viven.

nonisolated struct RecurringExpenseBackup: Codable, Sendable {
    var id: String?
    var amount: Double
    var name: String
    var category: String
    var subcategory: String?
    var paymentMethod: String
    var frequency: RecurringFrequency
    var dayOfMonth: Int
    var billingMonth: Int
    var active: Bool
    var icon: String?
    var startDate: String?
    var endDate: String?
    var lastCreated: String?
    var createdAt: String?
    var updatedAt: String?

    @MainActor
    init(_ r: RecurringExpense) {
        id = r.id
        amount = r.amount
        name = r.name
        category = r.category
        subcategory = r.subcategory
        paymentMethod = r.paymentMethod
        frequency = r.frequency
        dayOfMonth = r.dayOfMonth
        billingMonth = r.billingMonth
        active = r.active
        icon = r.icon
        startDate = r.startDate
        endDate = r.endDate
        lastCreated = r.lastCreated
        createdAt = r.createdAt
        updatedAt = r.updatedAt
    }

    @MainActor
    func toRecurringExpense() -> RecurringExpense {
        RecurringExpense(
            id: id, amount: amount, name: name, category: category,
            subcategory: subcategory, paymentMethod: paymentMethod,
            frequency: frequency, dayOfMonth: dayOfMonth, billingMonth: billingMonth,
            active: active, icon: icon, startDate: startDate, endDate: endDate,
            lastCreated: lastCreated, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

nonisolated struct MonthlyBudgetBackup: Codable, Sendable {
    var id: String?   // documentId (sin @DocumentID wrapper)
    var userId: String
    var year: Int
    var month: Int
    var income: Double
    var currency: String
    var savingsAllocated: Double
    var createdAt: Date
    var updatedAt: Date

    @MainActor
    init(_ b: MonthlyBudget) {
        id = b.documentId
        userId = b.userId
        year = b.year
        month = b.month
        income = b.income
        currency = b.currency
        savingsAllocated = b.savingsAllocated
        createdAt = b.createdAt
        updatedAt = b.updatedAt
    }

    @MainActor
    func toMonthlyBudget() -> MonthlyBudget {
        var budget = MonthlyBudget(
            userId: userId, year: year, month: month,
            income: income, currency: currency, savingsAllocated: savingsAllocated
        )
        budget.createdAt = createdAt
        budget.updatedAt = updatedAt
        return budget
    }
}

/// Representa un backup completo del usuario
nonisolated struct UserBackup: Codable, Sendable {
    let userId: String
    let timestamp: Date
    let version: String

    // Datos del usuario
    let userDocument: UserDocument?
    let expenses: [Expense]
    let categories: [Category]
    let recurringExpenses: [RecurringExpenseBackup]   // sin @DocumentID
    let monthlyBudgets: [MonthlyBudgetBackup]         // sin @DocumentID
    let savedFilters: [ExpenseFilter]

    // Metadata
    let deviceInfo: DeviceInfo

    struct DeviceInfo: Codable, Sendable {
        let model: String
        let systemVersion: String
        let appVersion: String
    }

    /// La misma copia con otros gastos: sin ellos para el documento principal
    /// de una copia por partes, o con todos al recomponerla.
    func conGastos(_ gastos: [Expense]) -> UserBackup {
        UserBackup(
            userId: userId, timestamp: timestamp, version: version,
            userDocument: userDocument, expenses: gastos, categories: categories,
            recurringExpenses: recurringExpenses, monthlyBudgets: monthlyBudgets,
            savedFilters: savedFilters, deviceInfo: deviceInfo
        )
    }
}

@MainActor
@Observable
final class BackupManager {

    // MARK: - Singleton
    static let shared = BackupManager()

    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "BackupManager")

    private init() {}

    // MARK: - State
    var isCreatingBackup = false
    var isRestoringBackup = false
    var availableBackups: [BackupMetadata] = []

    struct BackupMetadata: Identifiable, Codable {
        let id: String
        let timestamp: Date
        let expenseCount: Int
        let categoryCount: Int
        let size: Int // bytes
        /// Documentos hermanos con los gastos (0 = copia de un solo documento).
        /// Sus ids se deducen de este número: borrarlos no cuesta una consulta.
        let partCount: Int
    }

    private func backupsCollection(_ userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("backups")
    }

    // MARK: - Create Backup

    /// Crea un backup completo del usuario actual
    func createBackup() async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "BackupManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuario no autenticado"])
        }

        isCreatingBackup = true
        defer { isCreatingBackup = false }

        logger.info("🔄 Creating backup for user \(userId)...")

        // 1. Recopilar todos los datos del usuario
        let userDoc = UserDataManager.shared.userDocument
        let expenses = try await fetchAllExpenses(userId: userId)
        let categories = UserDataManager.shared.categories
        let recurring = try await fetchRecurringExpenses(userId: userId)
        let budgets = try await fetchMonthlyBudgets(userId: userId)
        let filters = UserDataManager.shared.savedFilters

        // 2. Crear objeto de backup
        // Convertir a tipos backup-safe (sin @DocumentID) para que JSONEncoder funcione
        let recurringBackup = recurring.map { RecurringExpenseBackup($0) }
        let budgetsBackup = budgets.map { MonthlyBudgetBackup($0) }

        let backup = UserBackup(
            userId: userId,
            timestamp: Date(),
            version: "1.0",
            userDocument: userDoc,
            expenses: expenses,
            categories: categories,
            recurringExpenses: recurringBackup,
            monthlyBudgets: budgetsBackup,
            savedFilters: filters,
            deviceInfo: .init(
                model: UIDevice.current.model,
                systemVersion: UIDevice.current.systemVersion,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            )
        )

        // 3. Guardar en Firestore (colección backups)
        // Usamos JSONEncoder en lugar de Firestore.Encoder para evitar
        // FirestoreEncodingError con @DocumentID, Set<String> y tipos complejos anidados
        //
        // Fuera del hilo principal: es el historial entero, y la copia
        // automática salta en el arranque, justo cuando se está pintando la Home.
        let backupId = UUID().uuidString
        let documentos = try await Task.detached(priority: .utility) {
            try BackupChunking.trocear(backup)
        }.value

        // 4. Guardar datos + metadata en un único setData (plain [String: Any] para evitar FirestoreEncodingError)
        let firestoreData: [String: Any] = [
            "jsonData": documentos.principal,
            "version": backup.version,
            "userId": backup.userId,
            "timestamp": Timestamp(date: backup.timestamp),  // raíz para poder ordenar por él
            "partCount": documentos.partes.count,
            "metadata": [
                "id": backupId,
                "timestamp": Timestamp(date: backup.timestamp),
                "expenseCount": expenses.count,
                "categoryCount": categories.count,
                "size": documentos.bytes
            ] as [String: Any]
        ]

        // Las partes primero y el documento principal al final: es el que hace
        // que la copia exista. Si algo falla a medias no queda una copia a la
        // vista con gastos de menos, solo partes sueltas que se recogen aquí.
        let coleccion = backupsCollection(userId)
        do {
            for (indice, parte) in documentos.partes.enumerated() {
                let datosDeParte: [String: Any] = [
                    "isBackupPart": true,
                    "parentBackupId": backupId,
                    "partIndex": indice,
                    "partCount": documentos.partes.count,
                    "jsonData": parte,
                    "userId": backup.userId,
                    // `createdAt`, no `timestamp`: ver `BackupChunking`.
                    "createdAt": Timestamp(date: backup.timestamp),
                ]
                let id = BackupChunking.idDeParte(copia: backupId, indice: indice)
                try await withRetry {
                    try await coleccion.document(id).setData(datosDeParte)
                }
            }
            try await withRetry {
                try await coleccion.document(backupId).setData(firestoreData)
            }
        } catch {
            logger.error("❌ Copia \(backupId) sin terminar (\(documentos.partes.count) partes): \(error.localizedDescription)")
            // Sin esperarlo: sin red el borrado no vuelve hasta que la haya, y
            // quien espera aquí es el botón de «Crear copia». Firestore lo deja
            // en cola; si tampoco llega, lo recoge `borrarPartesHuerfanas`.
            let partes = documentos.partes.count
            Task { try? await self.borrarCopia(id: backupId, partes: partes, en: coleccion) }
            throw error
        }

        logger.info("✅ Backup created successfully: \(backupId)")
        if !documentos.partes.isEmpty {
            logger.info("   - en \(documentos.partes.count) partes (\(documentos.bytes) bytes)")
        }
        logger.info("   - \(expenses.count) expenses")
        logger.info("   - \(categories.count) categories")
        logger.info("   - \(recurring.count) recurring expenses")
        logger.info("   - \(budgets.count) monthly budgets")

        // Actualizar lista + limpiar backups antiguos (máximo 3)
        await loadAvailableBackups()
        await pruneOldBackups(userId: userId)

        return backupId
    }

    /// Elimina backups más antiguos, manteniendo solo los 3 más recientes
    private func pruneOldBackups(userId: String) async {
        let coleccion = backupsCollection(userId)
        do {
            // Del servidor: de esta lista sale también qué partes están
            // huérfanas, y con una caché a medias se borrarían partes buenas.
            let snapshot = try await coleccion
                .order(by: "timestamp", descending: true)
                .getDocuments(source: .server)

            // Las partes no llevan `timestamp` y no salen aquí; el filtro es
            // por si alguna vez lo llevaran.
            let copias = snapshot.documents.filter { !Self.esParte($0.data()) }
            for doc in copias.dropFirst(3) {
                try await borrarCopia(id: doc.documentID, partes: Self.partes(en: doc.data()), en: coleccion)
                logger.debug("🗑️ Backup antiguo eliminado: \(doc.documentID)")
            }

            let vivas = copias.prefix(3)
            await borrarPartesHuerfanas(
                copiasVivas: Set(vivas.map(\.documentID)),
                partesEsperadas: vivas.reduce(0) { $0 + Self.partes(en: $1.data()) },
                en: coleccion
            )
        } catch {
            logger.warning("⚠️ No se pudieron limpiar backups antiguos: \(error.localizedDescription)")
        }
    }

    // MARK: - Partes

    private static func esParte(_ data: [String: Any]) -> Bool {
        data["isBackupPart"] as? Bool == true
    }

    /// Cuántas partes dice tener una copia. Las de un solo documento —todas
    /// las anteriores a este formato— no traen el campo.
    private static func partes(en data: [String: Any]) -> Int {
        max(0, data["partCount"] as? Int ?? 0)
    }

    /// Borra una copia con sus partes, en un solo lote: o desaparece entera o
    /// no desaparece. Borrar un documento que no existe no es un error, así
    /// que sirve igual para una copia que se quedó a medias.
    private func borrarCopia(id: String, partes: Int, en coleccion: CollectionReference) async throws {
        let referencias = [coleccion.document(id)] + (0..<partes).map {
            coleccion.document(BackupChunking.idDeParte(copia: id, indice: $0))
        }
        for lote in referencias.chunked(into: BackupChunking.operacionesPorLote) {
            let batch = db.batch()
            lote.forEach { batch.deleteDocument($0) }
            try await batch.commit()
        }
    }

    /// Recoge las partes de copias que ya no existen (ver
    /// `BackupChunking.partesHuerfanas`).
    ///
    /// Primero se cuentan, que cuesta una lectura: bajarlas para mirarlas es
    /// bajar casi 1 MB por parte, y lo normal es que no sobre ninguna.
    private func borrarPartesHuerfanas(
        copiasVivas: Set<String>,
        partesEsperadas: Int,
        en coleccion: CollectionReference
    ) async {
        do {
            let consulta = coleccion.whereField("isBackupPart", isEqualTo: true)
            let total = try await consulta.count.getAggregation(source: .server).count.intValue
            guard total > partesEsperadas else { return }

            let snapshot = try await consulta.getDocuments(source: .server)
            let guardadas = snapshot.documents.map { doc in
                BackupChunking.ParteGuardada(
                    id: doc.documentID,
                    copia: doc.data()["parentBackupId"] as? String ?? "",
                    creada: (doc.data()["createdAt"] as? Timestamp)?.dateValue()
                )
            }
            let huerfanas = BackupChunking.partesHuerfanas(guardadas, copiasVivas: copiasVivas)
            for lote in huerfanas.chunked(into: BackupChunking.operacionesPorLote) {
                let batch = db.batch()
                lote.forEach { batch.deleteDocument(coleccion.document($0)) }
                try await batch.commit()
            }
            if !huerfanas.isEmpty {
                logger.info("🧹 \(huerfanas.count) partes de copias que ya no existen, borradas")
            }
        } catch {
            logger.warning("⚠️ No se pudieron revisar las partes huérfanas: \(error.localizedDescription)")
        }
    }

    // MARK: - Restore Backup

    /// Restaura un backup específico
    func restoreBackup(backupId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "BackupManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuario no autenticado"])
        }

        isRestoringBackup = true
        defer { isRestoringBackup = false }

        logger.info("🔄 Restoring backup \(backupId)...")

        // 1. Cargar backup desde Firestore
        let coleccion = backupsCollection(userId)
        let doc = try await coleccion.document(backupId).getDocument()

        guard let jsonString = doc.data()?["jsonData"] as? String else {
            throw NSError(domain: "BackupManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Backup no encontrado o formato inválido"])
        }

        // Los dos formatos: las copias de un solo documento no traen
        // `partCount` y todo está en `jsonString`; las que van por partes
        // tienen los gastos en documentos hermanos de id conocido.
        let partesEsperadas = Self.partes(en: doc.data() ?? [:])
        var partes: [Int: String] = [:]
        for indice in 0..<partesEsperadas {
            let id = BackupChunking.idDeParte(copia: backupId, indice: indice)
            let parte = try await coleccion.document(id).getDocument()
            // Si falta, `recomponer` se niega a restaurar a medias.
            if let texto = parte.data()?["jsonData"] as? String { partes[indice] = texto }
        }

        // Propagar errores de decode (antes try? los tragaba sin diagnóstico)
        let backup: UserBackup
        do {
            // Fuera del hilo principal, igual que al crearla.
            let partesLeidas = partes
            backup = try await Task.detached(priority: .userInitiated) {
                try BackupChunking.recomponer(
                    principal: jsonString, partes: partesLeidas, partesEsperadas: partesEsperadas)
            }.value
        } catch let fallo as BackupChunking.Fallo {
            logger.error("Backup \(backupId) incompleto: \(fallo.localizedDescription)")
            throw fallo
        } catch {
            logger.error("Decode backup failed: \(error.localizedDescription)")
            throw NSError(domain: "BackupManager", code: 422,
                          userInfo: [NSLocalizedDescriptionKey: "Backup corrupto: \(error.localizedDescription)"])
        }

        // 1.5. Marcar restore en progreso (permite detectar restores incompletos al re-abrir)
        let userRef = Firestore.firestore().collection("users").document(userId)
        try await userRef.setData(["restoreInProgress": true,
                                   "restoreStartedAt": Timestamp(date: Date())], merge: true)

        do {
            // 2. Restaurar gastos
            logger.info("   Restoring \(backup.expenses.count) expenses...")
            try await restoreExpenses(backup.expenses, userId: userId)

            // 3. Restaurar categorías
            logger.info("   Restoring \(backup.categories.count) categories...")
            try await garantizarMapaDeCategorias(backup.categories, userId: userId)
            for category in backup.categories {
                try await restoreCategory(category, userId: userId)
            }

            // 4. Restaurar gastos recurrentes
            logger.info("   Restoring \(backup.recurringExpenses.count) recurring expenses...")
            for recurring in backup.recurringExpenses {
                try await restoreRecurringExpense(recurring, userId: userId)
            }

            // 5. Restaurar presupuestos mensuales
            logger.info("   Restoring \(backup.monthlyBudgets.count) monthly budgets...")
            for budget in backup.monthlyBudgets {
                try await restoreMonthlyBudget(budget, userId: userId)
            }

            // 6. Restaurar documento de usuario (settings, filters, etc)
            if let userDoc = backup.userDocument {
                logger.info("   Restoring user document...")
                try await restoreUserDocument(userDoc, userId: userId)
            }

            // 7. Limpiar flag de restore exitoso
            try await userRef.updateData([
                "restoreInProgress": FieldValue.delete(),
                "restoreStartedAt": FieldValue.delete()
            ])

            logger.info("✅ Backup restored successfully!")
        } catch {
            // Mantenemos el flag como evidencia de restore fallido (UI puede ofrecer reintentar/limpiar).
            logger.error("❌ Restore aborted: \(error.localizedDescription)")
            throw error
        }

        // 8. Recargar datos en la UI
        await UserDataManager.shared.loadUserData()
    }

    // MARK: - Export/Import JSON

    /// Exporta todos los datos del usuario a un archivo JSON
    func exportToJSON() async throws -> URL {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "BackupManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuario no autenticado"])
        }

        logger.info("📤 Exporting data to JSON...")

        // Crear backup
        let userDoc = UserDataManager.shared.userDocument
        let expenses = try await fetchAllExpenses(userId: userId)
        let categories = UserDataManager.shared.categories
        let recurring = try await fetchRecurringExpenses(userId: userId)
        let budgets = try await fetchMonthlyBudgets(userId: userId)
        let filters = UserDataManager.shared.savedFilters

        let backup = UserBackup(
            userId: userId,
            timestamp: Date(),
            version: "1.0",
            userDocument: userDoc,
            expenses: expenses,
            categories: categories,
            recurringExpenses: recurring.map { RecurringExpenseBackup($0) },
            monthlyBudgets: budgets.map { MonthlyBudgetBackup($0) },
            savedFilters: filters,
            deviceInfo: .init(
                model: UIDevice.current.model,
                systemVersion: UIDevice.current.systemVersion,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            )
        )

        // Archivo temporal. Quien lo comparte lo borra al terminar
        // (`BackupSettingsView`): lleva todos los gastos del usuario en claro.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "Clarity_Backup_\(formatter.string(from: Date())).json"

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        // Convertir a JSON (backup-safe: sin @DocumentID) y escribirlo, fuera
        // del hilo principal: con el historial entero y `prettyPrinted` son
        // varios MB.
        try await Task.detached(priority: .userInitiated) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(backup)
            try jsonData.write(to: fileURL, options: .completeFileProtection)
        }.value

        logger.info("✅ JSON exported to \(fileURL.path)")

        return fileURL
    }

    /// Importa datos desde un archivo JSON
    func importFromJSON(fileURL: URL) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "BackupManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuario no autenticado"])
        }

        logger.info("📥 Importing data from JSON...")

        // Leer y decodificar fuera del hilo principal: es el historial entero.
        // El permiso de acceso al archivo lo abre y lo cierra quien llama, y
        // sigue abierto mientras dura esta espera.
        let backup = try await Task.detached(priority: .userInitiated) {
            let jsonData = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(UserBackup.self, from: jsonData)
        }.value

        // Restaurar datos (mismo proceso que restaurar backup)
        isRestoringBackup = true
        defer { isRestoringBackup = false }

        // Restaurar todos los datos
        try await restoreExpenses(backup.expenses, userId: userId)

        try await garantizarMapaDeCategorias(backup.categories, userId: userId)
        for category in backup.categories {
            try await restoreCategory(category, userId: userId)
        }

        for recurring in backup.recurringExpenses {
            try await restoreRecurringExpense(recurring, userId: userId)
        }

        for budget in backup.monthlyBudgets {
            try await restoreMonthlyBudget(budget, userId: userId)
        }

        if let userDoc = backup.userDocument {
            try await restoreUserDocument(userDoc, userId: userId)
        }

        logger.info("✅ JSON imported successfully!")

        await UserDataManager.shared.loadUserData()
    }

    // MARK: - List Backups

    /// Carga la lista de backups disponibles
    func loadAvailableBackups() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            logger.warning("No authenticated user")
            return
        }

        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("backups")
                .order(by: "timestamp", descending: true)
                .limit(to: 3)
                .getDocuments()

            var backups: [BackupMetadata] = []

            for doc in snapshot.documents {
                // Las partes de una copia no son copias (y sin `timestamp`
                // tampoco deberían salir en esta consulta).
                guard !Self.esParte(doc.data()) else { continue }
                guard let metadataDict = doc.data()["metadata"] as? [String: Any],
                      let id = metadataDict["id"] as? String,
                      let ts = metadataDict["timestamp"] as? Timestamp,
                      let expenseCount = metadataDict["expenseCount"] as? Int,
                      let categoryCount = metadataDict["categoryCount"] as? Int,
                      let size = metadataDict["size"] as? Int
                else { continue }

                backups.append(BackupMetadata(
                    id: id,
                    timestamp: ts.dateValue(),
                    expenseCount: expenseCount,
                    categoryCount: categoryCount,
                    size: size,
                    partCount: Self.partes(en: doc.data())
                ))
            }

            self.availableBackups = backups
            logger.info("✅ Loaded \(backups.count) available backups")
        } catch {
            logger.error("Error loading backups: \(error.localizedDescription)")
        }
    }

    /// Elimina un backup
    func deleteBackup(backupId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "BackupManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuario no autenticado"])
        }

        let coleccion = backupsCollection(userId)
        // Cuántas partes tiene lo sabe la lista; si la copia no está en ella,
        // se le pregunta a su documento.
        let partes: Int
        if let conocida = availableBackups.first(where: { $0.id == backupId }) {
            partes = conocida.partCount
        } else {
            partes = Self.partes(en: try await coleccion.document(backupId).getDocument().data() ?? [:])
        }
        try await borrarCopia(id: backupId, partes: partes, en: coleccion)

        logger.info("🗑️ Deleted backup \(backupId)")

        await loadAvailableBackups()
    }

    // MARK: - Auto Backup

    /// Crea un backup automático si hace más de X días desde el último
    func checkAndCreateAutoBackup(daysSinceLastBackup: Int = 7) async {
        logger.info("🔍 [AutoBackup] Checking if auto-backup is needed...")

        await loadAvailableBackups()
        logger.debug("[AutoBackup] Backups disponibles: \(self.availableBackups.count)")

        guard let lastBackup = availableBackups.first else {
            logger.info("📦 [AutoBackup] No backups found — creating first backup")
            do {
                let id = try await createBackup()
                logger.info("[AutoBackup] ✅ Primer backup creado: \(id)")
            } catch {
                logger.error("❌ [AutoBackup] Error creating first backup: \(error.localizedDescription)")
            }
            return
        }

        let daysSince = Calendar.current.dateComponents([.day], from: lastBackup.timestamp, to: Date()).day ?? 0
        logger.info("📅 [AutoBackup] Last backup was \(daysSince) day(s) ago (threshold: \(daysSinceLastBackup))")

        if daysSince >= daysSinceLastBackup {
            logger.info("⏳ [AutoBackup] Threshold reached — creating auto-backup")
            do {
                let id = try await createBackup()
                logger.info("[AutoBackup] ✅ Auto-backup creado: \(id)")
            } catch {
                logger.error("❌ [AutoBackup] Error: \(error.localizedDescription)")
            }
        } else {
            logger.debug("[AutoBackup] ✅ Backup reciente, no hace falta crear uno nuevo")
        }
    }

    // MARK: - Private Helpers

    /// Reintenta una operación async hasta `maxAttempts` veces con backoff exponencial.
    /// Útil para errores de red transitorios (WatchStream / Network connectivity changed).
    private func withRetry<T>(
        maxAttempts: Int = 3,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                let isNetworkError = (error as NSError).domain == "FIRFirestoreErrorDomain"
                    || error.localizedDescription.lowercased().contains("network")
                    || error.localizedDescription.lowercased().contains("unavailable")
                guard isNetworkError, attempt < maxAttempts - 1 else { break }
                let delayNs = UInt64(pow(2.0, Double(attempt))) * 500_000_000  // 0.5s, 1s, 2s
                logger.warning("Reintento \(attempt + 1) tras error de red: \(error.localizedDescription)")
                try? await Task.sleep(nanoseconds: delayNs)
            }
        }
        throw lastError!
    }

    // Las tres lecturas de la copia van solo contra el servidor. Sin red,
    // Firestore contesta desde su caché sin dar error —puede que con un mes
    // suelto— y eso se guardaba como copia completa. Ahora falla, se reintenta
    // y la copia automática lo vuelve a probar en el siguiente arranque.
    private func fetchAllExpenses(userId: String) async throws -> [Expense] {
        try await withRetry {
            let snapshot = try await self.db.collection("users")
                .document(userId)
                .collection("expenses")
                .getDocuments(source: .server)
            // Con el DTO y el id del documento, como el resto de la app: `Expense`
            // no lleva `@DocumentID` y el documento no guarda el id, así que
            // decodificado a pelo salía con `id == nil` y `restoreExpense` lo
            // descartaba: la copia no recuperaba ni un gasto.
            return snapshot.documents.compactMap { doc -> Expense? in
                do {
                    return try doc.data(as: ExpenseDTO.self).toDomain(id: doc.documentID)
                } catch {
                    self.logger.error("Backup: gasto \(doc.documentID) no decodificable: \(error.localizedDescription)")
                    return nil
                }
            }
        }
    }

    private func fetchRecurringExpenses(userId: String) async throws -> [RecurringExpense] {
        try await withRetry {
            let snapshot = try await self.db.collection("users")
                .document(userId)
                .collection("recurringExpenses")
                .getDocuments(source: .server)
            return snapshot.documents.compactMap { try? $0.data(as: RecurringExpense.self) }
        }
    }

    private func fetchMonthlyBudgets(userId: String) async throws -> [MonthlyBudget] {
        try await withRetry {
            let snapshot = try await self.db.collection("users")
                .document(userId)
                // `monthly_budgets`, como `FinancialService`. Aquí ponía
                // `monthlyBudgets`, que no existe: las copias no guardaban
                // ningún presupuesto.
                .collection("monthly_budgets")
                .getDocuments(source: .server)
            return snapshot.documents.compactMap { try? $0.data(as: MonthlyBudget.self) }
        }
    }

    /// Restaura los gastos en lotes. Antes era un `await setData` por gasto,
    /// en serie: con 3.000 gastos, 3.000 viajes de ida y vuelta.
    private func restoreExpenses(_ expenses: [Expense], userId: String) async throws {
        let lotes = BackupChunking.lotes(de: expenses)
        guard !lotes.isEmpty else { return }

        // Se escriben en Firestore por fuera del repositorio y pueden ser de
        // cualquier año. La sincronización de fondo solo baja una ventana
        // reciente: sin esto, los antiguos no entrarían en la caché local
        // hasta la completa semanal. También si falla a medias: los lotes ya
        // confirmados están escritos.
        defer { ExpenseSyncPolicy.olvidarMarcas() }

        let coleccion = db.collection("users").document(userId).collection("expenses")
        for lote in lotes {
            let batch = db.batch()
            for expense in lote {
                guard let id = expense.id else { continue }
                let data = try Firestore.Encoder().encode(expense)
                batch.setData(data, forDocument: coleccion.document(id), merge: true)
            }
            try await batch.commit()
        }
    }

    /// Regla de `architecture.md`: no se escribe una entrada del mapa sin que el
    /// mapa entero esté persistido. Si el documento no tiene mapa (cuenta nueva,
    /// dispositivo nuevo) y la restauración se cortaba a medias, quedaba un mapa
    /// parcial que además impedía la siembra de después. Con esto, si falta se
    /// siembra completo con las categorías de la copia; si ya existe, no hace
    /// nada. De paso crea el documento, que `updateData` exige.
    private func garantizarMapaDeCategorias(_ categories: [Category], userId: String) async throws {
        guard !categories.isEmpty else { return }
        try await UserDataService.shared.persistCategoriesIfMissing(categories, userId: userId)
    }

    private func restoreCategory(_ category: Category, userId: String) async throws {
        guard let id = category.id else { return }

        let categoryData: [String: Any] = [
            "name": category.name,
            "color": category.color,
            "subcategories": category.subcategories,
        ]

        try await db.collection("users")
            .document(userId)
            .updateData([
                // FieldPath: ids de defaults llevan emoji, dot-path string no es fiable
                FieldPath(["categories", id]): categoryData,
                "categoriesVersion": UUID().uuidString,
                "categoriesUpdatedAt": FieldValue.serverTimestamp(),
            ])
    }

    private func restoreRecurringExpense(_ backup: RecurringExpenseBackup, userId: String) async throws {
        guard let id = backup.id else { return }
        // Convertir de vuelta al modelo real para que Firestore.Encoder funcione correctamente
        let model = backup.toRecurringExpense()
        let data = try Firestore.Encoder().encode(model)
        try await db.collection("users")
            .document(userId)
            .collection("recurringExpenses")
            .document(id)
            .setData(data, merge: true)
    }

    private func restoreMonthlyBudget(_ backup: MonthlyBudgetBackup, userId: String) async throws {
        let model = backup.toMonthlyBudget()
        let docId = backup.id ?? MonthlyBudget.generateDocumentId(
            userId: userId, year: backup.year, month: backup.month
        )
        let data = try Firestore.Encoder().encode(model)
        try await db.collection("users")
            .document(userId)
            .collection("monthly_budgets")
            .document(docId)
            .setData(data, merge: true)
    }

    private func restoreUserDocument(_ userDoc: UserDocument, userId: String) async throws {
        let data = try Firestore.Encoder().encode(userDoc)
        try await db.collection("users")
            .document(userId)
            .setData(data, merge: true)
    }
}
