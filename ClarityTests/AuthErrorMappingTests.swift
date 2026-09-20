// AuthErrorMappingTests.swift
// Lo que ve el usuario cuando falla el inicio de sesión. Firebase devuelve sus
// errores en inglés y con jerga («The supplied auth credential is malformed…»);
// `AuthViewModel.mapAuthError` los traduce. Era `private` y no tenía tests: un
// `case` borrado por descuido habría acabado en el mensaje genérico sin que
// nadie se enterase.
//
// No se crea ningún `AuthViewModel` ni se toca Firebase Auth: la función es
// estática y solo mira el código del error.

import Testing
import Foundation
import FirebaseAuth
@testable import Clarity

@Suite("Mensajes de error de autenticación")
@MainActor
struct AuthErrorMappingTests {

    private static let generico = "No se ha podido completar la operación. Inténtalo de nuevo."

    /// Un error como los que lanza el SDK: `NSError` con su dominio y el código.
    private func errorDeFirebase(_ codigo: Int) -> NSError {
        NSError(domain: AuthErrorDomain, code: codigo, userInfo: [
            NSLocalizedDescriptionKey: "The supplied auth credential is malformed or has expired."
        ])
    }

    @Test("cada código que se maneja tiene su mensaje", arguments: [
        (AuthErrorCode.wrongPassword.rawValue, "Email o contraseña incorrectos"),
        (AuthErrorCode.invalidCredential.rawValue, "Email o contraseña incorrectos"),
        (AuthErrorCode.invalidEmail.rawValue, "Email no válido"),
        (AuthErrorCode.userNotFound.rawValue, "Esta cuenta no existe"),
        (AuthErrorCode.userDisabled.rawValue, "Esta cuenta está deshabilitada"),
        (AuthErrorCode.emailAlreadyInUse.rawValue, "Este email ya está registrado"),
        (AuthErrorCode.weakPassword.rawValue, "La contraseña debe tener al menos 6 caracteres"),
        (AuthErrorCode.networkError.rawValue, "Sin conexión. Comprueba tu internet."),
        (AuthErrorCode.tooManyRequests.rawValue, "Demasiados intentos. Espera unos minutos."),
        (AuthErrorCode.requiresRecentLogin.rawValue, "Por seguridad, vuelve a iniciar sesión"),
        (AuthErrorCode.operationNotAllowed.rawValue, "Este método de inicio de sesión no está disponible"),
        (AuthErrorCode.accountExistsWithDifferentCredential.rawValue,
         "Ya existe una cuenta con este email usando otro método (prueba con Google/Apple)"),
        (AuthErrorCode.credentialAlreadyInUse.rawValue, "Esta credencial ya está vinculada a otra cuenta"),
        (AuthErrorCode.userTokenExpired.rawValue, "Sesión caducada. Vuelve a iniciar sesión."),
        (AuthErrorCode.webContextCancelled.rawValue, "Inicio de sesión cancelado"),
        (AuthErrorCode.webContextAlreadyPresented.rawValue, "Inicio de sesión cancelado"),
    ])
    func codigoConocido(_ codigo: Int, _ mensaje: String) {
        #expect(AuthViewModel.mapAuthError(errorDeFirebase(codigo)) == mensaje)
    }

    // Lo que NO debe pasar nunca: que al usuario le llegue el texto en inglés
    // del SDK.
    @Test("ningún código conocido deja pasar el texto de Firebase ni cae en el genérico", arguments: [
        AuthErrorCode.wrongPassword, .invalidCredential, .invalidEmail, .userNotFound,
        .userDisabled, .emailAlreadyInUse, .weakPassword, .networkError, .tooManyRequests,
        .requiresRecentLogin, .operationNotAllowed, .accountExistsWithDifferentCredential,
        .credentialAlreadyInUse, .userTokenExpired, .webContextCancelled, .webContextAlreadyPresented,
    ].map(\.rawValue))
    func nuncaElTextoDelSDK(_ codigo: Int) {
        let error = errorDeFirebase(codigo)
        let mensaje = AuthViewModel.mapAuthError(error)
        #expect(!mensaje.isEmpty)
        #expect(mensaje != error.localizedDescription)
        #expect(mensaje != Self.generico)
    }

    @Test("un código de Firebase que no se maneja: mensaje genérico en español")
    func codigoDesconocido() {
        #expect(AuthViewModel.mapAuthError(errorDeFirebase(AuthErrorCode.internalError.rawValue)) == Self.generico)
        #expect(AuthViewModel.mapAuthError(errorDeFirebase(99_999)) == Self.generico)
    }

    @Test("errores que no son de Firebase: también el genérico, nunca su descripción")
    func errorAjeno() {
        struct ErrorCualquiera: Error {}
        let deRed = URLError(.timedOut)

        #expect(AuthViewModel.mapAuthError(ErrorCualquiera()) == Self.generico)
        #expect(AuthViewModel.mapAuthError(deRed) == Self.generico)
        #expect(AuthViewModel.mapAuthError(deRed) != deRed.localizedDescription)
    }
}
