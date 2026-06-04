// KeyboardDoneToolbar.swift
// Modifier reutilizable: añade botón "Hecho" sobre el teclado + swipe-to-dismiss.
// Resuelve teclados .decimalPad/.numberPad que no traen tecla de retorno y
// dejaban al usuario sin forma de cerrar el teclado.
// No requiere FocusState — usa resignFirstResponder global.

import SwiftUI

extension View {
    /// Añade una toolbar de teclado con botón "Hecho" + cierre interactivo al
    /// deslizar. Aplicar sobre el contenedor scrollable (Form / List / ScrollView).
    func keyboardDoneToolbar() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Hecho") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                    .fontWeight(.semibold)
                }
            }
    }
}
