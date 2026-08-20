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
        ("square.and.arrow.up", "Exportar a CSV", "Tus datos son tuyos, siempre"),
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
            .background(DesignTokens.Colors.background)
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
        VStack(spacing: Spacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.clarityPrimary)
                .padding(.top, Spacing.md)

            Text(reason.headline)
                .scaledFont(size: 24, weight: .bold)
                .multilineTextAlignment(.center)

            Text(reason.subheadline)
                .scaledFont(size: 14)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(features, id: \.title) { feature in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(Color.clarityPrimary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .scaledFont(size: 15, weight: .semibold)
                        Text(feature.detail)
                            .scaledFont(size: 12)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    @ViewBuilder
    private var planPicker: some View {
        if subscriptions.isLoadingProducts {
            ProgressView().tint(Color.clarityPrimary)
        } else if subscriptions.sortedProducts.isEmpty {
            Text("Los planes no están disponibles ahora mismo.")
                .scaledFont(size: 13)
                .foregroundStyle(.secondary)
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
                            .scaledFont(size: 16, weight: .semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.clarityPrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .disabled(isPurchasing)
        }
    }

    private var legalLinks: some View {
        VStack(spacing: Spacing.xxs) {
            Text("La suscripción se renueva automáticamente salvo que la canceles al menos 24 h antes del final del periodo. Puedes gestionarla en los Ajustes de tu Apple ID.")
                .scaledFont(size: 10)
                .foregroundStyle(.tertiary)
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
                .foregroundStyle(isSelected ? Color.clarityPrimary : Color.secondary)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .scaledFont(size: 15, weight: .semibold)
                Text(periodLabel)
                    .scaledFont(size: 12)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(product.displayPrice)
                .scaledFont(size: 16, weight: .bold)
                .foregroundStyle(isSelected ? Color.clarityPrimary : Color.primary)
        }
        .padding(Spacing.sm)
        .background(isSelected ? Color.clarityPrimary.opacity(0.1) : Color.glassBackground)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(isSelected ? Color.clarityPrimary : Color.clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .contentShape(Rectangle())
    }
}
