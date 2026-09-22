// HomeDisposicionSyncTests.swift
// Dónde se guarda la Home editable (2.4.0): al momento en el iPhone, al poco
// en la cuenta, y al llegar el documento gana la más reciente. Con almacén en
// memoria y el mock de `UserDataStore`: ni UserDefaults del usuario ni Firestore.

import Testing
import Foundation
@testable import Clarity

@Suite("Disposición de la Home: iPhone y cuenta", .serialized)
@MainActor
struct HomeDisposicionSyncTests {

    /// Lo que harían UserDefaults y la cuenta, apuntado.
    final class AlmacenFalso {
        var local: HomeDisposicion
        var guardadas: [HomeDisposicion] = []
        var documentoCargado: Bool
        var remota: HomeDisposicion?
        var subidas: [HomeDisposicion] = []

        init(local: HomeDisposicion = .porDefecto, remota: HomeDisposicion? = nil, documentoCargado: Bool = true) {
            self.local = local
            self.remota = remota
            self.documentoCargado = documentoCargado
        }

        var almacen: HomeDisposicionAlmacen {
            HomeDisposicionAlmacen(
                cargarLocal: { self.local },
                guardarLocal: { self.local = $0; self.guardadas.append($0) },
                documentoCargado: { self.documentoCargado },
                remota: { self.remota },
                subir: { self.subidas.append($0) }
            )
        }
    }

    private let ahora = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeSUT(_ falso: AlmacenFalso) -> HomeViewModel {
        let repo = MockExpenseRepository()
        let vm = HomeViewModel(
            getExpensesUseCase: GetExpensesUseCase(repository: repo),
            deleteExpenseUseCase: DeleteExpenseUseCase(repository: repo),
            addExpenseUseCase: AddExpenseUseCase(repository: repo),
            almacenDisposicion: falso.almacen
        )
        vm.reloj = { self.ahora }
        vm.esperaSubida = .zero
        return vm
    }

    @Test("Arranca con la copia del iPhone")
    func arrancaConLaLocal() {
        var local = HomeDisposicion.porDefecto
        local.quitar("pila-e")
        let vm = makeSUT(AlmacenFalso(local: local))
        #expect(vm.disposicion == local)
    }

    @Test("Un cambio se sella, se guarda en el iPhone al momento y sube a la cuenta")
    func cambioSeGuardaYSube() async {
        let falso = AlmacenFalso()
        let vm = makeSUT(falso)
        vm.quitarTarjeta("pila-e")
        #expect(vm.disposicion.actualizada == ahora)
        #expect(falso.guardadas.last == vm.disposicion)
        await vm.subidaPendiente?.value
        #expect(falso.subidas == [vm.disposicion])
    }

    @Test("Lo que no cambia nada ni se sella ni se sube")
    func sinCambiosNoSeGuarda() async {
        let falso = AlmacenFalso()
        let vm = makeSUT(falso)
        vm.cambiarTamano("ultimos", a: .pequena)
        vm.quitarTarjeta("no-existe")
        vm.devolverAPila("racha")
        #expect(vm.disposicion == .porDefecto)
        #expect(falso.guardadas.isEmpty)
        #expect(vm.subidaPendiente == nil)
    }

    @Test("Varios cambios seguidos son una sola escritura en la cuenta, con el último estado")
    func variosCambiosUnaSubida() async {
        let falso = AlmacenFalso()
        let vm = makeSUT(falso)
        vm.esperaSubida = .milliseconds(80)
        vm.quitarTarjeta("pila-e")
        vm.noEnsenarEnPila("racha")
        vm.anadirTarjeta(.clase("hucha"), tamano: .pequena)
        await vm.subidaPendiente?.value
        #expect(falso.guardadas.count == 3)
        #expect(falso.subidas.count == 1)
        #expect(falso.subidas.first == vm.disposicion)
        #expect(vm.disposicion.elementos.first?.tipo == .clase("hucha"))
    }

