// Diagnosticos.swift
// Arranque del registro de cuelgues: migas, su volcado a disco, vigilante y
// MetricKit.
//
// Para qué: que el próximo correo de soporte de quien sufre un cuelgue traiga
// datos sin que tenga que hacer nada especial. El resumen lo añade
// `SupportContact.diagnosticsFooter`.

import Foundation

enum Diagnosticos {
    /// Los tests corren dentro de la app: un test que ocupe el hilo principal no
    /// es un cuelgue, y su informe acabaría en el pie de un correo real.
    static var enTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Se llama una vez, desde el `AppDelegate`. En el hilo principal solo
    /// registra observadores; el trabajo va en la cola del vigilante.
    static func arranca() {
        guard !enTests else { return }

        // Antes de dejar ninguna miga: lo que volcó la sesión pasada se aparta
        // como "sesión anterior" para que esta no lo pise.
        VolcadoDeMigas.shared.arranca()

        Migas.deja("app: arranca")
        VigilanteDeCuelgues.shared.arranca()
        SuscriptorMetricKit.shared.arranca()
        MigasDeTeclado.arranca()
    }
}
