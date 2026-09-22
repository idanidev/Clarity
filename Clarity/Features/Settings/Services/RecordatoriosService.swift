// RecordatoriosService.swift
// Programa el resumen semanal y el recordatorio diario con los datos al día (#57).
//
// Una notificación local lleva el texto fijado al programarla, así que un
// resumen con cifras hay que rehacerlo cada vez que cambian: tras cada cambio
// en los gastos (con una pequeña espera, porque un solo guardado avisa varias
// veces) y al pasar a segundo plano, que es el último momento seguro antes de
// que salga. Qué dice y cuándo sale lo deciden las funciones puras de
// `PlanDeRecordatorios.swift`; aquí solo se lee la caché y se programa.

import Foundation
import OSLog
import UIKit
import UserNotifications

@MainActor
final class RecordatoriosService {
    static let shared = RecordatoriosService()

    /// Claves de UserDefaults, las mismas que usa `NotificationsView` con
    /// `@AppStorage`.
    enum Clave {
        static let push = "notifications.pushEnabled"
        static let semanal = "notifications.weeklyReminder"
        static let diaSemanal = "notifications.weeklyDay"
        /// Se llaman "daily*" por herencia, pero son la hora del semanal. No se
        /// renombran: quien ya lo tiene configurado perdería su día y su hora.
        static let horaSemanal = "notifications.dailyHour"
        static let minutoSemanal = "notifications.dailyMinute"
        /// Nuevas a propósito. `notifications.dailyReminder` era el diario que
        /// se retiró antes de la 2.2.0 (4f90319), y en las builds que lo
        /// llevaron se encendía solo al aceptar el permiso que se pedía tras el
        /// segundo gasto: reutilizarla se lo volvería a encender a gente que
        /// nunca lo eligió, y este va apagado por defecto.
        static let diario = "notifications.dailyCheckIn"
        static let horaDiario = "notifications.dailyCheckInHour"
        static let minutoDiario = "notifications.dailyCheckInMinute"
    }

    enum Identificador {
        /// El primero es el id de siempre del semanal; los siguientes, las
        /// semanas de después.
        static let semanales: [String] = ["clarity.weekly.reminder"]
            + (1..<ResumenSemanal.avisosPorDelante).map { "clarity.weekly.reminder.\($0)" }
        /// Distintos de `clarity.daily.reminder`, el del diario retirado, que
        /// `NotificationsView.refreshOnLaunch` cancela en cada arranque.
        static let diarios: [String] = (0..<RecordatorioDiario.avisosPorDelante)
            .map { "clarity.checkin.daily.\($0)" }

        /// Todo lo que la app programa. Lo que no esté aquí se borra al volver
        /// a primer plano (`ClarityApp.removeStaleNotifications`), así que
        /// cualquier id nuevo tiene que entrar en esta lista.
        static let todos: Set<String> = Set(semanales + diarios + [
            "clarity.endofmonth.reminder",
            "clarity.daily.reminder",
            "clarity.inactivity.reminder",
            "clarity.inactivity.recurring",
        ])
    }

    /// Tras tocar el resumen, cuánto tiempo sigue en pie pedir la reseña.
    private static let margenResena: TimeInterval = 120
    private static let esperaTrasCambio: Duration = .seconds(2)
    private static let esperaAntesDeResena: Duration = .milliseconds(1500)

    private let defaults = UserDefaults.standard
    private let centro = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.idanidev.clarity", category: "Recordatorios")

    private var observador: (any NSObjectProtocol)?
    private var reprogramacionPendiente: Task<Void, Never>?
    /// Cuándo se abrió la app desde un resumen con cifras, si aún no se ha
    /// podido pedir la reseña.
    private var resenaPendienteDesde: Date?

    /// La pone `ClarityApp`: con la pantalla de bloqueo delante no se pide la
    /// reseña (saldría encima de Face ID).
    var estaBloqueada: () -> Bool = { false }

    private init() {}

    // MARK: - Arranque

