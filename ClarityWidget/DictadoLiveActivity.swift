// DictadoLiveActivity.swift
// La isla dinámica mientras se dicta un gasto, y su versión de pantalla bloqueada (#66).

import ActivityKit
import SwiftUI
import WidgetKit

private let violeta = Color(red: 0.545, green: 0.361, blue: 0.965)

struct DictadoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DictadoAttributes.self) { context in
            HStack(spacing: 14) {
                icono(context.state.fase)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(violeta.opacity(0.25), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo(context.state.fase)).font(.headline)
                    Text(context.state.texto.isEmpty ? "Di el gasto…" : context.state.texto)
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if let importe = context.state.importe {
                    Text(importe, format: .currency(code: "EUR"))
                        .font(.title3.weight(.bold)).monospacedDigit()
                }
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.75))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    icono(context.state.fase).font(.title2).foregroundStyle(violeta).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let importe = context.state.importe {
                        Text(importe, format: .currency(code: "EUR"))
                            .font(.title3.weight(.bold)).monospacedDigit()
                            .contentTransition(.numericText(value: importe))
                    } else {
                        Text(titulo(context.state.fase)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.texto.isEmpty ? "Di el gasto…" : context.state.texto)
                        .font(.callout).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                icono(context.state.fase).foregroundStyle(violeta)
            } compactTrailing: {
                if let importe = context.state.importe {
                    Text(importe, format: .currency(code: "EUR")).font(.caption.weight(.semibold)).monospacedDigit()
                } else {
                    Image(systemName: "ellipsis").foregroundStyle(.secondary)
                }
            } minimal: {
                icono(context.state.fase).foregroundStyle(violeta)
            }
            .keylineTint(violeta)
        }
    }

    @ViewBuilder
    private func icono(_ fase: DictadoAttributes.ContentState.Fase) -> some View {
        switch fase {
        case .escuchando: Image(systemName: "waveform").symbolEffect(.variableColor.iterative)
        case .procesando: Image(systemName: "sparkles")
        case .listo: Image(systemName: "checkmark.circle.fill")
        }
    }

    private func titulo(_ fase: DictadoAttributes.ContentState.Fase) -> String {
        switch fase {
        case .escuchando: "Escuchando"
        case .procesando: "Apuntando…"
        case .listo: "Apuntado"
        }
    }
}
