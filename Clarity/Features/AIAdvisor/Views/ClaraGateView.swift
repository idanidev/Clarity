// ClaraGateView.swift
// Decide qué ve el usuario en la pestaña de Clara.
//
// Clara estuvo deshabilitada porque dependía de proveedores remotos con clave:
// una compilada en la app —que cualquiera puede extraer— y otra que el usuario
// tenía que conseguir por su cuenta. Con el modelo de Apple Intelligence no hay
// clave, no hay coste y los datos no salen del iPhone, así que vuelve para
// quien tenga el hardware.
//
// Para el resto no se enseña una promesa: se dice por qué no puede ser.

import SwiftUI

struct ClaraGateView: View {
    var body: some View {
        if AIServiceManager.shared.puedeUsarModeloLocal {
            AIAdvisorView()
        } else {
            AIDisabledView(motivo: AIServiceManager.shared.motivoModeloLocal)
        }
    }
}
