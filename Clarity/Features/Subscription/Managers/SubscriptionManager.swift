// SubscriptionManager.swift
// Clarity Pro con StoreKit 2 (#40 §3).
//
// El paywall llega apagado (`ProConfig.paywallEnabled` = false): mientras los
// productos no existan en App Store Connect, todo el mundo tiene acceso completo
// y nada cambia para los usuarios actuales. Al crear los productos basta con
// activar el flag.

import Foundation
import Observation
import OSLog
import StoreKit

enum ProProduct: String, CaseIterable, Sendable {
    case monthly = "com.idanidev.clarity.pro.monthly"
    case yearly  = "com.idanidev.clarity.pro.yearly"
    case lifetime = "com.idanidev.clarity.pro.lifetime"

    var displayOrder: Int {
        switch self {
        case .yearly: return 0
        case .monthly: return 1
        case .lifetime: return 2
        }
    }
}

@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    private(set) var products: [Product] = []
    private(set) var purchasedProductIds: Set<String> = []
    private(set) var isLoadingProducts = false
    var purchaseError: String?

    private var updatesTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.idanidev.clarity", category: "Subscription")

    private init() {
        updatesTask = observeTransactionUpdates()
    }

    // MARK: - Estado

    /// Única fuente de verdad para "¿puede usar funciones Pro?".
    /// Con el paywall apagado nadie está limitado.
    var isPro: Bool {
        guard ProConfig.paywallEnabled else { return true }
        return !purchasedProductIds.isEmpty
    }

    var hasLifetime: Bool {
        purchasedProductIds.contains(ProProduct.lifetime.rawValue)
    }

    var sortedProducts: [Product] {
        products.sorted { lhs, rhs in
            let l = ProProduct(rawValue: lhs.id)?.displayOrder ?? 99
            let r = ProProduct(rawValue: rhs.id)?.displayOrder ?? 99
            return l < r
        }
    }

    // MARK: - Carga

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            products = try await Product.products(for: ProProduct.allCases.map(\.rawValue))
            await refreshEntitlements()
        } catch {
            logger.error("No se pudieron cargar los productos: \(error.localizedDescription)")
        }
    }

    /// Relee lo que el usuario tiene comprado ahora mismo.
    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.revocationDate == nil {
                owned.insert(transaction.productID)
            }
        }
        purchasedProductIds = owned
    }

    // MARK: - Compra

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseError = "No se pudo verificar la compra."
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                HapticManager.shared.success()
                AnalyticsService.shared.track(.purchaseCompleted(productId: product.id))
                return true

            case .userCancelled:
                return false

            case .pending:
                purchaseError = "La compra está pendiente de aprobación."
                return false

            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            logger.error("Compra fallida: \(error.localizedDescription)")
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Listener

    /// Compras hechas en otro dispositivo, renovaciones y reembolsos.
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }
}

// MARK: - Configuración del paywall

enum ProConfig {
    /// Interruptor maestro. En false la app se comporta como hasta ahora.
    /// Ponerlo a true SOLO cuando los productos estén activos en App Store Connect.
    static var paywallEnabled: Bool {
        UserDefaults.standard.bool(forKey: "pro.paywallEnabled")
    }

    static func setPaywallEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "pro.paywallEnabled")
    }
}

// MARK: - Límites del plan gratuito

enum ProLimits {
    /// Gastos por voz al mes en el plan gratuito.
    static let voiceExpensesPerMonth = 30

    private static let voiceCountKey = "pro.voiceCount"
    private static let voiceMonthKey = "pro.voiceMonth"

    // MARK: Reglas puras
    //
    // La cuenta del mes y su puesta a cero dependían de `UserDefaults.standard`
    // y de la fecha de hoy, así que no había forma de probar un cambio de mes
    // sin esperar a que llegara. Las reglas son estas tres funciones, sin
    // estado; lo de abajo solo lee y escribe `UserDefaults` y delega aquí.
    // Los meses son las claves «yyyy-MM» de `Formatters.monthString(from:)`.

    /// Gastos por voz que cuentan para `mesActual`. Lo guardado solo vale si es
    /// de este mismo mes (y año: la clave lleva los dos); si no, el mes empieza
    /// de cero aunque el contador viejo siga escrito.
    nonisolated static func vozUsadosEsteMes(guardados: Int, mesGuardado: String?, mesActual: String) -> Int {
        guard mesGuardado == mesActual else { return 0 }
        return guardados
    }

    /// Cuántos quedan hasta el tope. Nunca negativo, aunque el contador se
    /// haya pasado (p. ej. si el límite se baja en una versión posterior).
    nonisolated static func vozRestantes(usados: Int, limite: Int) -> Int {
        max(0, limite - usados)
    }

    /// Contador tras apuntar un gasto por voz: si el mes guardado no es el
    /// actual se arranca de cero ANTES de sumar, así que el primero del mes
    /// deja el contador en 1 y no en «los del mes pasado + 1».
    nonisolated static func vozTrasRegistrar(
        guardados: Int, mesGuardado: String?, mesActual: String
    ) -> (usados: Int, mes: String) {
        (vozUsadosEsteMes(guardados: guardados, mesGuardado: mesGuardado, mesActual: mesActual) + 1, mesActual)
    }

    // MARK: Estado (UserDefaults + fecha de hoy)

    @MainActor
    static var voiceExpensesUsedThisMonth: Int {
        let defaults = UserDefaults.standard
        return vozUsadosEsteMes(
            guardados: defaults.integer(forKey: voiceCountKey),
            mesGuardado: defaults.string(forKey: voiceMonthKey),
            mesActual: currentMonthKey())
    }

    @MainActor
    static var remainingVoiceExpenses: Int {
        guard ProConfig.paywallEnabled, !SubscriptionManager.shared.isPro else { return .max }
        return vozRestantes(usados: voiceExpensesUsedThisMonth, limite: voiceExpensesPerMonth)
    }

    /// ¿Puede registrar otro gasto por voz?
    @MainActor
    static var canUseVoice: Bool {
        remainingVoiceExpenses > 0
    }

    @MainActor
    static func registerVoiceExpense() {
        guard ProConfig.paywallEnabled, !SubscriptionManager.shared.isPro else { return }
        let defaults = UserDefaults.standard
        let mesGuardado = defaults.string(forKey: voiceMonthKey)
        let nuevo = vozTrasRegistrar(
            guardados: defaults.integer(forKey: voiceCountKey),
            mesGuardado: mesGuardado,
            mesActual: currentMonthKey())
        // Igual que antes: el mes solo se reescribe cuando cambia.
        if mesGuardado != nuevo.mes {
            defaults.set(nuevo.mes, forKey: voiceMonthKey)
        }
        defaults.set(nuevo.usados, forKey: voiceCountKey)
    }

    private static func currentMonthKey() -> String {
        Formatters.currentMonthString()
    }
}
