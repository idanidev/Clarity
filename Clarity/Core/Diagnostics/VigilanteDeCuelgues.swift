// VigilanteDeCuelgues.swift
// Un hilo aparte que comprueba, una vez por segundo, que el principal sigue vivo.
//
// Le manda un ping (`DispatchQueue.main.async`) y espera la respuesta. Si pasan
// más de tres segundos sin ella, el hilo principal está colgado y el vigilante
// escribe un informe en disco DESDE SU PROPIO HILO y de forma síncrona: al
// principal no se le puede pedir nada. Mientras dura, reescribe la duración cada
// poco, porque lo normal es que quien usa la app acabe cerrándola a mano y lo
// último escrito sea lo único que quede.
//
// Lo que NO ve: una interfaz que no responde con el hilo principal vivo (algo
// transparente que se traga los toques, por ejemplo). Ahí los pings se contestan
// y no hay informe: de ese caso se ocupa `VolcadoDeMigas`.

import Foundation
import OSLog
import UIKit

// MARK: - Decisión (pura)

nonisolated enum DeteccionDeCuelgue {
    enum Veredicto: Equatable, Sendable {
        case responde
        case colgado(segundos: TimeInterval)
    }

    /// Por debajo de esto es un tirón, no un cuelgue.
    static let umbral: TimeInterval = 3

    /// ¿Está colgado el hilo principal?
    ///
    /// - Parameters:
    ///   - ahora: instante actual, en un reloj monótono.
    ///   - pingSinResponderDesde: cuándo se mandó el ping que sigue sin
    ///     respuesta; `nil` si no hay ninguno pendiente.
    static func veredicto(
        ahora: TimeInterval,
        pingSinResponderDesde: TimeInterval?,
        umbral: TimeInterval = umbral
    ) -> Veredicto {
        guard let desde = pingSinResponderDesde else { return .responde }
        let espera = ahora - desde
        return espera > umbral ? .colgado(segundos: espera) : .responde
    }
}

// MARK: - Seguimiento (puro)

/// La máquina de estados del vigilante, sin hilos, sin reloj y sin disco: recibe
/// instantes y devuelve qué toca hacer. `VigilanteDeCuelgues` solo obedece.
nonisolated struct SeguimientoDeCuelgue: Equatable, Sendable {
    enum Orden: Equatable, Sendable {
        case nada
        case mandaPing
        /// Escribir el informe con esta duración. `recuperado` cierra el episodio.
        case escribe(segundos: TimeInterval, recuperado: Bool)
    }

    /// Cada cuánto corre una ronda.
    var intervalo: TimeInterval = 1
    var umbral: TimeInterval = DeteccionDeCuelgue.umbral
    /// Con el principal colgado, cada cuánto se reescribe la duración.
    var cadaCuantoReescribir: TimeInterval = 2
    /// Si el propio vigilante lleva más de esto sin correr, no es que el
    /// principal esté colgado: es que el proceso entero estuvo parado.
    var saltoDeSuspension: TimeInterval = 5

    private(set) var pingDesde: TimeInterval?
    private(set) var ultimaRonda: TimeInterval?
    /// Duración escrita por última vez en este episodio; `nil` si no hay cuelgue.
    private(set) var ultimaDuracionEscrita: TimeInterval?

    /// Una ronda del temporizador.
    mutating func ronda(ahora: TimeInterval) -> Orden {
        // El sistema suspende el proceso (o un punto de ruptura lo para) con
        // todos sus hilos a la vez. Ese hueco no es tiempo de cuelgue: se
        // descuenta del ping pendiente en vez de contarlo como bloqueo.
        if let ultima = ultimaRonda, let desde = pingDesde, ahora - ultima > saltoDeSuspension {
            pingDesde = desde + (ahora - ultima - intervalo)
        }
        ultimaRonda = ahora

        guard let desde = pingDesde else {
            // Un solo ping en vuelo: mandar otro cada segundo a un hilo colgado
            // solo le dejaría una cola de bloques que atender al despertar.
            pingDesde = ahora
            return .mandaPing
        }

        switch DeteccionDeCuelgue.veredicto(ahora: ahora, pingSinResponderDesde: desde, umbral: umbral) {
        case .responde:
            return .nada
        case .colgado(let segundos):
            if let escrita = ultimaDuracionEscrita, segundos - escrita < cadaCuantoReescribir {
                return .nada
            }
            ultimaDuracionEscrita = segundos
            return .escribe(segundos: segundos, recuperado: false)
        }
    }

    /// El hilo principal ha contestado al ping en el instante `ahora`.
    mutating func respuesta(ahora: TimeInterval) -> Orden {
        guard let desde = pingDesde else { return .nada }
        pingDesde = nil
        guard ultimaDuracionEscrita != nil else { return .nada }
        ultimaDuracionEscrita = nil
        return .escribe(segundos: ahora - desde, recuperado: true)
    }

    /// La app pasa a segundo plano. El aviso lo reparte el hilo principal, así que
    /// si llega es que está vivo: vale como respuesta, y el ping pendiente se
    /// olvida para que la suspensión que viene no cuente.
    mutating func pausa(ahora: TimeInterval) -> Orden {
        let orden = respuesta(ahora: ahora)
        pingDesde = nil
        ultimaRonda = nil
        return orden
    }
}

// MARK: - Vigilante