    @Test("Al llegar el documento, si la de la cuenta es más reciente, manda esa y no se sube nada")
    func ganaLaRemota() async {
        var remota = HomeDisposicion.porDefecto
        remota.quitar("pila-a")
        remota.actualizada = ahora
        let falso = AlmacenFalso(remota: remota)
        let vm = makeSUT(falso)
        vm.sincronizarDisposicion()
        #expect(vm.disposicion == remota)
        #expect(falso.local == remota)
        #expect(vm.subidaPendiente == nil)
        #expect(falso.subidas.isEmpty)
    }

    @Test("Si la del iPhone es más reciente (se editó sin cobertura), se sube")
    func subeLaLocal() async {
        var local = HomeDisposicion.porDefecto
        local.quitar("pila-a")
        local.actualizada = ahora
        var remota = HomeDisposicion.porDefecto
        remota.actualizada = ahora.addingTimeInterval(-3_600)
        let falso = AlmacenFalso(local: local, remota: remota)
        let vm = makeSUT(falso)
        vm.sincronizarDisposicion()
        await vm.subidaPendiente?.value
        #expect(vm.disposicion == local)
        #expect(falso.subidas == [local])
    }

    @Test("Sin documento todavía no se decide nada ni se sube: podría pisar una más reciente")
    func sinDocumentoNoSeSube() {
        var local = HomeDisposicion.porDefecto
        local.actualizada = ahora
        let falso = AlmacenFalso(local: local, documentoCargado: false)
        let vm = makeSUT(falso)
        vm.sincronizarDisposicion()
        #expect(vm.subidaPendiente == nil)
    }

    @Test("La Home de quien nunca editó no se sube aunque la cuenta no tenga ninguna")
    func nuncaEditadaNoSube() {
        let vm = makeSUT(AlmacenFalso())
        vm.sincronizarDisposicion()
        #expect(vm.subidaPendiente == nil)
    }

    @Test("Las tarjetas de la Home siguen a la disposición: lo quitado deja de salir")
    func tarjetasSiguenALaDisposicion() {
        let vm = makeSUT(AlmacenFalso())
        // Sin el filtro predeterminado del usuario del simulador, que podría dejar fuera el gasto.
        vm.selectedFilter = ExpenseFilter(dateRange: .thisMonth)
        vm.currentMonthExpenses = [Expense(id: "1", amount: 12, name: "Pan", category: "Alimentación",
                                           date: Formatters.localDayString(from: Date()))]
        #expect(vm.tarjetasHome.map(\.id).contains("ultimos"))
        #expect(vm.filasHome.flatMap { $0 }.map(\.id).contains("ultimos"))
        vm.quitarTarjeta("ultimos")
        #expect(!vm.tarjetasHome.map(\.id).contains("ultimos"))
    }

    // MARK: - UserDataManager

    @Test("UserDataManager sube por el store, sin tocar categorías, y deja la copia en el documento")
    func userDataManagerSube() async {
        let store = MockUserDataStore()
        let manager = UserDataManager(service: store, userIdProvider: { "test-uid-home" })
        manager.userDocument = UserDocument(displayName: "Prueba")
        var d = HomeDisposicion.porDefecto
        d.actualizada = ahora

        let subida = await manager.saveHomeDisposicion(d)

        #expect(subida)
        #expect(store.recordedCalls == ["saveHomeDisposicion(5)"])
        #expect(store.savedHomeDisposiciones.first?.userId == "test-uid-home")
        #expect(store.savedHomeDisposiciones.first?.disposicion == d)
        #expect(manager.homeDisposicion == d)
    }

    @Test("Sin sesión no se sube nada; si la escritura falla, se dice")
    func userDataManagerSinSesionOFallo() async {
        let store = MockUserDataStore()
        let sinSesion = UserDataManager(service: store, userIdProvider: { nil })
        #expect(await sinSesion.saveHomeDisposicion(.porDefecto) == false)
        #expect(store.recordedCalls.isEmpty)

        store.shouldFailSaveHomeDisposicion = true
        let conSesion = UserDataManager(service: store, userIdProvider: { "test-uid-home" })
        #expect(await conSesion.saveHomeDisposicion(.porDefecto) == false)
    }
}
