// DatosDemo.swift
// Los datos inventados del modo demo (solo DEBUG): gastos, presupuestos,
// metas y recurrentes de una persona que no existe, relativos a la fecha de
// hoy para que valgan en cualquier mes.
//
// Funciones puras: todo sale de `hoy` y del calendario, sin aleatoriedad, así
// que dos arranques el mismo día dan exactamente lo mismo y se puede probar
// (`DatosDemoTests`). Los nombres son genéricos a propósito: nada de marcas ni
// de nada que se parezca a la cuenta de nadie.

#if DEBUG
import Foundation

struct DatosDemo {
    /// Todos los gastos, del más reciente al más antiguo.
    let gastos: [Expense]
    /// Uno por mes, del actual hacia atrás.
    let presupuestos: [MonthlyBudget]
    let metas: [Goal]
    let recurrentes: [RecurringExpense]
    let categorias: [Category]
    let documento: UserDocument

    static let uid = "demo"
    /// Nómina de todos los meses. Con el ingreso extra del mes en curso, el
    /// presupuesto de este mes queda en 2.000 €.
    static let nomina: Double = 1850
    static let ingresoExtraDelMes = IncomeEntry(id: "demo-ingreso-segunda-mano", name: "Venta de segunda mano",
                                                 amount: 150, date: "", createdAt: nil)
    /// Meses completos hacia atrás, para la evolución y «tu normal».
    static let mesesAtras = 6
    /// El límite de Ocio.
    static let topeOcio: Double = 150

    // MARK: - Generación

    static func generar(hoy: Date, calendar: Calendar = .current) -> DatosDemo {
        let inicioMes = calendar.date(from: calendar.dateComponents([.year, .month], from: hoy)) ?? hoy
        let diaHoy = calendar.component(.day, from: hoy)
        let diasMesActual = calendar.range(of: .day, in: .month, for: hoy)?.count ?? 30
        let recurrentes = reglas(diaHoy: diaHoy, diasMes: diasMesActual, inicioMes: inicioMes, calendar: calendar)

        var gastos: [Expense] = []
        var presupuestos: [MonthlyBudget] = []

        for atras in 0...mesesAtras {
            guard let mes = calendar.date(byAdding: .month, value: -atras, to: inicioMes) else { continue }
            let diasMes = calendar.range(of: .day, in: .month, for: mes)?.count ?? 30
            // El mes en curso, hasta hoy; los anteriores, enteros.
            let ultimoDia = atras == 0 ? diaHoy : diasMes

            func fecha(_ dia: Int) -> String {
                let d = calendar.date(byAdding: .day, value: min(dia, diasMes) - 1, to: mes) ?? mes
                return Formatters.localDayString(from: d)
            }

            for (i, p) in plantilla.enumerated() where min(p.dia, diasMes) <= ultimoDia {
                let importe = atras == 0 ? p.importe : variar(p.importe, indice: i, mes: atras)
                gastos.append(Expense(
                    id: "demo-\(fecha(p.dia))-\(i)", amount: importe, name: p.nombre,
                    category: p.categoria.rawValue, subcategory: p.subcategoria,
                    date: fecha(p.dia), paymentMethod: p.pago))
            }

            for (i, extra) in (extras[atras] ?? []).enumerated() where min(extra.dia, diasMes) <= ultimoDia {
                gastos.append(Expense(
                    id: "demo-\(fecha(extra.dia))-extra-\(i)", amount: extra.importe, name: extra.nombre,
                    category: extra.categoria.rawValue, subcategory: extra.subcategoria,
                    date: fecha(extra.dia), paymentMethod: extra.pago))
            }

            // Los cargos de las reglas. En el mes en curso, solo los que ya han
            // pasado: el de hoy y los siguientes salen como próximos cargos.
            for regla in recurrentes {
                let dia = min(regla.dayOfMonth, diasMes)
                guard atras == 0 ? dia < diaHoy : true, let id = regla.id else { continue }
                gastos.append(Expense(
                    id: "demo-\(fecha(dia))-\(id)", amount: regla.amount, name: regla.name,
                    category: regla.category, subcategory: regla.subcategory,
                    date: fecha(dia), paymentMethod: regla.paymentMethod,
                    isRecurring: true, recurringId: id))
            }

            let anio = calendar.component(.year, from: mes)
            let numMes = calendar.component(.month, from: mes)
            var presupuesto = MonthlyBudget(userId: uid, year: anio, month: numMes, income: nomina)
            if atras == 0 {
                var extra = ingresoExtraDelMes
                extra.date = fecha(min(2, diaHoy))
                presupuesto.extraIncomes = [extra]
            } else if atras == 3 {
                presupuesto.extraIncomes = [IncomeEntry(id: "demo-ingreso-trabajo-extra", name: "Trabajo extra",
                                                        amount: 200, date: fecha(14), createdAt: nil)]
            }
            presupuestos.append(presupuesto)
        }

        gastos.sort {
            if $0.date != $1.date { return $0.date > $1.date }
            return ($0.id ?? "") > ($1.id ?? "")
        }

        let categorias = DefaultCategory.allCases.enumerated().map { index, cat in
            Category(id: cat.rawValue, name: cat.rawValue, color: cat.defaultColor,
                     subcategories: cat.defaultSubcategories, order: index, createdAt: nil, updatedAt: nil)
        }

        var ajustes = UserSettings.default
        ajustes.hasCompletedOnboarding = true
        ajustes.isSalaryRecurring = true
        let documento = UserDocument(
            displayName: "Demo", role: "user", createdAt: calendar.date(byAdding: .month, value: -8, to: inicioMes),
            income: nomina, settings: ajustes, aiQuotas: .free)

        return DatosDemo(gastos: gastos, presupuestos: presupuestos, metas: metas(calendar: calendar, hoy: hoy),
                         recurrentes: recurrentes, categorias: categorias, documento: documento)
    }

