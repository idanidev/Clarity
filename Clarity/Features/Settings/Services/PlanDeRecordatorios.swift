// PlanDeRecordatorios.swift
// Qué dicen y cuándo salen el resumen semanal y el recordatorio diario (#57).
//
// Una notificación local lleva el texto fijado al programarla: no hay forma de
// calcularlo en el momento de salir. Por eso `RecordatoriosService` la vuelve a
// programar con los datos al día, y todo lo que decide el texto y las fechas
// vive aquí, en funciones puras, para poder probarlo sin el centro de
// notificaciones. Aquí no se registra nada: ni en logs ni en analítica viaja
// un importe.

import Foundation

/// Lo que viaja en el `userInfo` de un aviso para saber, al tocarlo, cuál era.
/// Aparte y `nonisolated` porque lo lee el delegado de notificaciones, que
/// no corre en el main actor.
nonisolated enum MarcaAviso {
    static let tipo = "clarity.tipo"
    static let conDatos = "clarity.conDatos"
    static let resumenSemanal = "resumen_semanal"
}

/// Título y cuerpo de un aviso ya decidido.
nonisolated struct ContenidoRecordatorio: Equatable, Sendable {
    let titulo: String
    let cuerpo: String
    /// Lleva cifras del usuario (y no el texto de recordatorio de siempre). Al
    /// abrir la app desde uno así se puede pedir la reseña: quien lo toca lleva
    /// una semana apuntando.
    let conDatos: Bool
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
    static func contenido(
        _ cifras: Cifras,
        moneda: (Double) -> String = Formatters.currency,
        monedaSinDecimales: (Double) -> String = Formatters.currencyWithoutDecimals
    ) -> ContenidoRecordatorio {
        guard cifras.gastos > 0 else { return recordatorio }

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
            conDatos: true
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

    /// El de siempre, invitando a apuntar. Es el que sale las semanas sin gastos
    /// y en los avisos de las semanas siguientes, de las que aún no hay datos.
    static var recordatorio: ContenidoRecordatorio {
        ContenidoRecordatorio(
            titulo: String(localized: "notifications.weekly.reminderTitle", defaultValue: "Recordatorio semanal"),
            cuerpo: String(localized: "notifications.weekly.reminderBody",
                           defaultValue: "Recuerda apuntar tus gastos de esta semana"),
            conDatos: false
        )
    }

    /// "yyyy-MM-dd" en el calendario dado: el mismo formato que `Expense.date`,
    /// que guarda el día local en el que se hizo el gasto.
    static func claveDia(_ fecha: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: fecha)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - Recordatorio diario

nonisolated enum RecordatorioDiario {

    /// Avisos sueltos programados por delante. No es una notificación
    /// repetitiva porque tiene que poder saltarse el día en que ya se ha
    /// apuntado algo, y eso solo se sabe al programar.
    static let avisosPorDelante = 7

    /// Hora por defecto si el usuario no ha elegido otra.
    static let horaPorDefecto = 21

    /// ¿Se ha apuntado ya algún gasto con fecha de hoy? Los recurrentes no
    /// cuentan: los crea la app sola al abrirse, y un Netflix cobrado hoy no
    /// quiere decir que el usuario haya apuntado lo que ha gastado.
    static func hayGastoApuntadoHoy(_ gastos: [Expense], ahora: Date, calendar: Calendar) -> Bool {
        let hoy = ResumenSemanal.claveDia(ahora, calendar: calendar)
        return gastos.contains { !$0.esRecurrente && String($0.date.prefix(10)) == hoy }
    }

    /// Los próximos avisos, siempre `avisosPorDelante`, a la hora elegida. El de
    /// hoy entra si su hora aún no ha pasado y no hay gasto de hoy: avisar a
    /// quien ya ha hecho los deberes es la vía rápida a que apague las
    /// notificaciones.
    static func proximosAvisos(
        desde ahora: Date,
        hora: Int,
        minuto: Int,
        hayGastoHoy: Bool,
        calendar: Calendar
    ) -> [Date] {
        let hoy = calendar.startOfDay(for: ahora)
        let hora = min(max(hora, 0), 23)
        let minuto = min(max(minuto, 0), 59)

        var avisos: [Date] = []
        // Un día de más: si hoy se salta, el séptimo cae el octavo.
        for desplazamiento in 0...avisosPorDelante where avisos.count < avisosPorDelante {
            if desplazamiento == 0 && hayGastoHoy { continue }
            guard let dia = calendar.date(byAdding: .day, value: desplazamiento, to: hoy),
                  let aviso = calendar.date(bySettingHour: hora, minute: minuto, second: 0, of: dia),
                  aviso > ahora
            else { continue }
            avisos.append(aviso)
        }
        return avisos
    }

    static var contenido: ContenidoRecordatorio {
        ContenidoRecordatorio(
            titulo: String(localized: "notifications.daily.title", defaultValue: "¿Algún gasto hoy?"),
            cuerpo: String(localized: "notifications.daily.body",
                           defaultValue: "Apúntalo en 5 segundos: pulsa el micro y dilo en voz alta."),
            conDatos: false
        )
    }
}
