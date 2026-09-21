// BackupChunkingTests.swift
// La copia por partes: que ningún documento pase del límite de Firestore, que
// lo partido se recomponga igual, y que las copias antiguas —todo en un
// documento— se sigan leyendo. Lógica pura: aquí no hay Firestore.

import Foundation
import Testing
@testable import Clarity

@Suite("BackupChunking")
@MainActor
struct BackupChunkingTests {

    private func gasto(_ n: Int, id: String? = nil, notas: String? = nil) -> Expense {
        Expense(
            id: id ?? "g\(n)", amount: Double(n) + 0.5, name: "Café ☕️ \(n)", category: "Alimentacion🫄",
            date: "2026-09-10", notes: notas, isDeductible: n % 2 == 0,
            recurringId: n % 3 == 0 ? "regla" : nil,
            debtors: n % 5 == 0 ? [Debtor(id: "d\(n)", name: "Ana", amount: 1)] : nil,
            createdAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
    }

    private func hucha() -> GoalBackup {
        var meta = Goal(userId: "test-uid", name: "Viaje ✈️", type: .savingsTarget,
                        targetAmount: 1_200, currentAmount: 350, icon: "✈️", colorHex: "#00AAFF")
        meta.documentId = "hucha-1"
        meta.savedHistory = [
            .init(id: "a1", amount: 200, date: Date(timeIntervalSince1970: 1_795_000_000), note: "Paga extra"),
            .init(id: "a2", amount: 150, date: Date(timeIntervalSince1970: 1_797_000_000), note: nil),
        ]
        return GoalBackup(meta)
    }

    private func copia(_ gastos: [Expense], metas: [GoalBackup]? = nil) -> UserBackup {
        UserBackup(
            userId: "test-uid", timestamp: Date(timeIntervalSince1970: 1_800_000_000), version: "1.0",
            userDocument: nil, expenses: gastos,
            categories: [Category(id: "c1", name: "Ocio 🍻", color: "#fff", subcategories: ["Cine"], order: 0)],
            recurringExpenses: [], monthlyBudgets: [], goals: metas,
            savedFilters: [ExpenseFilter(name: "Mío")],
            deviceInfo: .init(model: "iPhone", systemVersion: "26.0", appVersion: "2.3.1")
        )
    }

    // MARK: - Metas

    @Test("Las huchas viajan en la copia con su saldo y sus aportaciones, también por partes")
    func metasEnLaCopia() throws {
        let documentos = try BackupChunking.trocear(copia((0..<200).map { gasto($0) }, metas: [hucha()]),
                                                     limite: 4_000)
        #expect(documentos.partes.count > 1)

        let vuelta = try BackupChunking.recomponer(principal: documentos.principal,
                                                   partes: porIndice(documentos.partes),
                                                   partesEsperadas: documentos.partes.count)
        let meta = try #require(vuelta.goals?.first)
        #expect(meta.id == "hucha-1")
        #expect(meta.currentAmount == 350)
        #expect(meta.savedHistory.map(\.amount) == [200, 150])

        // Y de vuelta al modelo de la app, con todo lo que el init no cubre.
        let goal = meta.toGoal()
        #expect(goal.name == "Viaje ✈️")
        #expect(goal.type == .savingsTarget)
        #expect(goal.savedHistory.count == 2)
    }

    @Test("Una copia anterior, sin metas, se sigue leyendo")
    func copiaSinMetas() throws {
        let documentos = try BackupChunking.trocear(copia([gasto(1)]))
        // Como la guardaba la 2.3.0: sin la clave `goals`.
        var json = try #require(JSONSerialization.jsonObject(with: Data(documentos.principal.utf8)) as? [String: Any])
        json.removeValue(forKey: "goals")
        let antigua = String(decoding: try JSONSerialization.data(withJSONObject: json), as: UTF8.self)

        let vuelta = try BackupChunking.recomponer(principal: antigua)
        #expect(vuelta.goals == nil)
        #expect(vuelta.expenses.count == 1)
    }

    private func porIndice(_ partes: [String]) -> [Int: String] {
        Dictionary(uniqueKeysWithValues: partes.enumerated().map { ($0.offset, $0.element) })
    }

    // MARK: - Partir

    @Test("Si todo cabe, un solo documento y ninguna parte")
    func cabeEnUno() throws {
        let documentos = try BackupChunking.trocear(copia((0..<20).map { gasto($0) }))
        #expect(documentos.partes.isEmpty)
        #expect(documentos.bytes == documentos.principal.utf8.count)

        let vuelta = try BackupChunking.recomponer(principal: documentos.principal)
        #expect(vuelta.expenses.count == 20)
    }

    @Test("Si no cabe, los gastos salen a partes y ningún documento pasa del límite")
    func seParte() throws {
        let gastos = (0..<200).map { gasto($0) }
        let limite = 4_000
        let documentos = try BackupChunking.trocear(copia(gastos), limite: limite)

        #expect(documentos.partes.count > 1)
        #expect(documentos.principal.utf8.count <= limite)
        #expect(documentos.partes.allSatisfy { $0.utf8.count <= limite })
        // El principal va sin gastos: están todos en las partes.
        #expect(try BackupChunking.recomponer(principal: documentos.principal).expenses.isEmpty)
        #expect(documentos.bytes == documentos.principal.utf8.count + documentos.partes.reduce(0) { $0 + $1.utf8.count })
    }

    @Test("Lo partido se recompone igual: todos los gastos, en su orden y con sus campos")
    func idaYVuelta() throws {
        let gastos = (0..<200).map { gasto($0) }
        let documentos = try BackupChunking.trocear(copia(gastos), limite: 4_000)

        let vuelta = try BackupChunking.recomponer(
            principal: documentos.principal,
            partes: porIndice(documentos.partes),
            partesEsperadas: documentos.partes.count)

        #expect(vuelta.expenses.map(\.id) == gastos.map(\.id))
        #expect(vuelta.expenses == gastos)
        // `==` de `Expense` no mira estos: se comprueban aparte.
        #expect(vuelta.expenses.map(\.isDeductible) == gastos.map(\.isDeductible))
        #expect(vuelta.expenses.map(\.createdAt) == gastos.map(\.createdAt))
        #expect(vuelta.expenses[5].debtors?.first?.name == "Ana")
        // Lo que no son gastos viaja en el principal.
        #expect(vuelta.categories.map(\.name) == ["Ocio 🍻"])
        #expect(vuelta.savedFilters.map(\.name) == ["Mío"])
        #expect(vuelta.userId == "test-uid")
    }

    @Test("El límite es de bytes: un gasto con notas largas ocupa más que uno escueto")
    func porTamañoNoPorNumero() throws {
        let largos = (0..<40).map { gasto($0, notas: String(repeating: "ñ", count: 400)) }
        let cortos = (0..<40).map { gasto($0) }
        let limite = 6_000

        let conLargos = try BackupChunking.trocear(copia(largos), limite: limite)
        let conCortos = try BackupChunking.trocear(copia(cortos), limite: limite)

        #expect(conLargos.partes.count > conCortos.partes.count)
        // "ñ" son dos bytes en UTF-8: se mide lo que cuenta Firestore, no caracteres.
        #expect(conLargos.partes.allSatisfy { $0.utf8.count <= limite })
    }

    @Test("Un único gasto que no cabe se devuelve tal cual, sin bucle infinito")
    func gastoGigante() throws {
        let gigante = gasto(1, notas: String(repeating: "x", count: 5_000))
        let documentos = try BackupChunking.trocear(copia([gigante, gasto(2)]), limite: 2_000)
        let vuelta = try BackupChunking.recomponer(
            principal: documentos.principal, partes: porIndice(documentos.partes),
            partesEsperadas: documentos.partes.count)
        #expect(vuelta.expenses.map(\.id) == ["g1", "g2"])
    }

    @Test("Si ni sin gastos cabe el principal, falla diciéndolo")
    func principalDemasiadoGrande() {
        #expect(throws: BackupChunking.Fallo.self) {
            try BackupChunking.trocear(copia([gasto(1)]), limite: 50)
        }
    }

