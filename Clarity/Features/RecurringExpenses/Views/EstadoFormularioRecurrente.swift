// EstadoFormularioRecurrente.swift
// Foto de lo que el usuario puede tocar en el formulario de un recurrente.

import Foundation

/// Los formularios de crear y editar un recurrente guardan sus campos en `@State`
/// sueltos. Para saber si hay algo que perder al cancelar (`confirmarDescarte`)
/// se hace una foto al abrir y se compara con la de ahora: si son iguales, el
/// usuario no ha cambiado nada —o lo ha dejado como estaba— y la hoja se cierra
/// sin preguntar.
struct EstadoFormularioRecurrente: Equatable {
    var importe: String
    var nombre: String
    var categoria: String
    var subcategoria: String?
    var metodoDePago: String
    var frecuencia: RecurringFrequency
    var dia: Int
    var mesDeCobro: Int
    var icono: String
    var fin: FinRecurrente
    var fechaFin: Date
    var plazos: Int
}