    // MARK: - Qué se gasta

    struct Apunte {
        let dia: Int
        let nombre: String
        let categoria: DefaultCategory
        let subcategoria: String?
        let importe: Double
        let pago: String
    }

    /// Un mes tipo, día a día. El mes en curso sale tal cual hasta hoy; los
    /// anteriores, con los importes un poco movidos (`variar`).
    static let plantilla: [Apunte] = {
        var p: [Apunte] = []
        func a(_ dias: [Int], _ nombre: String, _ cat: DefaultCategory, _ sub: String?, _ importes: [Double], _ pago: String = "Tarjeta") {
            for (i, dia) in dias.enumerated() {
                p.append(Apunte(dia: dia, nombre: nombre, categoria: cat, subcategoria: sub,
                                importe: importes[i % importes.count], pago: pago))
            }
        }
        // Alimentación: el súper de la semana y lo pequeño de cada día.
        a([3, 10, 17, 24, 31], "Supermercado", .alimentacion, "Supermercado", [78.40, 64.90, 86.15, 71.30, 58.60])
        a([1, 5, 9, 12, 16, 19, 23, 26, 30], "Panadería", .alimentacion, "Supermercado",
          [2.40, 3.10, 2.40, 3.80, 2.90, 2.40, 3.10, 2.60, 3.40], "Efectivo")
        a([2, 4, 8, 11, 15, 18, 22, 25, 29], "Café", .alimentacion, "Cafeterías",
          [1.80, 2.20, 1.80, 3.50, 1.80, 2.20, 1.80, 2.20, 1.80])
        a([6, 13, 20, 27], "Frutería", .alimentacion, "Supermercado", [9.80, 7.45, 11.20, 8.90], "Efectivo")
        a([8, 16, 23], "Menú del día", .alimentacion, "Restaurantes", [12.50, 13.00, 12.50])
        a([11, 25], "Comida a domicilio", .alimentacion, "Delivery", [24.90, 21.50])
        // Ocio, con su límite de 150 €.
        a([7], "Cine", .ocio, "Cine", [16.00])
        a([9], "Pádel", .ocio, "Deportes", [8.00])
        a([14], "Cañas con amigos", .ocio, "Bares", [18.50], "Efectivo")
        a([21], "Cena con amigos", .ocio, "Bares", [42.00], "Bizum")
        a([27], "Concierto", .ocio, "Conciertos", [35.00])
        // Transporte.
        a([2], "Abono transporte", .transporte, "Transporte público", [21.80])
        a([5, 19], "Gasolina", .transporte, "Gasolina", [50.00, 45.00])
        a([12], "Parking", .transporte, "Parking", [6.50])
        a([24], "Taxi", .transporte, "Taxi", [11.40])
        // Casa.
        a([3], "Internet", .vivienda, "Internet", [30.00], "Transferencia")
        a([6], "Luz", .vivienda, "Luz", [52.40], "Transferencia")
        a([15], "Agua", .vivienda, "Agua", [21.60], "Transferencia")
        a([18], "Gas", .vivienda, "Gas", [28.70], "Transferencia")
        // El resto.
        a([13], "Ropa", .compras, "Ropa", [45.99])
        a([18], "Regalo de cumpleaños", .compras, "Regalos", [30.00])
        a([26], "Cosas para casa", .compras, "Hogar", [24.50])
        a([4, 20], "Farmacia", .salud, "Farmacia", [9.75, 14.30])
        a([16], "Libro", .educacion, "Libros", [18.90])
        a([10], "Peluquería", .otros, "Varios", [15.00])
        return p
    }()

