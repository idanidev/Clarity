// ClarityWidgetControl.swift
// "Dictar gasto" como control: se añade al Centro de Control, a la pantalla
// bloqueada o se asigna al Botón de Acción, y apuntar un gasto pasa a ser un
// botón físico. La voz es lo que diferencia a Clarity; esto la saca de la app.

import AppIntents
import SwiftUI
import WidgetKit

struct DictarGastoControl: ControlWidget {
    static let kind = "com.idanidev.clarity.dictar"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: DictarGastoIntent()) {
                Label("Dictar gasto", systemImage: "mic.fill")
            }
        }
        .displayName("Dictar un gasto")
        .description("Abre Clarity escuchando para apuntar un gasto por voz.")
    }
}
