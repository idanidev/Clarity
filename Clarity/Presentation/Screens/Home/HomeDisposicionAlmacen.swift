// HomeDisposicionAlmacen.swift
// Dónde vive la disposición de la Home: en el iPhone, para arrancar al
// instante, y en la cuenta, para verse igual en otro dispositivo.
//
// Aparte de `HomeViewModel` para que los tests le pongan un almacén en memoria:
// corren dentro de la app, en el simulador con la sesión real, y con el de
// verdad escribirían en los UserDefaults del usuario y en su Firestore.

import Foundation

struct HomeDisposicionAlmacen {
    /// La copia del iPhone, o la Home de siempre migrada si no hay.
    var cargarLocal: () -> HomeDisposicion
    var guardarLocal: (HomeDisposicion) -> Void
    /// Si el documento de la cuenta ya se leyó. Mientras no, no se sabe qué
    /// hay allí y no se sube nada: podría pisar una más reciente.
    var documentoCargado: () -> Bool
    /// La de la cuenta, si el documento la trae.
    var remota: () -> HomeDisposicion?
    /// Escribe en la cuenta.
    var subir: (HomeDisposicion) async -> Void

    /// El de la app: UserDefaults y el documento `users/{uid}` a través de
    /// `UserDataManager`, que escribe solo el campo `homeDisposicion`.
    static var app: HomeDisposicionAlmacen {
        HomeDisposicionAlmacen(
            cargarLocal: { HomeDisposicion.cargar(de: .standard) },
            guardarLocal: { $0.guardar(en: .standard) },
            documentoCargado: { UserDataManager.shared.userDocument != nil },
            remota: { UserDataManager.shared.homeDisposicion },
            subir: { await UserDataManager.shared.saveHomeDisposicion($0) }
        )
    }
}
