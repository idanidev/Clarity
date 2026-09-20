// EnlaceAnadirGastoTests.swift
// El enlace `clarity://add-expense` es la puerta de Apple Pay, de Siri y del
// widget. Su lectura estaba enterrada en el `.onOpenURL` de `MainTabView` y no
// tenía ni un test. Estos fijan las reglas TAL COMO ESTABAN al extraerlas: si
// alguno molesta, es una decisión de producto, no un despiste del test.

import Testing
import Foundation
@testable import Clarity

@Suite("Enlace clarity://add-expense")
@MainActor
struct EnlaceAnadirGastoTests {

    private func interpretar(_ texto: String) throws -> EnlaceAnadirGasto {
        let url = try #require(URL(string: texto), "URL de prueba mal escrita: \(texto)")
        return EnlaceAnadirGasto.interpretar(url)
    }

    // MARK: - Enlaces que no son para esto

    @Test("otro host, otro esquema o sin host: se ignora", arguments: [
        "clarity://settings",
        "clarity://add-expenses?merchant=Bar&amount=3",
        "clarity://addexpense",
        "https://add-expense?merchant=Bar&amount=3",
        "otraapp://add-expense?input=cafe",
        "clarity:add-expense",
    ])
    func ignoraLoQueNoEsAnadirGasto(_ texto: String) throws {
        #expect(try interpretar(texto) == .ignorar)
    }

    // MARK: - Apple Pay

    @Test("comercio e importe: Apple Pay")
    func applePay() throws {
        #expect(try interpretar("clarity://add-expense?merchant=Mercadona&amount=23.45")
                == .applePay(comercio: "Mercadona", importe: 23.45))
    }

    @Test("el comercio llega descodificado, con espacios y acentos")
    func applePayComercioCodificado() throws {
        #expect(try interpretar("clarity://add-expense?merchant=Caf%C3%A9%20El%20Ni%C3%B1o&amount=4")
                == .applePay(comercio: "Café El Niño", importe: 4))
    }

    @Test("el orden de los parámetros da igual")
    func applePayOrdenIndiferente() throws {
        #expect(try interpretar("clarity://add-expense?amount=9.9&merchant=Bar")
                == .applePay(comercio: "Bar", importe: 9.9))
    }

    @Test("importe que no es un número: no es Apple Pay, se abre el formulario", arguments: [
        "clarity://add-expense?merchant=Bar&amount=abc",
        "clarity://add-expense?merchant=Bar&amount=12%E2%82%AC",  // «12€»
        "clarity://add-expense?merchant=Bar&amount=",
        "clarity://add-expense?merchant=Bar",
    ])
    func importeNoNumerico(_ texto: String) throws {
        #expect(try interpretar(texto) == .abrirFormulario)
    }

    // `Double(String)` solo entiende el punto. Un Atajo configurado en un
    // iPhone en español puede mandar «12,50»: hoy eso NO entra como Apple Pay.
    @Test("importe con coma: no se lee, se abre el formulario")
    func importeConComa() throws {
        #expect(try interpretar("clarity://add-expense?merchant=Bar&amount=12,50") == .abrirFormulario)
    }

    // Aquí no se valida el signo: llega a la hoja de confirmación y es
    // `AddExpenseUseCase` quien se niega a guardarlo («El monto debe ser mayor
    // a 0»). Queda fijado para que cambiarlo sea a propósito.
    @Test("importe cero o negativo: pasa como Apple Pay, lo rechaza quien guarda",
          arguments: [("0", 0.0), ("-5", -5.0), ("-0.01", -0.01)])
    func importeNoPositivo(_ texto: String, _ esperado: Double) throws {
        #expect(try interpretar("clarity://add-expense?merchant=Bar&amount=\(texto)")
                == .applePay(comercio: "Bar", importe: esperado))
    }

    @Test("comercio vacío: no es Apple Pay aunque haya importe")
    func comercioVacio() throws {
        #expect(try interpretar("clarity://add-expense?merchant=&amount=10") == .abrirFormulario)
    }

    // MARK: - Frase dictada (Siri / Atajos)

    @Test("frase con espacios y acentos codificados")
    func fraseCodificada() throws {
        #expect(try interpretar("clarity://add-expense?input=13%20euros%20caf%C3%A9%20con%20%C3%B1oquis")
                == .fraseDictada("13 euros café con ñoquis"))
    }

    // Lo mismo que hace `AddExpenseIntent`: ida y vuelta con la codificación
    // que usa de verdad.
    @Test("ida y vuelta con la codificación del intent de Siri")
    func fraseIdaYVuelta() throws {
        let frase = "veintitrés con cincuenta en la peluquería"
        let codificada = try #require(frase.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        #expect(try interpretar("clarity://add-expense?input=\(codificada)") == .fraseDictada(frase))
    }

    @Test("Apple Pay incompleto pero con frase: gana la frase")
    func fraseCuandoApplePayNoCuadra() throws {
        #expect(try interpretar("clarity://add-expense?merchant=Bar&amount=doce&input=doce%20euros%20bar")
                == .fraseDictada("doce euros bar"))
    }

    @Test("Apple Pay completo y frase a la vez: gana Apple Pay")
    func applePayAntesQueFrase() throws {
        #expect(try interpretar("clarity://add-expense?merchant=Bar&amount=12&input=otra%20cosa")
                == .applePay(comercio: "Bar", importe: 12))
    }

    // MARK: - Sin nada aprovechable

    @Test("sin parámetros, o con todos vacíos: abrir el formulario", arguments: [
        "clarity://add-expense",
        "clarity://add-expense?",
        "clarity://add-expense?input=",
        "clarity://add-expense?merchant=&amount=&input=",
        "clarity://add-expense?desconocido=1",
    ])
    func abreFormulario(_ texto: String) throws {
        #expect(try interpretar(texto) == .abrirFormulario)
    }
}
