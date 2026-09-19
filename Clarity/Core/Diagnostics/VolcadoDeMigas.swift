// VolcadoDeMigas.swift
// Las migas de la sesión, a disco cada vez que la app deja de estar delante.
//
// Cubre lo que el vigilante no ve: una interfaz que se traga los toques con el
// hilo principal vivo. Ahí los pings se contestan, no hay informe de cuelgue y
// quien usa la app acaba cerrándola a mano; las migas, que viven en memoria, se
// irían con ella. Pero para cerrarla hay que subir al selector de apps, y eso
// dispara `willResignActive` (y casi siempre `didEnterBackground`): ese es el
// momento de guardarlas. En el arranque siguiente pasan a ser "la sesión
// anterior", y de ahí, al pie del correo de soporte si no hay informe de cuelgue.
//
// PRIVACIDAD: lo que se vuelca son las migas tal cual. Vale el aviso de `Migas`:
// solo nombres de pantalla y de acción.

import Foundation
import OSLog
import UIKit

/// Las migas de una sesión, tal como quedan en disco.
nonisolated struct SesionDeMigas: Codable, Equatable, Sendable {
    /// Cuándo se volcó por última vez: hasta dónde llega lo que se sabe de ella.
    var volcado: Date
    var versionApp: String
    var build: String
    var migas: [Miga]
}

nonisolated final class VolcadoDeMigas: Sendable {
    static let shared = VolcadoDeMigas()

    /// En serie: la rotación del arranque se encola la primera y así ningún
    /// volcado de esta sesión puede adelantarse y pisar el de la anterior.
    private let cola = DispatchQueue(label: "com.idanidev.clarity.volcado-de-migas", qos: .utility)
    private let almacen: AlmacenDeDiagnosticos
    private let registro: RegistroDeMigas

    init(almacen: AlmacenDeDiagnosticos = .porDefecto, registro: RegistroDeMigas = Migas.registro) {
        self.almacen = almacen
        self.registro = registro
    }

    /// Lo primero del arranque. En el hilo principal solo encola la rotación y
    /// registra dos observadores.
    @MainActor
    func arranca() {
        rota()

        let avisos: [(Notification.Name, String)] = [
            // Subir al selector de apps, bajar el Centro de Control, una llamada…
            (UIApplication.willResignActiveNotification, "app: deja de estar activa"),
            (UIApplication.didEnterBackgroundNotification, "app: a segundo plano"),
        ]
        for (aviso, miga) in avisos {
            _ = NotificationCenter.default.addObserver(forName: aviso, object: nil, queue: nil) { [weak self] _ in
                guard let self else { return }
                self.registro.deja(miga)
                self.vuelca()
            }
        }
    }

    /// La sesión que quedó en disco pasa a ser "la anterior".
    func rota() {
        cola.async { [almacen] in almacen.rotaSesion() }
    }

    /// En el hilo que llama, solo la foto de las migas (un candado y copiar 40
    /// entradas); codificar y escribir va en la cola. Entre que se sube al
    /// selector de apps y se cierra la app pasa de sobra el tiempo que necesita.
    func vuelca() {
        let migas = registro.copia()
        let volcado = Date()
        cola.async { [almacen] in
            almacen.guardaSesion(SesionDeMigas(
                volcado: volcado,
                versionApp: DatosDelAparato.versionApp,
                build: DatosDelAparato.build,
                migas: migas
            ))
        }
    }

    /// Para los tests: vuelve cuando la cola ha terminado lo pendiente.
    func esperaAlDisco() {
        cola.sync {}
    }
}

// MARK: - En disco

// `nonisolated` explícito en las dos extensiones: con el aislamiento por defecto
// del proyecto, los miembros de una extensión salen del hilo principal aunque el
// tipo no lo sea, y esto se llama desde la cola del volcado.
nonisolated extension AlmacenDeDiagnosticos {
    static let nombreMigasDeSesion = "migas_sesion.json"
    static let nombreMigasDeSesionAnterior = "migas_sesion_anterior.json"

    var urlMigasDeSesion: URL {
        carpeta.appendingPathComponent(Self.nombreMigasDeSesion)
    }

    var urlMigasDeSesionAnterior: URL {
        carpeta.appendingPathComponent(Self.nombreMigasDeSesionAnterior)
    }

    /// Escritura atómica, como el informe: si cierran la app a media escritura,
    /// queda entero el volcado de antes. La carpeta ya está fuera de la copia de
    /// iCloud (`preparaCarpeta`).
    func guardaSesion(_ sesion: SesionDeMigas) {
        do {
            try preparaCarpeta()
            try Self.codifica(sesion).write(to: urlMigasDeSesion, options: .atomic)
        } catch {
            Self.registroDelSistema.error("No se pudieron volcar las migas de la sesión: \(error.localizedDescription)")
        }
    }

    func sesionAnterior() -> SesionDeMigas? {
        guard let datos = try? Data(contentsOf: urlMigasDeSesionAnterior) else { return nil }
        return try? Self.decodifica(SesionDeMigas.self, de: datos)
    }

    /// `migas_sesion.json` → `migas_sesion_anterior.json`. Si la sesión pasada no
    /// llegó a volcar nada, la anterior que hubiera se queda: su fecha va en el
    /// pie, así que no engaña.
    func rotaSesion() {
        let archivos = FileManager.default
        guard archivos.fileExists(atPath: urlMigasDeSesion.path) else { return }
        do {
            if archivos.fileExists(atPath: urlMigasDeSesionAnterior.path) {
                try archivos.removeItem(at: urlMigasDeSesionAnterior)
            }
            try archivos.moveItem(at: urlMigasDeSesion, to: urlMigasDeSesionAnterior)
        } catch {
            Self.registroDelSistema.error("No se pudieron rotar las migas de la sesión: \(error.localizedDescription)")
        }
    }
}

// MARK: - En el pie del correo

nonisolated extension ResumenDeCuelgue {
    /// Bloque "Sesión anterior" del pie. Mismo tope y mismas doce migas que el
    /// del cuelgue. Sin migas no hay bloque.
    ///
    /// - Parameter cuelguePrevio: un cuelgue más viejo que esta sesión. No lleva
    ///   bloque propio, solo una línea al final para que conste que lo hubo.
    static func paraElPie(
        _ sesion: SesionDeMigas,
        cuelguePrevio: InformeDeCuelgue? = nil,
        zona: TimeZone = .current,
        tope: Int = topeDeCaracteres
    ) -> String {
        guard !sesion.migas.isEmpty else { return "" }
        let dia = formateador("yyyy-MM-dd HH:mm:ss Z", zona: zona)
        let cabecera = """


        Sesión anterior (hasta \(dia.string(from: sesion.volcado))) · Clarity \(sesion.versionApp) (\(sesion.build))
        """
        let cierre = cuelguePrevio.map {
            "\nCuelgue previo: \(dia.string(from: $0.fecha)), \(String(format: "%.1f", $0.segundosBloqueado)) s"
        } ?? ""
        return conMigas(sesion.migas, tras: cabecera, cierre: cierre, zona: zona, tope: tope)
    }
}
