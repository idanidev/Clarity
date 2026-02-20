// BackupManager.swift
// Sistema de backup y restauración completo para datos de usuario

import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog
import SwiftUI

/// Representa un backup completo del usuario
struct UserBackup: Codable {
    let userId: String
    let timestamp: Date
    let version: String

    // Datos del usuario
    let userDocument: UserDocument?
    let expenses: [Expense]
    let categories: [Category]
    let recurringExpenses: [RecurringExpense]
    let monthlyBudgets: [MonthlyBudget]
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
        let backup = UserBackup(
            userId: userId,
            timestamp: Date(),
            version: "1.0",
            userDocument: userDoc,
            expenses: expenses,
            categories: categories,
            recurringExpenses: recurring,
            monthlyBudgets: budgets,
            savedFilters: filters,
            deviceInfo: .init(
                model: UIDevice.current.model,
                systemVersion: UIDevice.current.systemVersion,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            )
        )

        // 3. Guardar en Firestore (colección backups)
        let backupId = UUID().uuidString
        let backupData = try Firestore.Encoder().encode(backup)

        try await db.collection("users")
            .document(userId)
            .collection("backups")
            .document(backupId)
            .setData(backupData)

        // 4. Guardar metadata
        let metadata = BackupMetadata(
            id: backupId,
            timestamp: backup.timestamp,
            expenseCount: expenses.count,
            categoryCount: categories.count,
            size: try JSONEncoder().encode(backup).count
        )

        try await db.collection("users")
            .document(userId)
            .collection("backups")
            .document(backupId)
            .setData(["metadata": try Firestore.Encoder().encode(metadata)], merge: true)

        logger.info("✅ Backup created successfully: \(backupId)")
        logger.info("   - \(expenses.count) expenses")
        logger.info("   - \(categories.count) categories")
        logger.info("   - \(recurring.count) recurring expenses")
        logger.info("   - \(budgets.count) monthly budgets")

        // Actualizar lista de backups disponibles
        await loadAvailableBackups()

        return backupId
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

        guard let backup = try? doc.data(as: UserBackup.self) else {
            throw NSError(domain: "BackupManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Backup no encontrado"])
        }

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

        logger.info("✅ Backup restored successfully!")

        // 7. Recargar datos en la UI
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
            recurringExpenses: recurring,
            monthlyBudgets: budgets,
            savedFilters: filters,
            deviceInfo: .init(
                model: UIDevice.current.model,
                systemVersion: UIDevice.current.systemVersion,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            )
        )

        // Convertir a JSON
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

        try jsonData.write(to: fileURL)

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
                .limit(to: 10)
                .getDocuments()

            var backups: [BackupMetadata] = []

            for doc in snapshot.documents {
                if let metadataDict = doc.data()["metadata"] as? [String: Any],
                   let metadata = try? Firestore.Decoder().decode(BackupMetadata.self, from: metadataDict) {
                    backups.append(metadata)
                }
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
        await loadAvailableBackups()

        guard let lastBackup = availableBackups.first else {
            // No hay backups, crear uno
            logger.info("No backups found, creating first auto-backup...")
            try? await createBackup()
            return
        }

        let daysSince = Calendar.current.dateComponents([.day], from: lastBackup.timestamp, to: Date()).day ?? 0

        if daysSince >= daysSinceLastBackup {
            logger.info("Last backup was \(daysSince) days ago, creating auto-backup...")
            try? await createBackup()
        }
    }

    // MARK: - Private Helpers

    private func fetchAllExpenses(userId: String) async throws -> [Expense] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("expenses")
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Expense.self) }
    }

    private func fetchRecurringExpenses(userId: String) async throws -> [RecurringExpense] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("recurringExpenses")
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: RecurringExpense.self) }
    }

    private func fetchMonthlyBudgets(userId: String) async throws -> [MonthlyBudget] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("monthlyBudgets")
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: MonthlyBudget.self) }
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
                "categories.\(id)": categoryData,
                "categoriesVersion": UUID().uuidString,
                "categoriesUpdatedAt": FieldValue.serverTimestamp(),
            ])
    }

    private func restoreRecurringExpense(_ recurring: RecurringExpense, userId: String) async throws {
        guard let id = recurring.id else { return }

        let data = try Firestore.Encoder().encode(recurring)
        try await db.collection("users")
            .document(userId)
            .collection("recurringExpenses")
            .document(id)
            .setData(data, merge: true)
    }

    private func restoreMonthlyBudget(_ budget: MonthlyBudget, userId: String) async throws {
        let data = try Firestore.Encoder().encode(budget)
        try await db.collection("users")
            .document(userId)
            .collection("monthlyBudgets")
            .document(budget.id)
            .setData(data, merge: true)
    }

    private func restoreUserDocument(_ userDoc: UserDocument, userId: String) async throws {
        let data = try Firestore.Encoder().encode(userDoc)
        try await db.collection("users")
            .document(userId)
            .setData(data, merge: true)
    }
}
