
import FirebaseAuth
import FirebaseFirestore
// RecurringExpenseRepository.swift
import Foundation
import OSLog

class RecurringExpenseRepository {
    private let logger = Logger(subsystem: "com.idanidev.clarity", category: "RecurringExpenseRepository")
    private let db = Firestore.firestore()

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    private var collection: CollectionReference? {
        guard let userId = userId else { return nil }
        return db.collection("users").document(userId).collection("recurringExpenses")
    }

    /// Las reglas, un minuto en memoria. Al cargar las piden casi a la vez la
    /// Home, Metas, las gráficas, el gestor de recurrentes y la caché de voz:
    /// eran siete consultas seguidas para lo mismo (y con la colección vacía
    /// cada una llega al servidor). Toda escritura de este repositorio la
    /// invalida, así que quien lea después de escribir ve lo escrito.
    private let cache = CacheConCaducidad<[RecurringExpense]>(ttl: 60)

    func fetchAll() async throws -> [RecurringExpense] {
        guard let userId else {
            throw RepositoryError.notAuthenticated
        }
        return try await cache.valor(para: userId) { try await self.fetchAllSinCache() }
    }

    /// Margen antes de dar por perdida la lectura de las reglas. El mismo que
    /// `ExpenseRepository`.
    private static let remoteReadTimeout: TimeInterval = 8

    /// Al cerrar sesión o cambiar de usuario.
    func vaciarCache() {
        cache.vaciar()
    }

    private func fetchAllSinCache() async throws -> [RecurringExpense] {
        guard let collection = collection else {
            throw RepositoryError.notAuthenticated
        }
        // Cache-first: serve from disk instantly, fallback to server (también si cache vacío)
        //
        // Con tope de espera (#32). Envuelve el bloque entero, no cada lectura:
        // así el tiempo agotado sale de aquí como cualquier error de red, en vez
        // de caer en el `catch` de dentro y lanzar otra lectura al servidor.
        // Quien llama ya trata el error: nunca se convierte en «no hay reglas».
        let query = collection.order(by: "dayOfMonth")
        let snapshot = try await withTimeout(Self.remoteReadTimeout) {
            do {
                let cached = try await query.getDocuments(source: .cache)
                return cached.isEmpty ? try await query.getDocuments(source: .server) : cached
            } catch {
                return try await query.getDocuments(source: .server)
            }
        }
        var results: [RecurringExpense] = []
        for doc in snapshot.documents {
            do {
                let expense = try doc.data(as: RecurringExpense.self)
                results.append(expense)
            } catch {
                logger.warning("⚠️ Failed to decode document \(doc.documentID): \(error)")
            }
        }
        logger.debug("📋 Loaded \(results.count) recurring expenses (\(results.filter { $0.active }.count) active, \(results.filter { !$0.active }.count) paused)")
        return results
    }

    // Las escrituras invalidan la caché al empezar y al terminar. Al empezar,
    // porque Firestore aplica el cambio en local antes de que vuelva el
    // `await`; al terminar —también si falla—, para que una lectura hecha a
    // mitad no se quede guardada como buena.

    func add(_ expense: RecurringExpense) async throws -> String {
        guard let collection = collection else {
            throw RepositoryError.notAuthenticated
        }
        cache.invalidar()
        defer { cache.invalidar() }
        let docRef = try await collection.addDocument(from: expense)
        return docRef.documentID
    }

    func update(_ expense: RecurringExpense) async throws {
        guard let collection = collection, let id = expense.id else {
            throw RepositoryError.notAuthenticated
        }
        cache.invalidar()
        defer { cache.invalidar() }
        try await collection.document(id).setData(from: expense, merge: true)
    }

    func toggleActive(id: String, active: Bool) async throws {
        guard let collection = collection else {
            throw RepositoryError.notAuthenticated
        }
        cache.invalidar()
        defer { cache.invalidar() }
        try await collection.document(id).updateData([
            "active": active,
            "updatedAt": FieldValue.serverTimestamp(),
        ])
    }

    func delete(id: String) async throws {
        guard let collection = collection else {
            throw RepositoryError.notAuthenticated
        }
        cache.invalidar()
        defer { cache.invalidar() }
        try await collection.document(id).delete()
    }
}
