// ModoDemo.swift
// Modo demo para las capturas de la App Store. Solo existe en DEBUG: en
// Release no se compila nada de esta carpeta.
//
// Se activa arrancando con `-modoDemo`:
//
//     xcrun simctl launch <udid> com.idanidev.clarity -modoDemo -demoPantalla graficas
//
// La app entra ya dentro —sin login y con el onboarding hecho— y con los datos
// inventados de `DatosDemo` en repositorios en memoria. Firebase ni se
// configura: no se lee ni se escribe nada en Firestore, en Auth ni en la red,
// y si algún camino llegara a tocarlo la app se pararía en seco en vez de
// hablar con el proyecto de verdad. La caché de SwiftData es solo en memoria y
// Analytics no se arranca.
//
// `-demoPantalla home|graficas|metas|edicion` abre directamente cada pantalla
// (`edicion` es la Home en modo edición), para capturar sin automatizar toques.

#if DEBUG
import Foundation
import SwiftData

enum ModoDemo {
    enum Pantalla: String {
        case home, graficas, metas, edicion
    }

    static let activo = ProcessInfo.processInfo.arguments.contains("-modoDemo")

    /// La pantalla pedida con `-demoPantalla`; la Home si no se pide ninguna.
    static let pantalla: Pantalla = {
        let argumentos = ProcessInfo.processInfo.arguments
        guard let i = argumentos.firstIndex(of: "-demoPantalla"), i + 1 < argumentos.count,
              let pedida = Pantalla(rawValue: argumentos[i + 1])
        else { return .home }
        return pedida
    }()

    /// Los datos de la sesión, calculados una vez al arrancar respecto a hoy.
    static let datos = DatosDemo.generar(hoy: Date())

    /// Lo que hay que dejar listo antes de que se monte nada. Se llama desde el
    /// `AppDelegate`, en lugar de configurar Firebase.
    static func preparar() {
        // Lo que en una instalación nueva saldría encima de las pantallas: la
        // presentación de Metas y la enhorabuena por el mes anterior. En el
        // dominio de registro, que no se guarda en disco.
        let cal = Calendar.current
        let mesAnterior = cal.date(byAdding: .month, value: -1, to: Date()).map {
            String(Formatters.localDayString(from: $0).prefix(7))
        }
        UserDefaults.standard.register(defaults: [
            "metas.onboardingSeen": true,
            "voice.onboardingSeen": true,
            "celebrados.cierreMes": mesAnterior.map { [$0] } ?? [],
        ])

        // La caché local con los gastos de la demo. `SwiftDataService` ya abre
        // en memoria en modo demo: esto no toca el almacén de disco.
        let contexto = SwiftDataService.shared.context
        for gasto in datos.gastos {
            contexto.insert(ExpenseModel(from: gasto))
        }
        try? contexto.save()
    }
}
#endif
