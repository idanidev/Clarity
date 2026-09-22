// PlanDeRecordatorios.swift
// Qué dice y cuándo sale el resumen semanal (#57).
//
// Una notificación local lleva el texto fijado al programarla: no hay forma de
// calcularlo en el momento de salir. Por eso `RecordatoriosService` la vuelve a
// programar con los datos al día, y todo lo que decide el texto y las fechas
// vive aquí, en funciones puras, para poder probarlo sin el centro de
// notificaciones. Aquí no se registra nada: ni en logs ni en analítica viaja
// un importe. Y con el bloqueo de la app activado, tampoco en el aviso.

import Foundation

/// Lo que viaja en el `userInfo` de un aviso para saber, al tocarlo, cuál era.
/// Aparte y `nonisolated` porque lo lee el delegado de notificaciones, que
/// no corre en el main actor.
nonisolated enum MarcaAviso {
    static let tipo = "clarity.tipo"
    static let semanaConGastos = "clarity.semanaConGastos"
    static let resumenSemanal = "resumen_semanal"
}

/// Título y cuerpo de un aviso ya decidido.
nonisolated struct ContenidoRecordatorio: Equatable, Sendable {
    let titulo: String
    let cuerpo: String
    /// Es el resumen de una semana con gastos (y no el recordatorio de siempre),
    /// enseñe o no las cifras. Al abrir la app desde uno así se puede pedir la
    /// reseña: quien lo toca lleva una semana apuntando, y eso no cambia porque
    /// el bloqueo tape los importes.
    let semanaConGastos: Bool
}

// MARK: - Resumen semanal