    /// Lo que solo pasó en un mes concreto, por meses hacia atrás: así la
    /// evolución no sale plana y el mes pasado iba algo por encima de este.
    static let extras: [Int: [Apunte]] = [
        1: [Apunte(dia: 13, nombre: "Escapada de fin de semana", categoria: .viajes, subcategoria: "Hotel", importe: 185.00, pago: "Tarjeta")],
        2: [Apunte(dia: 20, nombre: "Revisión del coche", categoria: .transporte, subcategoria: nil, importe: 140.00, pago: "Tarjeta")],
        3: [Apunte(dia: 9, nombre: "Vuelos", categoria: .viajes, subcategoria: "Vuelos", importe: 128.00, pago: "Tarjeta")],
        5: [Apunte(dia: 18, nombre: "Auriculares", categoria: .compras, subcategoria: "Electrónica", importe: 79.00, pago: "Tarjeta")],
    ]

    /// Cuánto se movió cada mes anterior respecto al tipo.
    static let factores: [Int: Double] = [1: 1.06, 2: 0.94, 3: 1.03, 4: 0.90, 5: 0.97, 6: 1.00]

    /// El importe de un mes anterior: el del mes tipo con el factor del mes y
    /// un ±8 % que depende solo del apunte y del mes. Redondeado a 5 céntimos,
    /// que es como salen los tickets.
    static func variar(_ importe: Double, indice: Int, mes: Int) -> Double {
        let vaiven = 1 + Double((indice * 37 + mes * 11) % 17 - 8) / 100
        let valor = importe * (factores[mes] ?? 1) * vaiven
        return (valor * 20).rounded() / 20
    }

    // MARK: - Recurrentes

    /// Música, móvil y gimnasio. El móvil y el gimnasio caen unos días después
    /// de hoy para que la Home tenga siempre próximos cargos.
    static func reglas(diaHoy: Int, diasMes: Int, inicioMes: Date, calendar: Calendar) -> [RecurringExpense] {
        let alta = calendar.date(byAdding: .month, value: -(mesesAtras + 2), to: inicioMes) ?? inicioMes
        let desde = Formatters.localDayString(from: alta)
        func regla(_ id: String, _ nombre: String, _ importe: Double, _ cat: DefaultCategory, _ sub: String?,
                   dia: Int, icono: String) -> RecurringExpense {
            RecurringExpense(id: id, amount: importe, name: nombre, category: cat.rawValue, subcategory: sub,
                             paymentMethod: "Tarjeta", frequency: .monthly, dayOfMonth: dia, billingMonth: 0,
                             active: true, icon: icono, startDate: desde, endDate: nil, lastCreated: nil,
                             createdAt: desde, updatedAt: desde)
        }
        return [
            regla("demo-regla-musica", "Música", 10.99, .suscripciones, nil, dia: 3, icono: "🎵"),
            regla("demo-regla-movil", "Tarifa móvil", 15.00, .suscripciones, nil,
                  dia: min(diaHoy + 4, diasMes), icono: "📱"),
            regla("demo-regla-gimnasio", "Gimnasio", 34.90, .salud, "Gimnasio",
                  dia: min(diaHoy + 7, diasMes), icono: "🏋️"),
        ]
    }

    // MARK: - Metas

    /// El límite de Ocio y dos huchas a medias.
    static func metas(calendar: Calendar, hoy: Date) -> [Goal] {
        var ocio = Goal(userId: uid, name: "Ocio", type: .spendingLimit, recurrence: .monthly,
                        targetAmount: topeOcio, linkedCategoryId: DefaultCategory.ocio.rawValue)
        ocio.documentId = "demo-meta-ocio"
        ocio.systemImage = "theatermasks.fill"

        var japon = Goal(userId: uid, name: "Viaje a Japón", type: .savingsTarget, targetAmount: 3000,
                         currentAmount: 1240, deadline: calendar.date(byAdding: .month, value: 9, to: hoy))
        japon.documentId = "demo-meta-japon"
        japon.systemImage = "airplane"

        var emergencia = Goal(userId: uid, name: "Fondo de emergencia", type: .savingsTarget, targetAmount: 6000,
                              currentAmount: 3600)
        emergencia.documentId = "demo-meta-emergencia"
        emergencia.systemImage = "umbrella.fill"

        return [ocio, japon, emergencia]
    }
}
#endif
