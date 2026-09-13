// DictarGastoIntent.swift
// Abre Clarity escuchando. Lo usan el control del Centro de Control, la
// pantalla bloqueada y el Botón de Acción.

import AppIntents
import Foundation

struct DictarGastoIntent: AppIntent {
    static let title: LocalizedStringResource = "Dictar un gasto"
    static let description = IntentDescription("Abre Clarity y empieza a escuchar para apuntar un gasto por voz.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // La app lo recoge al activarse y arranca el micro.
        UserDefaults(suiteName: "group.com.idanidev.clarity")?.set(true, forKey: "widget_start_voice")
        return .result()
    }
}
