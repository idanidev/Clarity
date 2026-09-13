// DictadoAttributes.swift
// Lo que la isla dinámica enseña mientras se dicta un gasto (#66).
//
// Existe dos veces, una en la app y otra en el widget, con el mismo nombre y la
// misma forma: ActivityKit empareja la actividad que pide la app con la vista
// del widget por el tipo. Si se cambia uno, se cambia el otro.

import ActivityKit
import Foundation

struct DictadoAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        enum Fase: String, Codable, Hashable {
            case escuchando, procesando, listo
        }
        var fase: Fase
        var texto: String
        var importe: Double?
    }
}
