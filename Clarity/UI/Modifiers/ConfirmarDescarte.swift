// ConfirmarDescarte.swift
// Ningún formulario tira lo escrito sin preguntar.
//
// Antes «Cancelar» cerraba la hoja sin más y deslizarla hacia abajo también: un
// gesto de más y se perdía un gasto a medio escribir. Con cambios, la hoja deja
// de cerrarse deslizando y «Cancelar» pregunta. Sin cambios, todo como siempre.

import SwiftUI

extension View {
    /// Protege un formulario presentado como hoja contra el descarte accidental.
    ///
    /// - Parameters:
    ///   - preguntando: lo enciende `BotonCancelarFormulario` cuando hay cambios.
    ///   - hayCambios: si el estado difiere del inicial. Es un `@autoclosure` a
    ///     propósito: se evalúa DENTRO del `body` del modificador y no en el de la
    ///     hoja, así que la hoja no pasa a depender de todos los campos del
    ///     formulario (se reevaluaría entera en cada tecla; ver las reglas de
    ///     rendimiento de `CLAUDE.md`). El que se reevalúa es este modificador,
    ///     que no pinta nada.
    ///   - descartar: cierra la hoja. Solo se llama tras confirmar.
    func confirmarDescarte(
        preguntando: Binding<Bool>,
        hayCambios: @autoclosure @escaping () -> Bool,
        descartar: @escaping () -> Void
    ) -> some View {
        modifier(ConfirmarDescarteModifier(
            preguntando: preguntando, hayCambios: hayCambios, descartar: descartar))
    }
}

private struct ConfirmarDescarteModifier: ViewModifier {
    @Binding var preguntando: Bool
    let hayCambios: () -> Bool
    let descartar: () -> Void

    func body(content: Content) -> some View {
        content
            // Deslizar hacia abajo no avisa de que se intenta cerrar, así que no
            // hay dónde preguntar: con cambios, la hoja solo sale por «Cancelar».
            .interactiveDismissDisabled(hayCambios())
            .confirmationDialog(
                "¿Descartar los cambios?",
                isPresented: $preguntando,
                titleVisibility: .visible
            ) {
                Button("Descartar", role: .destructive) { descartar() }
                Button("Seguir editando", role: .cancel) { }
            }
    }
}

/// El «Cancelar» de un formulario con `confirmarDescarte`: sin cambios cierra;
/// con cambios, pregunta.
///
/// `hayCambios` se lee al pulsar y no en el `body`: el botón no se repinta
/// mientras se escribe.
struct BotonCancelarFormulario: View {
    @Binding var preguntando: Bool
    let hayCambios: () -> Bool
    let cerrar: () -> Void

    init(
        preguntando: Binding<Bool>,
        hayCambios: @autoclosure @escaping () -> Bool,
        cerrar: @escaping () -> Void
    ) {
        _preguntando = preguntando
        self.hayCambios = hayCambios
        self.cerrar = cerrar
    }

    var body: some View {
        Button("Cancelar") {
            guard hayCambios() else {
                cerrar()
                return
            }
            // El teclado se recoge ANTES de preguntar. Si no, el sistema lo
            // esconde al salir el diálogo y lo repone al cerrarlo, y ese quita y
            // pon —con la barra de «Hecho» colgada del teclado— es justo la zona
            // donde las hojas de gasto se han quedado colgadas en algunos iOS.
            // Sin campo activo no hay nada que reponer.
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
            Migas.deja("formulario: pregunta descarte")
            preguntando = true
        }
    }
}
