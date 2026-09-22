// PasoOnboarding.swift
// Las páginas del onboarding, en el orden en que se enseñan (#57).
//
// El `rawValue` es la posición (el `tag` de cada página en `OnboardingView`) y
// `nombre` es lo que se mira en Analytics: si se reordenan las páginas, se
// reordenan los casos y los nombres se quedan como están, para que el embudo
// de antes y el de después sigan siendo comparables.

import Foundation

enum PasoOnboarding: Int, CaseIterable, Sendable {
    case bienvenida
    case voz
    case tutorial
    case primerGasto
    case listo

    /// Nombre estable del paso. No cambiarlo: rompe la serie en Analytics.
    var nombre: String {
        switch self {
        case .bienvenida: return "bienvenida"
        case .voz: return "voz"
        case .tutorial: return "tutorial"
        case .primerGasto: return "primer_gasto"
        case .listo: return "listo"
        }
    }

    /// El nombre de pantalla que ya se mandaba antes de este evento.
    var nombrePantalla: String { "onboarding_\(nombre)" }

    var evento: AnalyticsEvent {
        .onboardingStep(index: rawValue, name: nombre)
    }
}
