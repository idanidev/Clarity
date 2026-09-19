// MigasDeTeclado.swift
// Una miga por cada aviso del teclado, con su alto.
//
// El cuelgue que se persigue ocurre al abrir un formulario que saca el teclado
// nada más aparecer, y ya hubo uno parecido por cómo se medía el área segura con
// el teclado arriba (ver `MainTabView`). Saber si el teclado llegó a salir, con
// qué alto y cuántas veces es media respuesta.

import UIKit

enum MigasDeTeclado {
    /// Se llama una vez, desde el hilo principal. Los observadores duran lo que
    /// la app: no se dan de baja.
    static func arranca() {
        // Fuera del bloque: las constantes de `UIResponder` son del hilo
        // principal y el bloque del observador no está atado a ninguno.
        let claveDelMarco = UIResponder.keyboardFrameEndUserInfoKey
        let avisos: [(Notification.Name, String)] = [
            (UIResponder.keyboardWillShowNotification, "willShow"),
            (UIResponder.keyboardDidShowNotification, "didShow"),
            (UIResponder.keyboardWillHideNotification, "willHide"),
        ]

        for (aviso, nombre) in avisos {
            // `queue: nil`: corre en el hilo que publica el aviso, en el acto. Con
            // una cola de por medio, la miga llegaría tarde o, con el principal
            // colgado, nunca.
            _ = NotificationCenter.default.addObserver(forName: aviso, object: nil, queue: nil) { nota in
                let alto = (nota.userInfo?[claveDelMarco] as? CGRect)?.height ?? 0
                Migas.deja("teclado: \(nombre) alto=\(Int(alto))")
            }
        }
    }
}
