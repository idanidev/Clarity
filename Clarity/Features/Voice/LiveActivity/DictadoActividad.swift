// DictadoActividad.swift
// Arranca, actualiza y cierra la isla dinámica mientras se dicta (#66).

import ActivityKit
import Foundation

@MainActor
final class DictadoActividad {
    static let shared = DictadoActividad()

    private var actividad: Activity<DictadoAttributes>?
    private var ultimaActualizacion = Date.distantPast

    private init() {}

    func empezar() {
        guard actividad == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let estado = DictadoAttributes.ContentState(fase: .escuchando, texto: "", importe: nil)
        actividad = try? Activity.request(
            attributes: DictadoAttributes(),
            content: .init(state: estado, staleDate: nil),
            pushType: nil
        )
    }

    /// El sistema limita cuántas actualizaciones acepta: se manda como mucho
    /// una cada medio segundo, que para leer lo dictado sobra.
    func actualizar(texto: String) {
        guard let actividad, Date().timeIntervalSince(ultimaActualizacion) > 0.5 else { return }
        ultimaActualizacion = Date()
        let estado = DictadoAttributes.ContentState(fase: .escuchando, texto: texto, importe: Self.importe(en: texto))
        Task { await actividad.update(.init(state: estado, staleDate: nil)) }
    }

    func procesando(texto: String) {
        guard let actividad else { return }
        let estado = DictadoAttributes.ContentState(fase: .procesando, texto: texto, importe: Self.importe(en: texto))
        Task { await actividad.update(.init(state: estado, staleDate: nil)) }
    }

    /// Cierra con el resultado a la vista unos segundos. Sin importe, se va ya.
    func terminar(texto: String, importe: Double?) {
        guard let actividad else { return }
        self.actividad = nil
        let estado = DictadoAttributes.ContentState(fase: .listo, texto: texto, importe: importe)
        let politica: ActivityUIDismissalPolicy = importe == nil ? .immediate : .after(.now + 4)
        Task { await actividad.end(.init(state: estado, staleDate: nil), dismissalPolicy: politica) }
    }

    /// El primer importe que aparece en lo dictado: "20 euros", "3,50".
    static func importe(en texto: String) -> Double? {
        guard let rango = texto.range(of: #"\d+(?:[.,]\d{1,2})?"#, options: .regularExpression) else { return nil }
        return Double(texto[rango].replacingOccurrences(of: ",", with: "."))
    }
}
