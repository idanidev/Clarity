// HomePreferencias.swift
// Qué tarjetas quería ver el usuario en la Home y en qué orden (#69).
//
// Hasta la 2.3 la Home decidía sola qué enseñar por relevancia y esto iba por
// encima: lo que el usuario ocultaba no salía, y lo que ordenaba ganaba el
// hueco aunque puntuara menos. Se guardaba en el iPhone, no en la cuenta.
//
// Desde la 2.4 manda `HomeDisposicion`, que se edita en la propia Home. Esto
// queda para migrar lo que había (`HomeDisposicion.migrada`) y para el
// desempate de las pilas (`bonus`), que sigue siendo el de siempre.

import Foundation

nonisolated struct HomePreferencias: Sendable, Equatable, Codable {
    /// Clases de contenido que no deben salir.
    var ocultas: Set<String> = []
    /// El orden del usuario: lo que va antes gana el hueco.
    var prioridad: [String] = []

    static let clave = "home.preferencias"

    /// Lo que suma una clase por estar en la lista del usuario: por delante de
    /// cualquier relevancia automática (que va de 0 a 1), y entre ellas, en su orden.
    func bonus(_ clase: String) -> Double {
        guard let i = prioridad.firstIndex(of: clase) else { return 0 }
        return 2 - Double(i) * 0.01
    }

    static func cargar(de defaults: UserDefaults = .standard) -> HomePreferencias {
        guard let data = defaults.data(forKey: clave),
              let preferencias = try? JSONDecoder().decode(HomePreferencias.self, from: data)
        else { return HomePreferencias() }
        return preferencias
    }

    func guardar(en defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.clave) }
    }
}
