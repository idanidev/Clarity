// SuscriptorMetricKit.swift
// Lo que el sistema sabe de los cuelgues y el vigilante no: la pila de llamadas.
//
// MetricKit entrega sus diagnósticos cuando le parece —lo normal, en el arranque
// siguiente— y en un hilo suyo. Aquí solo se guardan, tal cual llegan, los que
// traen cuelgues (`hangDiagnostics`); el resto no interesa para esto y pesa.

import Foundation
import MetricKit

/// `nonisolated`: MetricKit llama a `didReceive` desde un hilo en segundo plano.
/// Sin estado mutable, así que no hay nada que proteger.
nonisolated final class SuscriptorMetricKit: NSObject, MXMetricManagerSubscriber, Sendable {
    static let shared = SuscriptorMetricKit()

    private let almacen: AlmacenDeDiagnosticos

    init(almacen: AlmacenDeDiagnosticos = .porDefecto) {
        self.almacen = almacen
    }

    func arranca() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let conCuelgues = payloads.filter { !($0.hangDiagnostics ?? []).isEmpty }
        guard !conCuelgues.isEmpty else { return }

        // Misma fecha para toda la entrega; el índice distingue un payload de otro.
        let recibido = Date()
        for (indice, payload) in conCuelgues.enumerated() {
            almacen.guardaMetricKit(payload.jsonRepresentation(), fecha: recibido, indice: indice)
        }
    }
}
