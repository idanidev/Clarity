// ProPaywallView.swift
// Pantalla de compra de Clarity Pro (#40 §3).

import StoreKit
import SwiftUI

struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptions = SubscriptionManager.shared
    @State private var selectedProductId: String?
    @State private var isPurchasing = false

    /// Motivo por el que se abrió el paywall, para encabezarlo con contexto.
    var reason: PaywallReason = .general

    enum PaywallReason {
        case general
        case voiceLimit
        case export

        var headline: String {
            switch self {
            case .general: return "Clarity Pro"
            case .voiceLimit: return "Has gastado tus registros por voz de este mes"
            case .export: return "Exportar es una función Pro"
            }
        }

        var subheadline: String {
            switch self {
            case .general: return "Todo lo que hace Clarity, sin límites."
            case .voiceLimit: return "Con Pro puedes registrar gastos por voz sin contar."
            case .export: return "Llévate tus datos a CSV cuando quieras."
            }
        }
    }

    private let features: [(icon: String, title: String, detail: String)] = [
        ("mic.fill", "Voz sin límites", "Registra todos los gastos que quieras hablando"),
        ("square.grid.2x2.fill", "Categorías a medida", "Crea las que necesites, sin tope"),
        // Exportar a CSV está desactivado en Ajustes: no se vende lo que no se puede usar.
        // ("square.and.arrow.up", "Exportar a CSV", "Tus datos son tuyos, siempre"),
        ("chart.line.uptrend.xyaxis", "Análisis completo", "Tendencias y comparativas de todo tu historial"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    header
                    featureList
                    planPicker
                    purchaseButton
                    legalLinks
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .fondoClarity()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restaurar") {
                        Task { await subscriptions.restorePurchases() }
                    }
                    .scaledFont(size: 14)
                }
            }
            .task {
                await subscriptions.loadProducts()
                if selectedProductId == nil {
                    selectedProductId = subscriptions.sortedProducts.first?.id
                }
            }
            .alert(
                "No se pudo completar",
                isPresented: Binding(
                    get: { subscriptions.purchaseError != nil },
                    set: { if !$0 { subscriptions.purchaseError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { subscriptions.purchaseError = nil }
            } message: {
                Text(subscriptions.purchaseError ?? "")
            }
            .onChange(of: subscriptions.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            CirculoIconoClarity(icono: "sparkles", tamano: 76, esSimbolo: true)
                .padding(.top, Spacing.md)

            VStack(spacing: Spacing.xs) {
                Text(reason.headline)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(reason.subheadline)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(features, id: \.title) { feature in
                HStack(spacing: Spacing.sm) {
                    CirculoIconoClarity(icono: feature.icon, tamano: 40, esSimbolo: true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.subheadline.weight(.semibold))
                        Text(feature.detail)
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: CornerRadius.xlarge)
    }

    @ViewBuilder
    private var planPicker: some View {
        if subscriptions.isLoadingProducts {
            ProgressView().tint(Color.clarityPrimary)
        } else if subscriptions.sortedProducts.isEmpty {
            Text("Los planes no están disponibles ahora mismo.")
                .scaledFont(size: 13)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        } else {
            VStack(spacing: Spacing.xs) {
                ForEach(subscriptions.sortedProducts, id: \.id) { product in
                    PlanRow(
                        product: product,
                        isSelected: selectedProductId == product.id
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: AnimationDuration.fast)) {
                            selectedProductId = product.id
                        }
                        HapticManager.shared.selection()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var purchaseButton: some View {
        if let product = subscriptions.sortedProducts.first(where: { $0.id == selectedProductId }) {
            Button {
                isPurchasing = true
                Task {
                    await subscriptions.purchase(product)
                    isPurchasing = false
                }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continuar · \(product.displayPrice)")
                    }
                }
            }
            .buttonStyle(.principalClarity)
            .disabled(isPurchasing)
        }
    }

    private var legalLinks: some View {
        VStack(spacing: Spacing.xxs) {
            Text("La suscripción se renueva automáticamente salvo que la canceles al menos 24 h antes del final del periodo. Puedes gestionarla en los Ajustes de tu Apple ID.")
                .scaledFont(size: 10)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: Spacing.sm) {
                Link("Términos", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacidad", destination: URL(string: "https://idanidev.com/clarity/privacidad")!)
            }
            .scaledFont(size: 11)
        }
    }
}

// MARK: - Fila de plan

private struct PlanRow: View {
    let product: Product
    let isSelected: Bool

    private var periodLabel: String {
        guard let subscription = product.subscription else { return "Pago único" }
        switch subscription.subscriptionPeriod.unit {
        case .month: return "al mes"
        case .year: return "al año"
        case .week: return "a la semana"
        case .day: return "al día"
        @unknown default: return ""
        }
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(isSelected ? Color.clarityPrimary : Color.textTertiary)
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(.body.weight(.semibold))
                Text(periodLabel)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            // El precio en color primario también seleccionado: sobre el vidrio
            // teñido de morado, un morado encima se leía mal.
            Text(product.displayPrice)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: CornerRadius.large, tint: isSelected ? Color.clarityPrimary : nil)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .strokeBorder(isSelected ? Color.clarityPrimary : Color.clear, lineWidth: 1.5)
        }
        .contentShape(Rectangle())
    }
}