nonisolated final class VigilanteDeCuelgues: @unchecked Sendable {
    static let shared = VigilanteDeCuelgues()

    /// `.utility`: el trabajo es mínimo y, con el principal dando vueltas en un
    /// núcleo, quedan otros libres. No es `.background`, que el sistema puede
    /// dejar sin correr justo cuando hace falta.
    private let cola = DispatchQueue(label: "com.idanidev.clarity.vigilante-de-cuelgues", qos: .utility)
    private let almacen: AlmacenDeDiagnosticos
    private let registro: RegistroDeMigas

    // Todo lo de abajo se toca SOLO desde `cola`; de ahí el `@unchecked Sendable`.
    private var seguimiento: SeguimientoDeCuelgue
    private var temporizador: DispatchSourceTimer?
    /// El cuelgue en curso, ya en disco.
    private var enCurso: InformeDeCuelgue?
    /// Lo que había en disco antes de este cuelgue. Ver `InformeDeCuelgue.queConservar`.
    private var anterior: InformeDeCuelgue?

    /// - Parameter seguimiento: los tests lo pasan con un ritmo más vivo para no
    ///   tener que bloquear el hilo principal varios segundos.
    init(
        almacen: AlmacenDeDiagnosticos = .porDefecto,
        registro: RegistroDeMigas = Migas.registro,
        seguimiento: SeguimientoDeCuelgue = SeguimientoDeCuelgue()
    ) {
        self.almacen = almacen
        self.registro = registro
        self.seguimiento = seguimiento
    }

    /// Reloj monótono: no salta si cambia la hora del aparato y no corre con el
    /// aparato dormido.
    private static func reloj() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    // MARK: Arranque

    /// En el hilo principal solo registra dos observadores; lo demás va a `cola`.
    @MainActor
    func arranca() {
        let centro = NotificationCenter.default

        // En segundo plano el sistema suspende el proceso: el hilo principal deja
        // de contestar sin estar colgado. Se para al salir y se retoma al volver.
        // (La miga de "a segundo plano" la deja `VolcadoDeMigas`, justo antes de
        // volcar, para que entre seguro en el archivo.)
        _ = centro.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.pausa()
        }
        _ = centro.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            Migas.deja("app: vuelve")
            self?.reanuda()
        }

        // Si el sistema lanza la app ya en segundo plano, espera al primer regreso.
        if UIApplication.shared.applicationState != .background {
            reanuda()
        }
    }

    func pausa() {
        let ahora = Self.reloj()
        cola.async {
            self.temporizador?.cancel()
            self.temporizador = nil
            self.aplica(self.seguimiento.pausa(ahora: ahora))
        }
    }

    func reanuda() {
        cola.async {
            guard self.temporizador == nil else { return }
            let intervalo = self.seguimiento.intervalo
            // Nunca se suspende: se crea, se activa y, al pausar, se cancela. Un
            // `DispatchSource` suspendido que se cancela o se libera revienta.
            let temporizador = DispatchSource.makeTimerSource(queue: self.cola)
            temporizador.schedule(deadline: .now() + intervalo, repeating: intervalo, leeway: .milliseconds(100))
            temporizador.setEventHandler { [weak self] in
                guard let self else { return }
                self.aplica(self.seguimiento.ronda(ahora: Self.reloj()))
            }
            temporizador.resume()
            self.temporizador = temporizador
        }
    }

    // MARK: En `cola`

    private func aplica(_ orden: SeguimientoDeCuelgue.Orden) {
        switch orden {
        case .nada:
            break
        case .mandaPing:
            mandaPing()
        case .escribe(let segundos, let recuperado):
            anota(segundos: segundos, recuperado: recuperado)
        }
    }

    private func mandaPing() {
        DispatchQueue.main.async { [weak self] in
            // En el principal, lo justo: mirar la hora y devolver el testigo.
            guard let self else { return }
            let respondido = Self.reloj()
            self.cola.async {
                self.aplica(self.seguimiento.respuesta(ahora: respondido))
            }
        }
    }

    private func anota(segundos: TimeInterval, recuperado: Bool) {
        var informe = enCurso ?? nuevoInforme()
        informe.segundosBloqueado = (segundos * 10).rounded() / 10
        informe.recuperado = recuperado

        guard recuperado else {
            enCurso = informe
            almacen.guarda(informe)
            return
        }

        almacen.guarda(InformeDeCuelgue.queConservar(anterior: anterior, recuperado: informe))
        enCurso = nil
        anterior = nil
        // Para el siguiente informe: que se vea que ya hubo uno en esta sesión.
        registro.deja("cuelgue: \(informe.segundosBloqueado) s, recuperado")
        AlmacenDeDiagnosticos.registroDelSistema.warning("Hilo principal recuperado tras \(informe.segundosBloqueado) s")
    }

    /// Empieza un episodio: las migas son las de este instante, que es cuando
    /// cuentan lo que llevó al cuelgue.
    private func nuevoInforme() -> InformeDeCuelgue {
        anterior = almacen.ultimoCuelgue()
        AlmacenDeDiagnosticos.registroDelSistema.warning("Hilo principal bloqueado: se escribe informe de cuelgue")
        return InformeDeCuelgue(
            fecha: Date(),
            segundosBloqueado: 0,
            recuperado: false,
            versionApp: DatosDelAparato.versionApp,
            build: DatosDelAparato.build,
            versionIOS: DatosDelAparato.versionIOS,
            modelo: DatosDelAparato.modelo,
            migas: registro.copia()
        )
    }
}
