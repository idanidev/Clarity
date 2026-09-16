// PersonalizarHomeSheet.swift
// Qué tarjetas salen en la Home y en qué orden (#69).

import SwiftUI

struct PersonalizarHomeSheet: View {
    @Bindable var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.preferencias.ordenCompleto) { tarjeta in
                        fila(tarjeta)
                    }
                    .onMove { desde, hasta in
                        var orden = viewModel.preferencias.ordenCompleto.map(\.id)
                        orden.move(fromOffsets: desde, toOffset: hasta)
                        viewModel.preferencias.prioridad = orden
                    }
                } header: {
                    Text("Arrastra para ordenar y apaga las que no quieras ver")
                } footer: {
                    Text("La Home tiene cuatro huecos y enseña, de las que dejes encendidas, las que más pesen ese día; las de arriba van primero.")
                }

                Section {
                    Button("Volver a lo de siempre", role: .destructive) {
                        viewModel.preferencias = HomePreferencias()
                        HapticManager.shared.selection()
                    }
                    .disabled(viewModel.preferencias == HomePreferencias())
                }
            }
            // Siempre con los tiradores de arrastrar: es una lista para ordenar.
            .environment(\.editMode, .constant(.active))
            .fondoClarity()
            .navigationTitle("Tarjetas de la Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hecho") { dismiss() }
                }
            }
        }
        .sinHuecoBarraInferior()
    }

    private func fila(_ tarjeta: HomePreferencias.Tarjeta) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tarjeta.nombre).font(.subheadline.weight(.medium))
                Text(tarjeta.descripcion).font(.caption).foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { !viewModel.preferencias.ocultas.contains(tarjeta.id) },
                set: { visible in
                    if visible { viewModel.preferencias.ocultas.remove(tarjeta.id) }
                    else { viewModel.preferencias.ocultas.insert(tarjeta.id) }
                }
            ))
            .labelsHidden()
            .tint(Color.clarityPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tarjeta.nombre), \(viewModel.preferencias.ocultas.contains(tarjeta.id) ? "oculta" : "visible")")
    }
}
