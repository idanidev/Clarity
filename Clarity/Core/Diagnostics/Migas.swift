// Migas.swift
// Migas de pan: el rastro de lo último que hizo la app antes de un cuelgue.
//
// Hay un cuelgue total al abrir "Añadir gasto" que no se deja reproducir. Cuando
// el vigilante (`VigilanteDeCuelgues`) detecta el bloqueo, estas migas van dentro
// del informe y, de ahí, al pie del siguiente correo de soporte: en qué pantalla
// estaba, qué campo tenía el foco, qué hizo el teclado.
//
// PRIVACIDAD: aquí solo entran nombres de pantalla y de acción escritos a mano
// en el código. Nunca importes, nombres de gasto, categorías del usuario, correos
// ni uid: esto acaba en un correo.

import Foundation
import os

/// Una entrada del rastro.
nonisolated struct Miga: Codable, Equatable, Sendable {
    /// Cuándo pasó. Si se repitió, la última vez.
    var fecha: Date
    var texto: String
    /// Cuántas veces seguidas. Ver `BufferDeMigas.anade`.
    var veces: Int = 1
}

/// Búfer circular: guarda las últimas `tope` migas y tira las más viejas.
///
/// Es un valor sin hilos ni reloj para poder probarlo; el candado lo pone
/// `RegistroDeMigas`.
nonisolated struct BufferDeMigas: Sendable {
    /// Largo máximo de un texto. Acota la memoria y garantiza que las doce migas
    /// del pie del correo caben en su tope (`ResumenDeCuelgue`). Las de verdad
    /// rondan los treinta caracteres.
    static let largoMaximo = 64

    let tope: Int
    private var almacen: [Miga] = []
    /// Dónde cae la siguiente. Con el búfer lleno, ahí está la más vieja.
    private var siguiente = 0
    private var ultimaClave: String?

    init(tope: Int) {
        self.tope = max(1, tope)
        almacen.reserveCapacity(self.tope)
    }

    /// Añade una miga. Si repite la clave de la anterior, no ocupa hueco nuevo:
    /// la anterior se queda con el texto y la hora de esta y suma una vez.
    ///
    /// Sin esto, justo el fallo que se busca —un bucle de layout que cambia la
    /// medida de la barra cien veces por segundo— llenaría el búfer de ruido y
    /// borraría lo que importa: qué se hizo antes de entrar en el bucle.
    ///
    /// - Parameter clave: familia de la miga. Sin ella, solo se agrupan textos
    ///   idénticos.
    mutating func anade(_ texto: String, fecha: Date, agrupando clave: String? = nil) {
        let recortado = String(texto.prefix(Self.largoMaximo))
        let claveEfectiva = clave ?? recortado

        if claveEfectiva == ultimaClave, !almacen.isEmpty {
            let ultima = (siguiente + tope - 1) % tope
            almacen[ultima].fecha = fecha
            almacen[ultima].texto = recortado
            almacen[ultima].veces += 1
            return
        }

        ultimaClave = claveEfectiva
        let miga = Miga(fecha: fecha, texto: recortado)
        if almacen.count < tope {
            almacen.append(miga)
        } else {
            almacen[siguiente] = miga
        }
        siguiente = (siguiente + 1) % tope
    }

    /// De la más vieja a la más reciente.
    var enOrden: [Miga] {
        guard almacen.count == tope else { return almacen }
        return Array(almacen[siguiente...] + almacen[..<siguiente])
    }
}

/// El búfer detrás de un candado.
///
/// Candado y no actor, a propósito: las migas se dejan de forma síncrona desde
/// el hilo principal y las lee el vigilante desde el suyo *mientras el principal
/// está colgado*. Con un actor, leerlas exigiría un `await` que un hilo colgado
/// no va a atender nunca.
nonisolated final class RegistroDeMigas: Sendable {
    private let estado: OSAllocatedUnfairLock<BufferDeMigas>

    init(tope: Int = 40) {
        estado = OSAllocatedUnfairLock(initialState: BufferDeMigas(tope: tope))
    }

    func deja(_ texto: String, agrupando clave: String? = nil, fecha: Date = Date()) {
        estado.withLock { $0.anade(texto, fecha: fecha, agrupando: clave) }
    }

    /// Copia de las migas, de la más vieja a la más reciente.
    func copia() -> [Miga] {
        estado.withLock { $0.enOrden }
    }
}

/// Punto de entrada: `Migas.deja("hoja añadir: aparece")`.
///
/// Cuesta un candado sin contienda y copiar una cadena corta; se puede llamar
/// desde cualquier hilo y desde el cuerpo de cualquier acción de la interfaz.
nonisolated enum Migas {
    static let registro = RegistroDeMigas()

    /// Solo nombres de pantalla y de acción. Ver el aviso de privacidad de arriba.
    static func deja(_ texto: String, agrupando clave: String? = nil) {
        registro.deja(texto, agrupando: clave)
    }

    static func copia() -> [Miga] {
        registro.copia()
    }
}