nonisolated enum ResumenSemanal {

    /// Avisos programados por delante: el próximo, con las cifras, y los de las
    /// semanas siguientes con el texto de siempre. Antes era una notificación
    /// repetitiva que sonaba cada semana aunque no se abriera la app; con una
    /// sola suelta, quien dejara de abrirla se quedaría sin ninguna. Con cuatro
    /// se cubre un mes sin abrirla; la siguiente vez que se abra se rehacen.
    static let avisosPorDelante = 4

    /// Lo que se cuenta de la semana del aviso y de la anterior.
    struct Cifras: Equatable, Sendable {
        var total: Double = 0
        var gastos: Int = 0
        var totalAnterior: Double = 0
        var gastosAnterior: Int = 0
    }

    /// Los próximos `cuantos` momentos, estrictamente posteriores a `ahora`, que
    /// caen en el día de la semana y la hora elegidos. `diaSemana` sigue la
    /// convención de `Calendar`: 1 = domingo … 7 = sábado.
    ///
    /// Cada uno se busca desde el anterior (y no sumando 7 días) para que el
    /// cambio de hora no mueva la hora del aviso.
    static func proximosAvisos(
        despuesDe ahora: Date,
        diaSemana: Int,
        hora: Int,
        minuto: Int,
        cuantos: Int = avisosPorDelante,
        calendar: Calendar
    ) -> [Date] {
        var componentes = DateComponents()
        componentes.weekday = min(max(diaSemana, 1), 7)
        componentes.hour = min(max(hora, 0), 23)
        componentes.minute = min(max(minuto, 0), 59)
        componentes.second = 0

        var avisos: [Date] = []
        var desde = ahora
        while avisos.count < cuantos,
              let siguiente = calendar.nextDate(after: desde, matching: componentes, matchingPolicy: .nextTime) {
            avisos.append(siguiente)
            desde = siguiente
        }
        return avisos
    }

    /// Días ("yyyy-MM-dd") de la semana que acaba el día del aviso, ambos
    /// incluidos: con el aviso en domingo, de lunes a domingo. Así la semana se
    /// cuenta según el día que eligió el usuario, no según el calendario.
    /// `semanasAtras: 1` da la anterior.
    static func semana(delAviso aviso: Date, semanasAtras: Int = 0, calendar: Calendar) -> ClosedRange<String>? {
        let diaDelAviso = calendar.startOfDay(for: aviso)
        guard let fin = calendar.date(byAdding: .day, value: -7 * semanasAtras, to: diaDelAviso),
              let inicio = calendar.date(byAdding: .day, value: -6, to: fin) else { return nil }
        return claveDia(inicio, calendar: calendar)...claveDia(fin, calendar: calendar)
    }

    /// Suma la semana del aviso y la anterior. Cuentan todos los gastos,
    /// recurrentes incluidos: también son dinero que ha salido esa semana.
    static func cifras(de gastos: [Expense], aviso: Date, calendar: Calendar) -> Cifras {
        guard let actual = semana(delAviso: aviso, calendar: calendar),
              let anterior = semana(delAviso: aviso, semanasAtras: 1, calendar: calendar)
        else { return Cifras() }

        var cifras = Cifras()
        for gasto in gastos {
            // Por si algún gasto antiguo guardó la hora detrás del día.
            let dia = String(gasto.date.prefix(10))
            if actual.contains(dia) {
                cifras.total += gasto.amount
                cifras.gastos += 1
            } else if anterior.contains(dia) {
                cifras.totalAnterior += gasto.amount
                cifras.gastosAnterior += 1
            }
        }
        return cifras
    }

    /// El texto del aviso. Sin gastos esa semana, el recordatorio de siempre:
    /// un «llevas 0,00 €» no invita a nada.
    ///
    /// Con `ocultarImportes` (el bloqueo de la app activado) no lleva cifras:
    /// el aviso sale en la pantalla de bloqueo del iPhone, a la vista de quien
    /// lo tenga en la mano, y quien protege la app con Face ID no quiere sus
    /// importes ahí. Sin valor por defecto a propósito: quien programe el aviso
    /// tiene que decidirlo.
    static func contenido(
        _ cifras: Cifras,
        ocultarImportes: Bool,
        moneda: (Double) -> String = Formatters.currency,
        monedaSinDecimales: (Double) -> String = Formatters.currencyWithoutDecimals
    ) -> ContenidoRecordatorio {
        guard cifras.gastos > 0 else { return recordatorio }
        guard !ocultarImportes else { return resumenSinCifras }

        let total = moneda(cifras.total)
        let numero = cifras.gastos == 1
            ? String(localized: "notifications.summary.oneExpense", defaultValue: "1 gasto")
            : String(localized: "notifications.summary.expenses", defaultValue: "\(cifras.gastos) gastos")
        var cuerpo = String(
            localized: "notifications.summary.body",
            defaultValue: "Esta semana llevas \(total) en \(numero)"
        )
        if let comparacion = comparacion(cifras, monedaSinDecimales: monedaSinDecimales) {
            cuerpo += " · " + comparacion
        }
        return ContenidoRecordatorio(
            titulo: String(localized: "notifications.summary.title", defaultValue: "Resumen semanal"),
            cuerpo: cuerpo,
            semanaConGastos: true
        )
    }

    /// Frente a la semana anterior, en euros enteros: los céntimos en una
    /// comparación solo estorban. Sin gastos la semana anterior no se compara
    /// («142 € más que la anterior» no le dice nada a quien acaba de empezar),
    /// y si la diferencia redondea a cero, es lo mismo.
    static func comparacion(
        _ cifras: Cifras,
        monedaSinDecimales: (Double) -> String = Formatters.currencyWithoutDecimals
    ) -> String? {
        guard cifras.gastosAnterior > 0 else { return nil }
        let diferencia = (cifras.total - cifras.totalAnterior).rounded()
        if diferencia == 0 {
            return String(localized: "notifications.summary.same", defaultValue: "lo mismo que la anterior")
        }
        let cantidad = monedaSinDecimales(abs(diferencia))
        return diferencia < 0
            ? String(localized: "notifications.summary.less", defaultValue: "\(cantidad) menos que la anterior")
            : String(localized: "notifications.summary.more", defaultValue: "\(cantidad) más que la anterior")
    }

    /// El resumen con el bloqueo activado: dice que está listo, sin importes ni
    /// número de gastos. Las cifras se ven al entrar, ya desbloqueada.
    static var resumenSinCifras: ContenidoRecordatorio {
        ContenidoRecordatorio(
            titulo: String(localized: "notifications.summary.title", defaultValue: "Resumen semanal"),
            cuerpo: String(localized: "notifications.summary.hiddenBody",
                           defaultValue: "Tu resumen de la semana está listo: entra para ver cuánto llevas."),
            semanaConGastos: true
        )
    }

    /// El de siempre, invitando a apuntar. Es el que sale las semanas sin gastos
    /// y en los avisos de las semanas siguientes, de las que aún no hay datos.
    static var recordatorio: ContenidoRecordatorio {
        ContenidoRecordatorio(
            titulo: String(localized: "notifications.weekly.reminderTitle", defaultValue: "Recordatorio semanal"),
            cuerpo: String(localized: "notifications.weekly.reminderBody",
                           defaultValue: "Recuerda apuntar tus gastos de esta semana"),
            semanaConGastos: false
        )
    }

    /// "yyyy-MM-dd" en el calendario dado: el mismo formato que `Expense.date`,
    /// que guarda el día local en el que se hizo el gasto.
    static func claveDia(_ fecha: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: fecha)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
