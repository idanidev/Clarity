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

    // Estos tests escribían en el Firestore real: `saveDefaultFilter` llamaba a
    // `Firestore.firestore()` sin pasar por el almacén inyectado, y cada pasada
    // dejaba «Write at users/test-uid-filtros failed: Missing or insufficient
    // permissions». Ahora la escritura remota es un requisito de
    // `UserDataStore` y aquí se comprueba que llega al doble y a nadie más.
    @Test("la escritura remota pasa por el almacén inyectado")
    func remoteWriteGoesThroughStore() async throws {
        UserDefaults.standard.removeObject(forKey: "filters.default.\(Self.uid)")
        let store = MockUserDataStore()
        let sut = UserDataManager(service: store, userIdProvider: { Self.uid })

        sut.saveDefaultFilter(filtro("Por el doble"))

        // Va en un `Task` suelto (el guardado local no espera a la red): se le
        // da turno con un tope corto en vez de dormir un tiempo fijo.
        for _ in 0..<100 where store.savedDefaultFilters.isEmpty {
            try await Task.sleep(for: .milliseconds(5))
        }

        let escrito = try #require(store.savedDefaultFilters.first)
        #expect(store.savedDefaultFilters.count == 1)
        #expect(escrito.userId == Self.uid)
        #expect(escrito.filter.name == "Por el doble")
        #expect(escrito.filter.minAmount == 10)
    }

    @Test("sin usuario no se intenta la escritura remota")
    func noRemoteWriteWithoutUser() async {
        let store = MockUserDataStore()
        let sinSesion = UserDataManager(service: store, userIdProvider: { nil })

        sinSesion.saveDefaultFilter(filtro("Nadie"))
        await Task.yield()

        #expect(store.recordedCalls.isEmpty)
    }
}

// MARK: - Regresión: el documento llega después que la Home
//
// Al soltar la interfaz antes de leer el documento de usuario (#32), la Home
// pasó a construirse sin filtros disponibles. Marcar entonces "ya aplicado"
// dejaba el filtro predeterminado sin aplicar durante toda la sesión, y el
// usuario lo veía como que se le borraba al cerrar la app.

@Suite("Filtro predeterminado · carga tardía", .serialized)
@MainActor
struct DefaultFilterLateLoadTests {

    private static let uid = "test-uid-tardio"

    private func makeManager() -> UserDataManager {
        UserDefaults.standard.removeObject(forKey: "filters.default.\(Self.uid)")
        return UserDataManager(service: MockUserDataStore(), userIdProvider: { Self.uid })
    }

    private func filtroGuardado(_ nombre: String) -> ExpenseFilter {
        ExpenseFilter(name: nombre, dateRange: .lastMonth)
    }

    @Test("al llegar el documento se siembra el espejo local")
    func seedsMirrorWhenDocumentArrives() {
        let manager = makeManager()
        #expect(manager.defaultFilter == nil)

        var settings = UserSettings.default
        settings.defaultFilter = filtroGuardado("Del servidor")
        manager.setUserDocument(UserDocument(
            email: "a@b.c", displayName: "Test", role: "user",
            createdAt: Date(), settings: settings))

        // Una instancia nueva —equivalente a reabrir la app— ya lo tiene sin
        // depender de que Firestore conteste a tiempo.
        let trasReiniciar = UserDataManager(
            service: MockUserDataStore(), userIdProvider: { Self.uid })
        #expect(trasReiniciar.defaultFilter?.name == "Del servidor")
    }

    @Test("el espejo local no se pisa con lo que traiga el documento")
    func doesNotOverwriteExistingMirror() {
        let manager = makeManager()
        manager.saveDefaultFilter(filtroGuardado("Elegido hace un momento"))

        var settings = UserSettings.default
        settings.defaultFilter = filtroGuardado("Versión vieja del servidor")
        manager.setUserDocument(UserDocument(
            email: "a@b.c", displayName: "Test", role: "user",
            createdAt: Date(), settings: settings))

        let trasReiniciar = UserDataManager(
            service: MockUserDataStore(), userIdProvider: { Self.uid })
        #expect(trasReiniciar.defaultFilter?.name == "Elegido hace un momento")
    }

    @Test("sin filtro predeterminado no se siembra nada")
    func noMirrorWhenNoDefault() {
        let manager = makeManager()
        manager.setUserDocument(UserDocument(
            email: "a@b.c", displayName: "Test", role: "user",
            createdAt: Date(), settings: .default))

        let trasReiniciar = UserDataManager(
            service: MockUserDataStore(), userIdProvider: { Self.uid })
        #expect(trasReiniciar.defaultFilter == nil)
    }
}