    // MARK: - Recomponer

    @Test("El formato antiguo —todo en un documento, sin partCount— se sigue leyendo")
    func formatoAntiguo() throws {
        // Tal y como lo escribía `createBackup` antes de las partes.
        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .secondsSince1970
        let gastos = (0..<30).map { gasto($0) }
        let json = try #require(String(data: try codificador.encode(copia(gastos)), encoding: .utf8))

        let vuelta = try BackupChunking.recomponer(principal: json)

        #expect(vuelta.expenses == gastos)
        #expect(vuelta.expenses.map(\.id) == gastos.map(\.id))
        #expect(vuelta.timestamp == Date(timeIntervalSince1970: 1_800_000_000))
    }

    @Test("Si falta una parte no se restaura a medias")
    func faltaUnaParte() throws {
        let documentos = try BackupChunking.trocear(copia((0..<200).map { gasto($0) }), limite: 4_000)
        var partes = porIndice(documentos.partes)
        partes.removeValue(forKey: 1)

        #expect(throws: BackupChunking.Fallo.copiaIncompleta(
            esperadas: documentos.partes.count, encontradas: documentos.partes.count - 1)
        ) {
            try BackupChunking.recomponer(
                principal: documentos.principal, partes: partes, partesEsperadas: documentos.partes.count)
        }
    }

    // MARK: - Documentos hermanos

    @Test("El id de una parte sale del de la copia y su índice")
    func idsDeParte() {
        #expect(BackupChunking.idDeParte(copia: "ABC", indice: 0) == "ABC_p0")
        #expect(BackupChunking.idDeParte(copia: "ABC", indice: 12) == "ABC_p12")
    }

    @Test("Solo son huérfanas las partes viejas de una copia que ya no existe")
    func huerfanas() {
        let ahora = Date(timeIntervalSince1970: 1_800_000_000)
        let ayer = ahora.addingTimeInterval(-BackupChunking.graciaDeHuerfanas - 60)
        let haceUnRato = ahora.addingTimeInterval(-600)
        let partes: [BackupChunking.ParteGuardada] = [
            .init(id: "viva_p0", copia: "viva", creada: ayer),
            .init(id: "muerta_p0", copia: "muerta", creada: ayer),
            .init(id: "muerta_p1", copia: "muerta", creada: ayer),
            // Otra copia a medio subir desde otro dispositivo: sus partes llegan
            // antes que su documento principal.
            .init(id: "subiendo_p0", copia: "subiendo", creada: haceUnRato),
            .init(id: "sinfecha_p0", copia: "sinfecha", creada: nil),
        ]

        let sobran = BackupChunking.partesHuerfanas(partes, copiasVivas: ["viva"], ahora: ahora)

        #expect(sobran.sorted() == ["muerta_p0", "muerta_p1"])
    }

    // MARK: - Lotes de restauración

    @Test("Los gastos se restauran en lotes que caben en un WriteBatch, y sin id no entran")
    func lotes() {
        var gastos = (0..<1_000).map { gasto($0) }
        gastos[3].id = nil
        gastos[7].id = ""

        let lotes = BackupChunking.lotes(de: gastos)

        #expect(lotes.map(\.count) == [450, 450, 98])
        #expect(lotes.allSatisfy { $0.count <= 500 })
        let ids = lotes.flatMap { $0 }.compactMap(\.id)
        #expect(ids.count == 998)
        #expect(!ids.contains("g3") && !ids.contains("g7"))
        // En su orden.
        #expect(ids.prefix(3) == ["g0", "g1", "g2"])
    }

    @Test("Sin gastos no hay lotes")
    func sinLotes() {
        #expect(BackupChunking.lotes(de: []).isEmpty)
        #expect(BackupChunking.lotes(de: [gasto(1, id: "")]).isEmpty)
    }
}
