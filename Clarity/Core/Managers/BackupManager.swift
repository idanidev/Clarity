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

struct RecurringExpenseBackup: Codable {
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

struct MonthlyBudgetBackup: Codable {
    var id: String?   // documentId (sin @DocumentID wrapper)
    var userId: String
    var year: Int
    var month: Int
    var income: Double
    var currency: String
    var savingsAllocated: Double
    var createdAt: Date
    var updatedAt: Date

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
struct UserBackup: Codable {
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

    struct DeviceInfo: Codable {
        let model: String
        let systemVersion: String
        let appVersion: String
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
        let backupId = UUID().uuidString
        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .secondsSince1970
        let jsonData = try jsonEncoder.encode(backup)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(domain: "BackupManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Error serializando backup a JSON"])
        }

        // 4. Guardar datos + metadata en un único setData (plain [String: Any] para evitar FirestoreEncodingError)
        let firestoreData: [String: Any] = [
            "jsonData": jsonString,
            "version": backup.version,
            "userId": backup.userId,
            "timestamp": Timestamp(date: backup.timestamp),  // raíz para poder ordenar por él
            "metadata": [
                "id": backupId,
                "timestamp": Timestamp(date: backup.timestamp),
                "expenseCount": expenses.count,
                "categoryCount": categories.count,
                "size": jsonData.count
            ] as [String: Any]
        ]

        try await withRetry {
            try await self.db.collection("users")
                .document(userId)
                .collection("backups")
                .document(backupId)
                .setData(firestoreData)
        }

        logger.info("✅ Backup created successfully: \(backupId)")
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
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("backups")
                .order(by: "timestamp", descending: true)
                .getDocuments()

            let toDelete = snapshot.documents.dropFirst(3)
            for doc in toDelete {
                try await db.collection("users")
                    .document(userId)
                    .collection("backups")
                    .document(doc.documentID)
                    .delete()
                logger.debug("🗑️ Backup antiguo eliminado: \(doc.documentID)")
            }
        } catch {
            logger.warning("⚠️ No se pudieron limpiar backups antiguos: \(error.localizedDescription)")
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
        let doc = try await db.collection("users")
            .document(userId)
            .collection("backups")
            .document(backupId)
            .getDocument()

        guard let jsonString = doc.data()?["jsonData"] as? String,
              let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "BackupManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Backup no encontrado o formato inválido"])
        }
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .secondsSince1970
        // Propagar errores de decode (antes try? los tragaba sin diagnóstico)
        let backup: UserBackup
        do {
            backup = try jsonDecoder.decode(UserBackup.self, from: jsonData)
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
            for expense in backup.expenses {
                try await restoreExpense(expense, userId: userId)
            }

            // 3. Restaurar categorías
            logger.info("   Restoring \(backup.categories.count) categories...")
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

        // Convertir a JSON (backup-safe: sin @DocumentID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(backup)

        // Guardar en archivo temporal
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "Clarity_Backup_\(formatter.string(from: Date())).json"

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        try jsonData.write(to: fileURL, options: .completeFileProtection)

        logger.info("✅ JSON exported to \(fileURL.path)")

        return fileURL
    }

    /// Importa datos desde un archivo JSON
    func importFromJSON(fileURL: URL) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "BackupManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuario no autenticado"])
        }

        logger.info("📥 Importing data from JSON...")

        // Leer archivo
        let jsonData = try Data(contentsOf: fileURL)

        // Decodificar
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(UserBackup.self, from: jsonData)

        // Restaurar datos (mismo proceso que restaurar backup)
        isRestoringBackup = true
        defer { isRestoringBackup = false }

        // Restaurar todos los datos
        for expense in backup.expenses {
            try await restoreExpense(expense, userId: userId)
        }

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
                    size: size
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

        try await db.collection("users")
            .document(userId)
            .collection("backups")
            .document(backupId)
            .delete()

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

    private func fetchAllExpenses(userId: String) async throws -> [Expense] {
        try await withRetry {
            let snapshot = try await self.db.collection("users")
                .document(userId)
                .collection("expenses")
                .getDocuments(source: .default)
            return snapshot.documents.compactMap { try? $0.data(as: Expense.self) }
        }
    }

    private func fetchRecurringExpenses(userId: String) async throws -> [RecurringExpense] {
        try await withRetry {
            let snapshot = try await self.db.collection("users")
                .document(userId)
                .collection("recurringExpenses")
                .getDocuments(source: .default)
            return snapshot.documents.compactMap { try? $0.data(as: RecurringExpense.self) }
        }
    }

    private func fetchMonthlyBudgets(userId: String) async throws -> [MonthlyBudget] {
        try await withRetry {
            let snapshot = try await self.db.collection("users")
                .document(userId)
                .collection("monthlyBudgets")
                .getDocuments(source: .default)
            return snapshot.documents.compactMap { try? $0.data(as: MonthlyBudget.self) }
        }
    }

    private func restoreExpense(_ expense: Expense, userId: String) async throws {
        guard let id = expense.id else { return }

        let data = try Firestore.Encoder().encode(expense)
        try await db.collection("users")
            .document(userId)
            .collection("expenses")
            .document(id)
            .setData(data, merge: true)
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
            .collection("monthlyBudgets")
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
