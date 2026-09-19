// VeloDePrivacidad.swift
// Lo que se ve de Clarity en el selector de apps cuando el bloqueo está activado.

import SwiftUI

/// Tapa la app mientras no está activa: el fondo de siempre y el icono, nada más.
///
/// Con el bloqueo biométrico activado, la miniatura del selector de apps seguía
/// enseñando los importes: el bloqueo protegía la app al volver, pero no la foto
/// que el sistema hace al salir. Esta capa es opaca (`HomeFondo` pinta sobre el
/// fondo de la app) y no lleva texto: no hay nada que leer ni que anunciar.
///
/// La pone y la quita `ClarityApp` según la fase de la escena. No pide nada para
/// quitarse: eso es cosa de `AppLockManager`.
///
/// Límite conocido: vive en la ventana de la app, debajo de las hojas. Una hoja
/// abierta (el formulario de un gasto, por ejemplo) sale en la miniatura; lo de
/// detrás, no. A `LockScreenView` le pasa lo mismo.
struct VeloDePrivacidad: View {
    var body: some View {
        ZStack {
            HomeFondo()

            // El mismo icono, con el mismo tratamiento, que la pantalla de entrada.
            Image("HomeIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                .shadow(color: Color.clarityPrimary.opacity(0.55), radius: 28, y: 10)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VeloDePrivacidad()
}
