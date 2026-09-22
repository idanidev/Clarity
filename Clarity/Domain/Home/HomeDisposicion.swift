// HomeDisposicion.swift
// Qué tarjetas lleva la Home, en qué orden y de qué tamaño (2.4.0).
//
// Hasta la 2.3 la Home tenía cuatro huecos fijos y el usuario solo podía
// ocultar tarjetas y ordenar prioridades en una hoja (`HomePreferencias`).
// Ahora se edita como la pantalla de inicio: se mueven, se quitan y se añaden
// tarjetas, pequeñas (media fila) o anchas (fila entera), y una «pila
// inteligente» enseña sola lo más relevante que no esté ya colocado a mano.
//
// Todo lo que decide qué se pinta y dónde vive aquí, sin SwiftUI, para
// probarlo con un puñado de datos. La vista solo pinta lo que sale de aquí.

import Foundation

nonisolated struct HomeDisposicion: Sendable, Equatable {

    // MARK: - Piezas

    enum Tamano: String, Sendable, Codable, CaseIterable {
        /// Media fila, como los huecos B y C de siempre.
        case pequena
        /// La fila entera, como los huecos A y E.
        case ancha
    }

    enum Tipo: Sendable, Hashable {
        /// Una clase de `HomeResumen.Contenido` colocada a mano.
        case clase(String)
        /// La pila inteligente: enseña la clase más relevante que le quepa.
        case pila
        /// Los tres últimos gastos del mes.
        case ultimos
    }

    struct Elemento: Sendable, Hashable, Identifiable {
        /// Estable: sobrevive a mover la tarjeta y a guardarla en la cuenta.
        let id: String
        var tipo: Tipo
        var tamano: Tamano
        /// Solo en las pilas que vienen de la Home de siempre: el hueco que
        /// reproducen. Con él, la pila elige entre los candidatos de ese hueco y
        /// con su mismo desempate, y quien nunca edite ve exactamente lo de
        /// antes. Las pilas que añade el usuario no lo llevan y eligen entre
        /// todo lo que cabe en su tamaño. Al cambiarla de tamaño se pierde: la
        /// cola de un hueco ancho no sirve para una pila pequeña.
        var hueco: HomeResumen.Slot?

        init(id: String = UUID().uuidString, tipo: Tipo, tamano: Tamano, hueco: HomeResumen.Slot? = nil) {
            self.id = id
            self.tipo = tipo
            self.tamano = tamano
            self.hueco = hueco
        }

        var esPila: Bool { tipo == .pila }

        /// La clase colocada a mano, si lo es.
        var clase: String? {
            if case .clase(let c) = tipo { return c }
            return nil
        }
    }

    /// De arriba abajo; las pequeñas se emparejan de dos en dos (ver `filas`).
    var elementos: [Elemento]
    /// Lo que la pila no debe enseñar. Es el `ocultas` de `HomePreferencias`:
    /// una clase oculta que se coloque a mano sí sale.
    var ocultas: Set<String>
    /// El orden que el usuario dio en la hoja de antes. Solo cuenta dentro de
    /// las pilas y como hasta ahora: lo que va antes gana (`HomePreferencias.bonus`).
    var prioridad: [String]
    /// Cuándo la cambió el usuario por última vez. Entre la copia del iPhone y
    /// la de la cuenta gana la más reciente (`masReciente`).
    var actualizada: Date

    init(elementos: [Elemento], ocultas: Set<String> = [], prioridad: [String] = [], actualizada: Date = HomeDisposicion.nunca) {
        self.elementos = elementos
        self.ocultas = ocultas
        self.prioridad = prioridad
        self.actualizada = actualizada
    }

    /// La marca de lo que nunca se ha editado: pierde contra cualquier copia
    /// editada y no se sube a la cuenta. La época de Unix y no `distantPast`,
    /// que queda justo en el borde de lo que admite un `Timestamp` de Firestore.
    static let nunca = Date(timeIntervalSince1970: 0)

    // MARK: - Por defecto y migración

    /// La Home de siempre: hueco A, B y C en una fila, los últimos gastos y el E.
    static let porDefecto = HomeDisposicion(elementos: [
        Elemento(id: "pila-a", tipo: .pila, tamano: .ancha, hueco: .a),
        Elemento(id: "pila-b", tipo: .pila, tamano: .pequena, hueco: .b),
        Elemento(id: "pila-c", tipo: .pila, tamano: .pequena, hueco: .c),
        Elemento(id: "ultimos", tipo: .ultimos, tamano: .ancha),
        Elemento(id: "pila-e", tipo: .pila, tamano: .ancha, hueco: .e),
    ])

    /// Quien ya tenía la app: la Home de siempre con lo que ocultó y ordenó.
    /// Con la marca de «nunca editada»: si en la cuenta hay otra, gana esa.
    static func migrada(desde preferencias: HomePreferencias) -> HomeDisposicion {
        var d = porDefecto
        d.ocultas = preferencias.ocultas
        d.prioridad = preferencias.prioridad
        return d
    }

    // MARK: - Catálogo

    /// Cada clase que se puede poner en la Home: nombre, para qué sirve y qué
    /// tamaños admite, el primero el suyo.
    struct Ficha: Sendable, Equatable, Identifiable {
        let id: String
        let nombre: String
        let descripcion: String
        let tamanos: [Tamano]
    }

    /// Los tamaños salen de las colas de los huecos de siempre (`Slot.candidatos`):
    /// lo que iba en A o E se pinta a lo ancho, lo que iba en B o C cabe en media
    /// fila, y lo que estaba en los dos admite los dos. Lo comprueba
    /// `HomeDisposicionTests`, y se ve en las capturas de `HomeEditableCapturasTests`:
    /// las listas con importe a la derecha (límites, reparto, sitios), las barras
    /// por semana y el tope sugerido se parten o se estiran en media fila, y una
    /// cifra sola a lo ancho es una tarjeta medio vacía. La excepción es «Frente
    /// al mes pasado», que solo iba en huecos anchos pero en media fila se lee
    /// igual de bien: admite los dos.
    /// El orden es el de la galería.
    static let catalogo: [Ficha] = [
        Ficha(id: "limites", nombre: "Límites", descripcion: "Cómo van tus topes por categoría.", tamanos: [.ancha]),
        Ficha(id: "ahorro", nombre: "Ahorro previsto", descripcion: "Lo que te quedará si el mes sigue así.", tamanos: [.pequena]),
        Ficha(id: "cargos", nombre: "Próximos cargos", descripcion: "Recurrentes que aún no han pasado.", tamanos: [.pequena]),
        Ficha(id: "fueraDeNormal", nombre: "Fuera de lo normal", descripcion: "Una categoría muy por encima de tu costumbre.", tamanos: [.ancha, .pequena]),
        Ficha(id: "teDeben", nombre: "Te deben", descripcion: "Gastos compartidos pendientes de devolver.", tamanos: [.pequena]),
        Ficha(id: "hucha", nombre: "Hucha", descripcion: "Tu hucha más avanzada.", tamanos: [.ancha, .pequena]),
        Ficha(id: "reparto", nombre: "Dónde se te va", descripcion: "Las tres categorías que más pesan.", tamanos: [.ancha]),
        Ficha(id: "sitios", nombre: "Tus sitios", descripcion: "Los comercios a los que más vuelves.", tamanos: [.ancha]),
        Ficha(id: "comparativa", nombre: "Frente al mes pasado", descripcion: "El total a estas alturas, mes contra mes.", tamanos: [.ancha, .pequena]),
        Ficha(id: "subeFuerte", nombre: "Sube fuerte", descripcion: "La categoría que más crece frente al mes pasado.", tamanos: [.pequena, .ancha]),
        Ficha(id: "semana", nombre: "Esta semana", descripcion: "Frente a la semana pasada, hasta el mismo día.", tamanos: [.pequena]),
        Ficha(id: "semanaASemana", nombre: "Semana a semana", descripcion: "Lo gastado en cada semana del mes.", tamanos: [.ancha]),
        Ficha(id: "diaCaro", nombre: "Día más caro", descripcion: "El día que más gastaste este mes.", tamanos: [.pequena]),
        Ficha(id: "diaSemana", nombre: "Tu día caro", descripcion: "El día de la semana en que más gastas.", tamanos: [.pequena]),
        Ficha(id: "hormiga", nombre: "Gastos hormiga", descripcion: "Cuánto suman los gastos pequeños.", tamanos: [.pequena]),
        Ficha(id: "ranking", nombre: "Entre tus meses", descripcion: "Dónde cae este mes entre los anteriores.", tamanos: [.pequena]),
        Ficha(id: "racha", nombre: "Racha", descripcion: "Días seguidos apuntando.", tamanos: [.pequena]),
        Ficha(id: "limiteSugerido", nombre: "Un tope sugerido", descripcion: "Una categoría grande sin límite.", tamanos: [.ancha]),
    ]

    private static let fichas: [String: Ficha] = Dictionary(uniqueKeysWithValues: catalogo.map { ($0.id, $0) })

    static func ficha(_ clase: String) -> Ficha? { fichas[clase] }

    /// Lo que admite cada tipo. Vacío para una clase que esta versión no
    /// conoce (la puso una versión más nueva en otro dispositivo): se conserva
    /// tal cual pero no se pinta.
    static func tamanos(de tipo: Tipo) -> [Tamano] {
        switch tipo {
        case .clase(let c): ficha(c)?.tamanos ?? []
        case .pila: [.ancha, .pequena]
        // Tres filas con nombre, fecha, categoría e importe: en media fila no caben.
        case .ultimos: [.ancha]
        }
    }

    static func nombre(de tipo: Tipo) -> String {
        switch tipo {
        case .clase(let c): ficha(c)?.nombre ?? c
        case .pila: "Pila inteligente"
        case .ultimos: "Últimos gastos"
        }
    }

    /// Entre qué elige una pila que no viene de un hueco, y a igualdad de
    /// relevancia gana lo que va antes: las colas de los huecos de su tamaño,
    /// una detrás de otra, como se resolvían, y después lo demás que quepa en
    /// ese tamaño (hoy, «Frente al mes pasado» en las pequeñas).
    static func candidatosDePila(_ tamano: Tamano) -> [String] {
        let colas: [HomeResumen.Slot] = tamano == .ancha ? [.a, .e] : [.b, .c]
        let resto = catalogo.filter { $0.tamanos.contains(tamano) }.map(\.id)
        var vistos = Set<String>()
        return (colas.flatMap(\.candidatos) + resto).filter { vistos.insert($0).inserted }
    }

    // MARK: - Qué enseña cada una

    /// Una tarjeta ya resuelta: lo que es y lo que enseña este mes.
    struct Tarjeta: Sendable, Equatable, Identifiable {
        let elemento: Elemento
        /// La clase que pinta: la suya, o la que eligió la pila. `nil` en los
        /// últimos gastos y en una pila que no tiene nada que enseñar.
        let clase: String?
        /// Si este mes tiene algo que enseñar. Fuera de edición, la que no
        /// tiene no se pinta (ningún cuadro vacío, #65); en edición sale
        /// atenuada para poder moverla o quitarla.
        let conDatos: Bool

        var id: String { elemento.id }
        var tamano: Tamano { elemento.tamano }
        var esPila: Bool { elemento.esPila }
    }

    /// Todas las tarjetas, en orden, con lo que enseña cada una.
    ///
    /// - Parameters:
    ///   - relevancias: las de `HomeResumen`: una clase con datos este mes y
    ///     cuánto importa. Una clase que no está no tiene datos.
    ///   - hayUltimos: si el mes tiene algún gasto que enseñar en «Últimos».
    func tarjetas(relevancias: [String: Double], hayUltimos: Bool) -> [Tarjeta] {
        let pilas = contenidoDePilas(relevancias: relevancias)
        return elementos.compactMap { e in
            switch e.tipo {
            case .clase(let c):
                // Una clase que esta versión no sabe pintar no ocupa sitio.
                guard Self.ficha(c) != nil else { return nil }
                return Tarjeta(elemento: e, clase: c, conDatos: relevancias[c] != nil)
            case .pila:
                let clase = pilas[e.id]
                return Tarjeta(elemento: e, clase: clase, conDatos: clase != nil)
            case .ultimos:
                return Tarjeta(elemento: e, clase: nil, conDatos: hayUltimos)
            }
        }
    }

    /// Lo que enseña cada pila, por id de elemento. De arriba abajo, cada una
    /// coge lo más relevante de lo que le cabe que (a) quepa en su tamaño,
    /// (b) no esté colocado a mano en la Home, (c) no lo enseñe ya una pila
    /// anterior y (d) no esté en `ocultas`. Una pila sin nada no sale.
    func contenidoDePilas(relevancias: [String: Double]) -> [String: String] {
        var excluidas = ocultas.union(elementos.compactMap(\.clase))
        let bonus = HomePreferencias(prioridad: prioridad).bonus
        var resultado: [String: String] = [:]
        for e in elementos where e.esPila {
            let candidatos = e.hueco.map(\.candidatos) ?? Self.candidatosDePila(e.tamano)
            guard let clase = HomeResumen.elegir(entre: candidatos, relevancias: relevancias,
                                                 excluidas: excluidas, bonus: bonus) else { continue }
            resultado[e.id] = clase
            excluidas.insert(clase)
        }
        return resultado
    }

    // MARK: - Filas

    /// Cómo se reparten en filas: las pequeñas de dos en dos y las anchas
    /// solas. Una pequeña suelta antes de una ancha se queda en su fila, con la
    /// otra media vacía: la ancha no sube a rellenarla, igual que en la
    /// pantalla de inicio. Genérico para que lo usen las tarjetas resueltas y
    /// la rejilla de la vista.
    static func filas<T>(_ items: [T], tamano: (T) -> Tamano) -> [[T]] {
        var filas: [[T]] = []
        var suelta: T?
        for item in items {
            switch tamano(item) {
            case .pequena:
                if let anterior = suelta {
                    filas.append([anterior, item])
                    suelta = nil
                } else {
                    suelta = item
                }
            case .ancha:
                if let anterior = suelta {
                    filas.append([anterior])
                    suelta = nil
                }
                filas.append([item])
            }
        }
        if let suelta { filas.append([suelta]) }
        return filas
    }

    // MARK: - Editar

    func contiene(_ tipo: Tipo) -> Bool { elementos.contains { $0.tipo == tipo } }

    /// Si se puede añadir: las clases y los últimos gastos, una vez cada uno;
    /// pilas, las que se quiera.
    func admite(_ tipo: Tipo) -> Bool {
        switch tipo {
        case .pila: true
        case .clase(let c): Self.ficha(c) != nil && !contiene(tipo)
        case .ultimos: !contiene(tipo)
        }
    }

    /// Añade arriba del todo, que es donde se ve al volver de la galería. Con un
    /// tamaño que el tipo no admite, el suyo. Devuelve el id nuevo, o `nil` si
    /// ya estaba.
    @discardableResult
    mutating func anadir(_ tipo: Tipo, tamano: Tamano? = nil, id: String = UUID().uuidString) -> String? {
        guard admite(tipo) else { return nil }
        let admitidos = Self.tamanos(de: tipo)
        let elegido = tamano.flatMap { admitidos.contains($0) ? $0 : nil } ?? admitidos.first ?? .ancha
        elementos.insert(Elemento(id: id, tipo: tipo, tamano: elegido), at: 0)
        return id
    }

    @discardableResult
    mutating func quitar(_ id: String) -> Bool {
        guard let i = elementos.firstIndex(where: { $0.id == id }) else { return false }
        elementos.remove(at: i)
        return true
    }

    /// Solo a un tamaño que el tipo admita.
    @discardableResult
    mutating func cambiarTamano(_ id: String, a tamano: Tamano) -> Bool {
        guard let i = elementos.firstIndex(where: { $0.id == id }),
              elementos[i].tamano != tamano,
              Self.tamanos(de: elementos[i].tipo).contains(tamano) else { return false }
        elementos[i].tamano = tamano
        elementos[i].hueco = nil
        return true
    }

    /// Pone los elementos en el orden de `ids`. Lo que no venga en la lista
    /// (lo que llegó de la cuenta mientras se arrastraba) se queda al final, en
    /// su orden.
    @discardableResult
    mutating func ordenar(_ ids: [String]) -> Bool {
        let posicion = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let nuevo = elementos.enumerated().sorted { a, b in
            (posicion[a.element.id] ?? ids.count + a.offset, a.offset) < (posicion[b.element.id] ?? ids.count + b.offset, b.offset)
        }.map(\.element)
        guard nuevo != elementos else { return false }
        elementos = nuevo
        return true
    }

    /// Un puesto antes (−1) o después (+1). Para VoiceOver, que no arrastra.
    @discardableResult
    mutating func mover(_ id: String, puestos: Int) -> Bool {
        guard let i = elementos.firstIndex(where: { $0.id == id }) else { return false }
        let destino = min(max(i + puestos, 0), elementos.count - 1)
        guard destino != i else { return false }
        elementos.insert(elementos.remove(at: i), at: destino)
        return true
    }

    @discardableResult
    mutating func noEnsenarEnPila(_ clase: String) -> Bool { ocultas.insert(clase).inserted }

    @discardableResult
    mutating func devolverAPila(_ clase: String) -> Bool { ocultas.remove(clase) != nil }

    /// Si es la Home de siempre, sin nada oculto ni ordenado.
    var esLaDeSiempre: Bool {
        elementos == Self.porDefecto.elementos && ocultas.isEmpty && prioridad.isEmpty
    }

    /// La Home de siempre, como el «Volver a lo de siempre» de la hoja de antes:
    /// las tarjetas de siempre y nada oculto ni ordenado.
    @discardableResult
    mutating func restablecer() -> Bool {
        guard !esLaDeSiempre else { return false }
        elementos = Self.porDefecto.elementos
        ocultas = []
        prioridad = []
        return true
    }

    /// Sin repetidos ni tamaños imposibles. Lo que llega de la cuenta o de otra
    /// versión pasa por aquí antes de pintarse.
    func normalizada() -> HomeDisposicion {
        var ids = Set<String>(), clases = Set<String>()
        var hayUltimos = false
        var limpios: [Elemento] = []
        for var e in elementos {
            guard ids.insert(e.id).inserted else { continue }
            switch e.tipo {
            case .clase(let c): guard clases.insert(c).inserted else { continue }
            case .ultimos:
                guard !hayUltimos else { continue }
                hayUltimos = true
            case .pila: break
            }
            let admitidos = Self.tamanos(de: e.tipo)
            if let primero = admitidos.first, !admitidos.contains(e.tamano) { e.tamano = primero }
            if !e.esPila || e.hueco?.tamano != e.tamano { e.hueco = nil }
            limpios.append(e)
        }
        var d = self
        d.elementos = limpios
        return d
    }

    // MARK: - iPhone y cuenta

    /// Entre la copia del iPhone y la de la cuenta, la más reciente. `subirLocal`
    /// cuando la del iPhone tiene cambios que la cuenta no tiene (se editó sin
    /// cobertura, o la subida no llegó). La que nunca se editó no se sube.
    static func masReciente(local: HomeDisposicion, remota: HomeDisposicion?) -> (ganadora: HomeDisposicion, subirLocal: Bool) {
        guard let remota else { return (local, local.actualizada > nunca) }
        if remota.actualizada > local.actualizada { return (remota, false) }
        return (local, local.actualizada > remota.actualizada)
    }

    static let clave = "home.disposicion"

    /// La copia del iPhone. Sin ella, la de antes de la 2.4 migrada: la Home de
    /// siempre con lo que se ocultó y ordenó en la hoja.
    static func cargar(de defaults: UserDefaults = .standard) -> HomeDisposicion {
        if let data = defaults.data(forKey: clave),
           let guardada = try? JSONDecoder().decode(HomeDisposicion.self, from: data) {
            return guardada
        }
        return migrada(desde: HomePreferencias.cargar(de: defaults))
    }

    func guardar(en defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.clave) }
    }
}