    /// Llamar una vez con la sesión ya cargada. Deja escuchando los cambios en
    /// los gastos y reprograma ya, por si el texto guardado es de otro día.
    func arrancar() {
        if observador == nil {
            observador = NotificationCenter.default.addObserver(
                forName: .expenseDidChange,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in RecordatoriosService.shared.reprogramarEnUnMomento() }
            }
        }
        reprogramarAhora()
    }

    // MARK: - Reprogramación

    /// Tras un cambio en los gastos. Espera un poco y se queda con el último:
    /// un solo guardado avisa desde el formulario y desde quien lo abrió.
    func reprogramarEnUnMomento() {
        reprogramacionPendiente?.cancel()
        reprogramacionPendiente = Task { [weak self] in
            try? await Task.sleep(for: Self.esperaTrasCambio)
            guard !Task.isCancelled else { return }
            await self?.reprogramar()
        }
    }

    /// Sin espera: al pasar a segundo plano y al cambiar los ajustes.
    func reprogramarAhora() {
        reprogramacionPendiente?.cancel()
        reprogramacionPendiente = nil
        Task { [weak self] in await self?.reprogramar() }
    }

    /// Al apagar el diario vuelve el aviso de inactividad, que con el diario
    /// encendido no se programa. Sin esto no volvería hasta el siguiente
    /// arranque en frío.
    func diarioApagado() {
        reprogramarAhora()
        Task {
            let ultimo = await leerGastos().map(\.dateAsDate).max()
            NotificationsView.scheduleInactivityReminderIfNeeded(lastExpenseDate: ultimo)
        }
    }

    private func reprogramar() async {
        let gastos = Ajustes(defaults).hayAlgunoActivo ? await leerGastos() : []

        // Los ajustes, después de leer la caché: si han cambiado entretanto,
        // manda lo último. Y todo lo de abajo va seguido, sin esperas: dos
        // reprogramaciones que se crucen no pueden mezclar sus avisos.
        let ajustes = Ajustes(defaults)
        let semanalActivo = ajustes.push && ajustes.semanal
        let diarioActivo = ajustes.push && ajustes.diario
        let ahora = Date()
        let calendario = Calendar.current
        var peticiones: [UNNotificationRequest] = []

        if semanalActivo {
            let avisos = ResumenSemanal.proximosAvisos(
                despuesDe: ahora,
                diaSemana: ajustes.diaSemanal,
                hora: ajustes.horaSemanal,
                minuto: ajustes.minutoSemanal,
                calendar: calendario
            )
            for (indice, (id, fecha)) in zip(Identificador.semanales, avisos).enumerated() {
                // Solo el próximo lleva cifras: de las semanas siguientes aún
                // no hay datos, y si se abre la app antes, se rehacen.
                let contenido = indice == 0
                    ? ResumenSemanal.contenido(ResumenSemanal.cifras(de: gastos, aviso: fecha, calendar: calendario))
                    : ResumenSemanal.recordatorio
                peticiones.append(peticion(id: id, contenido: contenido, fecha: fecha,
                                           calendario: calendario, esResumen: true))
            }
        }

        if diarioActivo {
            // Con el diario encendido, el de inactividad sobra: el diario ya
            // pregunta cada día y los dos juntos llegarían a sonar el mismo día
            // (10:00 «llevas 7 días sin registrar» y por la noche «¿algún
            // gasto hoy?»). `scheduleInactivityReminderIfNeeded` tampoco lo
            // programa mientras el diario siga encendido.
            NotificationsView.cancelInactivityReminder()

            let hayGastoHoy = RecordatorioDiario.hayGastoApuntadoHoy(gastos, ahora: ahora, calendar: calendario)
            let avisos = RecordatorioDiario.proximosAvisos(
                desde: ahora,
                hora: ajustes.horaDiario,
                minuto: ajustes.minutoDiario,
                hayGastoHoy: hayGastoHoy,
                calendar: calendario
            )
            for (id, fecha) in zip(Identificador.diarios, avisos) {
                peticiones.append(peticion(id: id, contenido: RecordatorioDiario.contenido, fecha: fecha,
                                           calendario: calendario, esResumen: false))
            }
        }

        aplicar(peticiones)

        // Sin importes ni número de gastos: solo qué hay programado.
        logger.debug("Recordatorios: semanal=\(semanalActivo), diario=\(diarioActivo), avisos=\(peticiones.count)")
    }

    /// Síncrona a propósito: el alta sin esperar respuesta se entrega al
    /// sistema en el acto, también si la app se suspende justo después de
    /// pasar a segundo plano.
    private func aplicar(_ peticiones: [UNNotificationRequest]) {
        // Se quita solo lo que no se vuelve a programar: añadir con el mismo id
        // ya sustituye al anterior, y así no depende del orden en que el
        // sistema atienda el borrado y el alta.
        let programados = Set(peticiones.map(\.identifier))
        let sobrantes = (Identificador.semanales + Identificador.diarios).filter { !programados.contains($0) }
        centro.removePendingNotificationRequests(withIdentifiers: sobrantes)
        for peticion in peticiones {
            centro.add(peticion, withCompletionHandler: nil)
        }
    }

    private func peticion(
        id: String,
        contenido: ContenidoRecordatorio,
        fecha: Date,
        calendario: Calendar,
        esResumen: Bool
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = contenido.titulo
        content.body = contenido.cuerpo
        content.sound = .default
        if esResumen {
            content.userInfo = [MarcaAviso.tipo: MarcaAviso.resumenSemanal, MarcaAviso.conDatos: contenido.conDatos]
        }
        // Suelta y con fecha completa: una repetitiva conservaría el texto de
        // la semana en que se programó.
        let componentes = calendario.dateComponents([.year, .month, .day, .hour, .minute], from: fecha)
        let trigger = UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    /// Solo la caché local (SwiftData): esto corre al pasar a segundo plano y
    /// tras cada guardado, y no debe tocar la red.
    private func leerGastos() async -> [Expense] {
        do {
            return try await DependencyContainer.shared.expenseRepository.getExpenses(policy: .cacheOnly)
        } catch {
            logger.warning("Recordatorios sin caché de gastos: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - Apertura desde el resumen

    /// Lo llama el delegado de notificaciones al tocar un aviso. Solo el
    /// resumen con cifras deja pendiente la reseña: quien lo abre lleva una
    /// semana apuntando, que es el momento de éxito que busca
    /// `ReviewRequestManager`. El recordatorio sin gastos no cuenta.
    func avisoAbierto(tipo: String?, conDatos: Bool) {
        guard tipo == MarcaAviso.resumenSemanal, conDatos else { return }
        resenaPendienteDesde = Date()
        pedirResenaSiToca()
    }

    /// Pide la reseña si la app se abrió desde un resumen con cifras. Con la
    /// app aún sin estar delante o con la pantalla de bloqueo, la deja
    /// pendiente: `ClarityApp` vuelve a llamar al pasar a primer plano y al
    /// desbloquear. Pasados un par de minutos se olvida, para no salir en una
    /// apertura que ya no tiene nada que ver. Las reglas de siempre (a partir
    /// de la tercera sesión, una vez por versión, tres al año) las aplica
    /// `ReviewRequestManager`.
    func pedirResenaSiToca() {
        guard let desde = resenaPendienteDesde else { return }
        guard Date().timeIntervalSince(desde) < Self.margenResena else {
            resenaPendienteDesde = nil
            return
        }
        guard !estaBloqueada() else { return }

        Task { [weak self] in
            // Un momento para que se vea la app antes de la hoja del sistema.
            try? await Task.sleep(for: Self.esperaAntesDeResena)
            guard let self, self.resenaPendienteDesde != nil, !self.estaBloqueada(),
                  UIApplication.shared.applicationState == .active
            else { return }
            self.resenaPendienteDesde = nil
            ReviewRequestManager.shared.requestReviewIfAppropriate()
        }
    }
}

// MARK: - Ajustes

private extension RecordatoriosService {
    /// Lo que el usuario eligió en Notificaciones. `@AppStorage` no guarda su
    /// valor por defecto hasta que se cambia, así que sin clave se usa el de
    /// la pantalla.
    struct Ajustes {
        let push: Bool
        let semanal: Bool
        let diaSemanal: Int
        let horaSemanal: Int
        let minutoSemanal: Int
        let diario: Bool
        let horaDiario: Int
        let minutoDiario: Int

        /// Solo entonces hace falta leer los gastos.
        var hayAlgunoActivo: Bool { push && (semanal || diario) }

        init(_ defaults: UserDefaults) {
            push = defaults.bool(forKey: Clave.push)
            semanal = defaults.bool(forKey: Clave.semanal)
            diaSemanal = defaults.object(forKey: Clave.diaSemanal) as? Int ?? 1
            horaSemanal = defaults.object(forKey: Clave.horaSemanal) as? Int ?? 20
            minutoSemanal = defaults.object(forKey: Clave.minutoSemanal) as? Int ?? 0
            diario = defaults.bool(forKey: Clave.diario)
            horaDiario = defaults.object(forKey: Clave.horaDiario) as? Int ?? RecordatorioDiario.horaPorDefecto
            minutoDiario = defaults.object(forKey: Clave.minutoDiario) as? Int ?? 0
        }
    }
}
