// EnlaceAnadirGasto.swift
// Interpretación del enlace profundo `clarity://add-expense`.
//
// Vivía dentro del cierre de `.onOpenURL` de `MainTabView`, donde no había
// forma de probarla sin levantar la vista entera. Aquí es una función pura:
// entra una URL, sale qué hay que hacer. Todo lo que tiene efectos (cerrar
// hojas, esperar a las categorías, migas, hablar con el coordinador de voz)
// se queda en `MainTabView`.
//
// Quién abre la app con este enlace:
//  - el Atajo de Apple Pay → `?merchant=…&amount=…`
//  - Siri / Atajos (`AddExpenseIntent`) → `?input=<frase>`
//  - el widget → sin parámetros

import Foundation

nonisolated enum EnlaceAnadirGasto: Equatable, Sendable {
    /// Pago con Apple Pay: comercio e importe ya conocidos.
    case applePay(comercio: String, importe: Double)
    /// Frase dictada a Siri o escrita en un Atajo; la resuelve el parser de voz.
    case fraseDictada(String)
    /// Enlace válido sin nada aprovechable: se abre el formulario vacío.
    case abrirFormulario
    /// No es un enlace de añadir gasto: no se hace nada.
    case ignorar

    /// Mismas reglas, en el mismo orden, que tenía el cierre de `onOpenURL`:
    /// 1. esquema `clarity` y host `add-expense`, o se ignora;
    /// 2. `merchant` no vacío + `amount` que `Double` sepa leer → Apple Pay;
    /// 3. si no, `input` no vacío → frase dictada;
    /// 4. si no, abrir el formulario.
    ///
    /// El importe se lee con `Double(String)`, que solo entiende el punto como
    /// separador: «12,50» no es Apple Pay y cae al siguiente caso. Tampoco se
    /// comprueba aquí que sea mayor que cero; eso lo valida quien guarda
    /// (`AddExpenseUseCase`). Es el comportamiento que había y no se cambia.
    static func interpretar(_ url: URL) -> EnlaceAnadirGasto {
        guard url.scheme == "clarity", url.host == "add-expense",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        else { return .ignorar }

        let queryItems = components.queryItems ?? []
        let merchant = queryItems.first(where: { $0.name == "merchant" })?.value
        let amountStr = queryItems.first(where: { $0.name == "amount" })?.value
        let inputPhrase = queryItems.first(where: { $0.name == "input" })?.value

        if let merchant, !merchant.isEmpty,
           let amountStr, let amount = Double(amountStr) {
            return .applePay(comercio: merchant, importe: amount)
        } else if let phrase = inputPhrase, !phrase.isEmpty {
            return .fraseDictada(phrase)
        } else {
            return .abrirFormulario
        }
    }
}
