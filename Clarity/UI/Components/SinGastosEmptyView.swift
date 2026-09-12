// SinGastosEmptyView.swift
// Estado vacío por no haber gastos todavía (#65).
//
// Seis pantallas decían "Sin datos para gráficos", "Sin datos para calendario",
// "No hay gastos para comparar"… y ahí se acababa el camino. Todas dicen lo
// mismo por el mismo motivo —no hay gastos en el periodo— y todas tienen la
// misma salida, que es apuntar uno; lo único que faltaba era ofrecerla.
//
// Es un `ContentUnavailableView` por dentro a propósito: hereda el tamaño, el
// espaciado y el comportamiento con Dynamic Type que ya trae iOS en vez de
// reinventarlos.

import SwiftUI

struct SinGastosEmptyView: View {
    let titulo: String
    let mensaje: String
    let icono: String
    let accion: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(titulo, systemImage: icono)
        } description: {
            Text(mensaje)
        } actions: {
            Button {
                HapticManager.shared.selection()
                AnalyticsService.shared.track(.emptyStateAction(method: "manual"))
                accion()
            } label: {
                Text("Apuntar un gasto")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.clarityPrimary)
        }
    }
}

#Preview("Gráficos") {
    SinGastosEmptyView(
        titulo: "Todavía no hay nada que enseñar",
        mensaje: "En cuanto apuntes un gasto verás aquí en qué se te va el mes.",
        icono: "chart.pie",
        accion: {}
    )
}

#Preview("Comparación") {
    SinGastosEmptyView(
        titulo: "Aún no hay meses que comparar",
        mensaje: "Necesitas gastos en al menos un mes para ver la comparación.",
        icono: "chart.bar",
        accion: {}
    )
}