nonisolated extension HomeResumen.Slot {
    /// A y E son anchos; B y C, medias tarjetas.
    var tamano: HomeDisposicion.Tamano {
        switch self {
        case .a, .e: .ancha
        case .b, .c: .pequena
        }
    }
}

// MARK: - Codable

// A mano, y no el sintetizado, por dos motivos: el formato es el que queda en
// Firestore (`users/{uid}.homeDisposicion`) y tiene que leerse bien en la
// consola —`{"tipo": "clase", "clase": "limites"}` y no `{"clase": {"_0": …}}`—,
// y leer es tolerante: un elemento que no se entiende (otra versión, un dato
// roto) se salta y el resto se conserva, en vez de perder la Home entera.

nonisolated extension HomeDisposicion: Codable {
    private enum Claves: String, CodingKey {
        case elementos, ocultas, prioridad, actualizada
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Claves.self)
        // Sin lista no es una disposición: quien llama se queda con la suya.
        var lista = try c.nestedUnkeyedContainer(forKey: .elementos)
        var elementos: [Elemento] = []
        while !lista.isAtEnd {
            if let e = try? lista.decode(Elemento.self) {
                elementos.append(e)
            } else {
                _ = try? lista.decode(Descartado.self)
            }
        }
        let ocultas = (try? c.decodeIfPresent([String].self, forKey: .ocultas)) ?? []
        let prioridad = (try? c.decodeIfPresent([String].self, forKey: .prioridad)) ?? []
        let actualizada = (try? c.decodeIfPresent(Date.self, forKey: .actualizada)) ?? Self.nunca
        self = HomeDisposicion(elementos: elementos, ocultas: Set(ocultas), prioridad: prioridad,
                               actualizada: actualizada).normalizada()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Claves.self)
        try c.encode(elementos, forKey: .elementos)
        // Ordenadas: el mismo contenido da siempre el mismo documento.
        try c.encode(ocultas.sorted(), forKey: .ocultas)
        try c.encode(prioridad, forKey: .prioridad)
        try c.encode(actualizada, forKey: .actualizada)
    }
}

