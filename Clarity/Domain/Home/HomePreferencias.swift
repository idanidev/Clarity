// HomePreferencias.swift
// Qué tarjetas quiere ver el usuario en la Home y en qué orden (#69).
//
// La Home decide sola qué enseñar por relevancia; esto va por encima: lo que
// el usuario oculta no sale nunca, y lo que ordena gana el hueco aunque
// puntúe menos. Se guarda en el iPhone, no en la cuenta.

import Foundation

nonisolated struct HomePreferencias: Sendable, Equatable, Codable {
    /// Clases de contenido que no deben salir.
    var ocultas: Set<String> = []
    /// El orden del usuario: lo que va antes gana el hueco.
    var prioridad: [String] = []

    static let clave = "home.preferencias"

    /// Cada tarjeta que puede salir, con su nombre y para qué sirve.
    struct Tarjeta: Identifiable, Sendable, Equatable {
        let id: String
        let nombre: String
        let descripcion: String
    }

    /// El catálogo, en el orden por defecto en que se presenta al usuario.
    /// Los ids son las clases de `HomeResumen.Contenido`.
    static let tarjetas: [Tarjeta] = [
        Tarjeta(id: "limites", nombre: "Límites", descripcion: "Cómo van tus topes por categoría."),
        Tarjeta(id: "ahorro", nombre: "Ahorro previsto", descripcion: "Lo que te quedará si el mes sigue así."),
        Tarjeta(id: "cargos", nombre: "Próximos cargos", descripcion: "Recurrentes que aún no han pasado."),
        Tarjeta(id: "fueraDeNormal", nombre: "Fuera de lo normal", descripcion: "Una categoría muy por encima de tu costumbre."),
        Tarjeta(id: "teDeben", nombre: "Te deben", descripcion: "Gastos compartidos pendientes de devolver."),
        Tarjeta(id: "hucha", nombre: "Hucha", descripcion: "Tu hucha más avanzada."),
        Tarjeta(id: "reparto", nombre: "Dónde se te va", descripcion: "Las tres categorías que más pesan."),
        Tarjeta(id: "sitios", nombre: "Tus sitios", descripcion: "Los comercios a los que más vuelves."),
        Tarjeta(id: "comparativa", nombre: "Frente al mes pasado", descripcion: "El total a estas alturas, mes contra mes."),
        Tarjeta(id: "subeFuerte", nombre: "Sube fuerte", descripcion: "La categoría que más crece frente al mes pasado."),
        Tarjeta(id: "semana", nombre: "Esta semana", descripcion: "Frente a la semana pasada, hasta el mismo día."),
        Tarjeta(id: "semanaASemana", nombre: "Semana a semana", descripcion: "Lo gastado en cada semana del mes."),
        Tarjeta(id: "diaCaro", nombre: "Día más caro", descripcion: "El día que más gastaste este mes."),
        Tarjeta(id: "diaSemana", nombre: "Tu día caro", descripcion: "El día de la semana en que más gastas."),
        Tarjeta(id: "hormiga", nombre: "Gastos hormiga", descripcion: "Cuánto suman los gastos pequeños."),
        Tarjeta(id: "ranking", nombre: "Entre tus meses", descripcion: "Dónde cae este mes entre los anteriores."),
        Tarjeta(id: "racha", nombre: "Racha", descripcion: "Días seguidos apuntando."),
        Tarjeta(id: "limiteSugerido", nombre: "Un tope sugerido", descripcion: "Una categoría grande sin límite."),
    ]

    /// Todas las tarjetas en el orden del usuario: primero las que ordenó, después el resto.
    var ordenCompleto: [Tarjeta] {
        let porId = Dictionary(uniqueKeysWithValues: Self.tarjetas.map { ($0.id, $0) })
        let ordenadas = prioridad.compactMap { porId[$0] }
        let resto = Self.tarjetas.filter { !prioridad.contains($0.id) }
        return ordenadas + resto
    }

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
