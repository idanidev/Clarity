// ErrorDescriptionsTests.swift
// `AppError` y `RepositoryError` acaban en pantalla vía `localizedDescription`.
// Si a un caso le falta su `errorDescription`, Swift no avisa: enseña «The
// operation couldn’t be completed. (Clarity.AppError error 3.)», en inglés y
// con el nombre del tipo. Estos tests recorren TODOS los casos.
//
// Ninguno de los dos enums es `CaseIterable` (llevan valores asociados), así
// que la lista se escribe a mano; los `switch` sin `default` de abajo dejan de
// compilar cuando alguien añade un caso, y ese es el recordatorio de sumarlo.

import Testing
import Foundation
@testable import Clarity

@Suite("Descripciones de error")
@MainActor
struct ErrorDescriptionsTests {

    // MARK: - Comprobación común

    /// Lo mínimo que se le pide a un mensaje que va a ver el usuario.
    private func comprobar(_ error: any LocalizedError, _ nombre: String) throws {
        let descripcion = try #require(error.errorDescription, "\(nombre): sin errorDescription")
        #expect(!descripcion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(nombre): vacía")

        // Lo que enseña cualquier vista que haga `error.localizedDescription`
        // tiene que ser ese mismo texto, no el de relleno de Foundation.
        let enPantalla = (error as any Error).localizedDescription
        #expect(enPantalla == descripcion, "\(nombre): localizedDescription no usa errorDescription")
        #expect(!enPantalla.contains("The operation"), "\(nombre): descripción por defecto de Swift")
        #expect(!enPantalla.contains("couldn"), "\(nombre): descripción por defecto de Swift")
        #expect(!enPantalla.contains("Clarity."), "\(nombre): se cuela el nombre del tipo")
        #expect(!enPantalla.contains("AppError") && !enPantalla.contains("RepositoryError"),
                "\(nombre): se cuela el nombre del tipo")
    }

    // MARK: - AppError

    private static let motivo = "sin conexión"

    private static let casosAppError: [AppError] = [
        .dataLoadingFailed(motivo),
        .savingFailed(motivo),
        .deletionFailed(motivo),
        .networkError(motivo),
        .unknown(motivo),
        .validation("El importe debe ser mayor que cero"),
        .authenticationRequired,
        .rateLimited,
    ]

    /// Sin `default` a propósito: un caso nuevo rompe la compilación aquí.
    private static func nombre(_ error: AppError) -> String {
        switch error {
        case .dataLoadingFailed: "dataLoadingFailed"
        case .savingFailed: "savingFailed"
        case .deletionFailed: "deletionFailed"
        case .networkError: "networkError"
        case .unknown: "unknown"
        case .validation: "validation"
        case .authenticationRequired: "authenticationRequired"
        case .rateLimited: "rateLimited"
        }
    }

    @Test("AppError: cada caso tiene descripción propia y en español", arguments: casosAppError)
    func appError(_ error: AppError) throws {
        try comprobar(error, "AppError.\(Self.nombre(error))")
    }

    @Test("AppError: la lista de arriba cubre todos los casos, sin repetir")
    func appErrorListaCompleta() {
        #expect(Set(Self.casosAppError.map(Self.nombre)).count == 8)
        #expect(Self.casosAppError.count == 8)
    }

    @Test("AppError: el motivo concreto llega al mensaje", arguments: [
        AppError.dataLoadingFailed(motivo), .savingFailed(motivo), .deletionFailed(motivo),
        .networkError(motivo), .unknown(motivo),
    ])
    func appErrorIncluyeElMotivo(_ error: AppError) throws {
        let descripcion = try #require(error.errorDescription)
        #expect(descripcion.contains(Self.motivo))
        // Y no es SOLO el motivo: lleva delante qué estaba haciendo la app.
        #expect(descripcion.count > Self.motivo.count)
    }

    @Test("AppError.validation enseña el texto tal cual")
    func appErrorValidacion() {
        #expect(AppError.validation("Falta el nombre").errorDescription == "Falta el nombre")
    }

    @Test("AppError: siempre hay sugerencia, y la de red habla de la conexión", arguments: casosAppError)
    func appErrorSugerencia(_ error: AppError) throws {
        let sugerencia = try #require(error.recoverySuggestion)
        #expect(!sugerencia.isEmpty)
        if case .networkError = error {
            #expect(sugerencia.contains("conexión"))
        }
    }

    // MARK: - RepositoryError

    /// Error interno con un texto reconocible, para ver que llega al mensaje.
    private struct FalloInterno: LocalizedError {
        var errorDescription: String? { "el servidor no contesta" }
    }

    // `RepositoryError` no es `Equatable` ni `Sendable` de forma declarada
    // (lleva un `Error` dentro), así que se parametriza por nombre.
    private static let nombresRepositoryError = ["notAuthenticated", "notFound", "permissionDenied", "unknown"]

    private static func repositoryError(_ nombre: String) -> RepositoryError? {
        switch nombre {
        case "notAuthenticated": .notAuthenticated
        case "notFound": .notFound
        case "permissionDenied": .permissionDenied
        case "unknown": .unknown(FalloInterno())
        default: nil
        }
    }

    /// Sin `default` a propósito: un caso nuevo rompe la compilación aquí.
    private static func nombre(_ error: RepositoryError) -> String {
        switch error {
        case .notAuthenticated: "notAuthenticated"
        case .notFound: "notFound"
        case .permissionDenied: "permissionDenied"
        case .unknown: "unknown"
        }
    }

    @Test("RepositoryError: cada caso tiene descripción propia y en español",
          arguments: nombresRepositoryError)
    func repositoryError(_ nombre: String) throws {
        let error = try #require(Self.repositoryError(nombre))
        #expect(Self.nombre(error) == nombre)
        try comprobar(error, "RepositoryError.\(nombre)")
    }

    @Test("RepositoryError.unknown arrastra la descripción del error de dentro")
    func repositoryErrorDesconocido() throws {
        let descripcion = try #require(RepositoryError.unknown(FalloInterno()).errorDescription)
        #expect(descripcion.contains("el servidor no contesta"))
        #expect(descripcion.hasPrefix("Error desconocido"))
    }

    @Test("los mensajes de RepositoryError no se repiten entre casos")
    func repositoryErrorDistintos() {
        let descripciones = Self.nombresRepositoryError
            .compactMap(Self.repositoryError)
            .compactMap(\.errorDescription)
        #expect(descripciones.count == 4)
        #expect(Set(descripciones).count == 4)
    }
}