nonisolated extension HomeDisposicion.Elemento: Codable {
    private enum Claves: String, CodingKey {
        case id, tipo, clase, tamano, hueco
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Claves.self)
        id = try c.decode(String.self, forKey: .id)
        switch try c.decode(String.self, forKey: .tipo) {
        case "clase": tipo = .clase(try c.decode(String.self, forKey: .clase))
        case "pila": tipo = .pila
        case "ultimos": tipo = .ultimos
        default:
            throw DecodingError.dataCorruptedError(forKey: .tipo, in: c, debugDescription: "Tipo de tarjeta desconocido")
        }
        tamano = try c.decode(HomeDisposicion.Tamano.self, forKey: .tamano)
        hueco = (try? c.decodeIfPresent(String.self, forKey: .hueco)).flatMap { HomeResumen.Slot(rawValue: $0) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Claves.self)
        try c.encode(id, forKey: .id)
        switch tipo {
        case .clase(let clase):
            try c.encode("clase", forKey: .tipo)
            try c.encode(clase, forKey: .clase)
        case .pila: try c.encode("pila", forKey: .tipo)
        case .ultimos: try c.encode("ultimos", forKey: .tipo)
        }
        try c.encode(tamano, forKey: .tamano)
        try c.encodeIfPresent(hueco?.rawValue, forKey: .hueco)
    }
}

/// Para saltar un elemento que no se entiende sin que la lista se atasque en él.
private nonisolated struct Descartado: Decodable {
    init(from decoder: Decoder) throws {}
}
