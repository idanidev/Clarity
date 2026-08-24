// DefaultFilterPersistenceTests.swift
// El filtro predeterminado desaparecía al cerrar la app (#53).
//
// Vivía solo en memoria y en Firestore: si el write remoto no llegaba —sin
// cobertura, o cerrando la app justo después de marcar la estrella— al volver
// a abrir no estaba. Estos tests fijan el espejo local, que es lo que
// sobrevive al cierre.

import Testing
import Foundation
@testable import Clarity

@Suite("Filtro predeterminado", .serialized)
@MainActor
struct DefaultFilterPersistenceTests {

    private static let uid = "test-uid-filtros"

    private func makeSUT() -> UserDataManager {
        // Sin documento de usuario a propósito: es el caso en el que antes se
        // salía por el `guard` sin guardar nada y sin avisar.
        UserDefaults.standard.removeObject(forKey: "filters.default.\(Self.uid)")
        return UserDataManager(service: MockUserDataStore(), userIdProvider: { Self.uid })
    }

    private func filtro(_ nombre: String) -> ExpenseFilter {
        ExpenseFilter(
            name: nombre,
            selectedCategories: ["Ocio🍻"],
            dateRange: .lastMonth,
            minAmount: 10,
            sortBy: .amountDesc
        )
    }

    @Test("se guarda aunque el documento de usuario aún no haya cargado")
    func savesWithoutUserDocument() {
        let sut = makeSUT()
        #expect(sut.userDocument == nil)

        let guardado = sut.saveDefaultFilter(filtro("Ocio caro"))

        #expect(guardado)
        #expect(sut.defaultFilter?.name == "Ocio caro")
    }

    @Test("sobrevive a cerrar la app: se recupera del espejo local")
    func survivesRelaunch() {
        let sut = makeSUT()
        sut.saveDefaultFilter(filtro("Mes pasado"))

        // Una instancia nueva es lo más parecido a reabrir la app: memoria
        // vacía, sin documento remoto todavía.
        let trasReiniciar = UserDataManager(
            service: MockUserDataStore(), userIdProvider: { Self.uid })

        #expect(trasReiniciar.userDocument == nil)
        #expect(trasReiniciar.defaultFilter?.name == "Mes pasado")
    }

    @Test("conserva los ajustes del filtro, no solo el nombre")
    func keepsFilterContents() {
        let sut = makeSUT()
        sut.saveDefaultFilter(filtro("Completo"))

        let recuperado = UserDataManager(
            service: MockUserDataStore(), userIdProvider: { Self.uid }
        ).defaultFilter

        #expect(recuperado?.dateRange == .lastMonth)
        #expect(recuperado?.selectedCategories == ["Ocio🍻"])
        #expect(recuperado?.minAmount == 10)
        #expect(recuperado?.sortBy == .amountDesc)
    }

    @Test("el espejo es por usuario: otra cuenta no hereda el filtro")
    func isolatedPerUser() {
        let sut = makeSUT()
        sut.saveDefaultFilter(filtro("Mío"))

        let otroUsuario = UserDataManager(
            service: MockUserDataStore(), userIdProvider: { "otro-uid" })

        #expect(otroUsuario.defaultFilter == nil)
    }

    @Test("sin usuario no guarda y lo dice")
    func failsWithoutUser() {
        let sinSesion = UserDataManager(
            service: MockUserDataStore(), userIdProvider: { nil })

        #expect(sinSesion.saveDefaultFilter(filtro("Nadie")) == false)
        #expect(sinSesion.defaultFilter == nil)
    }

    @Test("el documento remoto manda sobre el espejo local")
    func remoteWins() {
        let sut = makeSUT()
        sut.saveDefaultFilter(filtro("Local"))

        var settings = UserSettings.default
        settings.defaultFilter = filtro("Remoto")
        sut.userDocument = UserDocument(
            email: "a@b.c", displayName: "Test", role: "user",
            createdAt: Date(), settings: settings)

        #expect(sut.defaultFilter?.name == "Remoto")
    }
}
