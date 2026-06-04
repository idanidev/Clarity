// OnboardingView.swift
// Onboarding premium con mockups visuales de cada feature

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - OnboardingView

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var page = 0
    @State private var income: String = ""
    @State private var isRecurring: Bool = true
    @State private var isSaving = false

    private let totalFeaturePages = 2 // welcome + voice + add-expense tutorial
    private var parsedIncome: Double {
        Double(income.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dark premium base
            Color.black.ignoresSafeArea()

            // Page content
            TabView(selection: $page) {
                WelcomePage().tag(0)
                VoiceSiriPage().tag(1)
                AddExpenseTutorialPage().tag(2)
                IncomePage(income: $income, isRecurring: $isRecurring).tag(3)
                DonePage(income: parsedIncome, isRecurring: isRecurring).tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: page)
            .ignoresSafeArea()

            // Bottom overlay
            VStack(spacing: 0) {
                Spacer()

                // Dot indicators (feature pages only)
                if page <= totalFeaturePages {
                    HStack(spacing: 6) {
                        ForEach(0...totalFeaturePages, id: \.self) { i in
                            Capsule()
                                .fill(i == page ? Color.white : Color.white.opacity(0.3))
                                .frame(width: i == page ? 20 : 6, height: 6)
                                .animation(.spring(response: 0.3), value: page)
                        }
                    }
                    .padding(.bottom, 16)
                }

                // CTA button
                Button {
                    withAnimation { nextPage() }
                    HapticManager.shared.selection()
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.black)
                        } else {
                            Text(ctaLabel)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .disabled(isSaving)
                .padding(.horizontal, 24)

                // Secondary action
                if page == 0 {
                    Button("Saltar") {
                        withAnimation { page = totalFeaturePages + 1 }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.top, 14)
                } else if page == totalFeaturePages + 1 {
                    // income page: skip
                    Button("Configurar después") {
                        withAnimation { page += 1 }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.top, 14)
                } else {
                    Color.clear.frame(height: 14 + 20) // consistent spacing
                }

                Color.clear.frame(height: 20)
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Helpers

    private var ctaLabel: String {
        switch page {
        case 0:           return "Descubrir Clarity"
        case totalFeaturePages: return "Configurar ahora"
        case totalFeaturePages + 1: return "Continuar"
        case totalFeaturePages + 2: return "Empezar"
        default:          return "Siguiente"
        }
    }

    private func nextPage() {
        if page == totalFeaturePages + 2 {
            saveAndComplete()
        } else {
            page += 1
        }
    }

    private func saveAndComplete() {
        guard let userId = Auth.auth().currentUser?.uid else { onComplete(); return }
        isSaving = true

        // Safety net: si Firebase tarda > 4s, completamos igualmente.
        // Evita que el botón quede bloqueado por red lenta o reglas Firestore restrictivas.
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                if isSaving {
                    isSaving = false
                    onComplete()
                }
            }
        }

        Task {
            do {
                var updates: [String: Any] = [
                    "settings.isSalaryRecurring": isRecurring,
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                if parsedIncome > 0 { updates["income"] = parsedIncome }
                try await Firestore.firestore().collection("users").document(userId).updateData(updates)
                if parsedIncome > 0 && isRecurring {
                    let cal = Calendar.current
                    let budget = MonthlyBudget(
                        userId: userId,
                        year: cal.component(.year, from: Date()),
                        month: cal.component(.month, from: Date()),
                        income: parsedIncome
                    )
                    try await DependencyContainer.shared.financialService.saveMonthlyBudget(budget)
                }
                await UserDataManager.shared.loadUserData()
            } catch { /* configurar después */ }
            await MainActor.run {
                guard isSaving else { return } // ya completado por safety net
                isSaving = false
                onComplete()
            }
        }
    }
}

// MARK: - Page 0: Welcome

private struct WelcomePage: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            // Glow orbs
            Circle()
                .fill(Color(hex: "#8B5CF6").opacity(0.35))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(x: -60, y: -120)
                .scaleEffect(appear ? 1 : 0.5)

            Circle()
                .fill(Color(hex: "#6366F1").opacity(0.25))
                .frame(width: 250)
                .blur(radius: 70)
                .offset(x: 100, y: 100)
                .scaleEffect(appear ? 1 : 0.5)

            VStack(spacing: 0) {
                Spacer()

                // Logo mark — AppIcon home-screen
                Image("HomeIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color(hex: "#8B5CF6").opacity(0.6), radius: 30, y: 10)
                    .scaleEffect(appear ? 1 : 0.4)
                    .opacity(appear ? 1 : 0)

                Spacer().frame(height: 36)

                Text("Clarity")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .offset(y: appear ? 0 : 30)
                    .opacity(appear ? 1 : 0)

                Spacer().frame(height: 12)

                Text("Tu dinero, siempre claro.")
                    .font(.title3)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .offset(y: appear ? 0 : 20)
                    .opacity(appear ? 1 : 0)

                Spacer().frame(height: 48)

                // Feature badges
                HStack(spacing: 10) {
                    ForEach(["mic.fill", "repeat", "chart.pie.fill", "sparkles"], id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .opacity(appear ? 1 : 0)

                Spacer()
                Spacer()
            }
        }
        .background(Color.black)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { appear = true }
        }
    }
}

// MARK: - Page 1: Voice & Siri

private struct VoiceSiriPage: View {
    @State private var appear = false
    @State private var wavePhase: CGFloat = 0
    @State private var showCard = false
    @State private var showSiri = false

    private let bars = 28

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Purple glow
            Circle()
                .fill(Color(hex: "#8B5CF6").opacity(0.2))
                .frame(width: 400)
                .blur(radius: 100)
                .offset(y: -80)

            VStack(spacing: 0) {
                Spacer().frame(height: 70)

                // Illustration: mic + waveform
                ZStack {
                    // Waveform rings
                    ForEach(0..<3) { i in
                        Circle()
                            .strokeBorder(Color(hex: "#8B5CF6").opacity(0.15 - Double(i) * 0.04), lineWidth: 1.5)
                            .frame(width: CGFloat(100 + i * 50), height: CGFloat(100 + i * 50))
                            .scaleEffect(appear ? 1 : 0.2)
                            .animation(.spring(response: 0.6).delay(Double(i) * 0.08 + 0.1), value: appear)
                    }

                    // Mic circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#8B5CF6"), Color(hex: "#6366F1")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .shadow(color: Color(hex: "#8B5CF6").opacity(0.7), radius: 24, y: 8)

                    Image(systemName: "waveform")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(height: 200)
                .scaleEffect(appear ? 1 : 0.5)
                .opacity(appear ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appear)

                Spacer().frame(height: 32)

                // Mock voice transcript
                if showCard {
                    VStack(spacing: 10) {
                        // Transcript bubble
                        HStack {
                            Image(systemName: "waveform")
                                .font(.caption.bold())
                                .foregroundStyle(Color(hex: "#8B5CF6"))
                            Text("\"Añade 20 euros en gasolina\"")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Result card
                        HStack(spacing: 12) {
                            Text("⛽")
                                .font(.title2)
                                .frame(width: 40, height: 40)
                                .background(Color(hex: "#F59E0B").opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gasolina")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("Transporte · Hoy")
                                    .font(.caption)
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                            Spacer()
                            Text("20,00 €")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .padding(.horizontal, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Siri trigger card — frase EXACTA destacada
                if showSiri {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "mic.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(Color(hex: "#8B5CF6"))
                            Text("CON SIRI, DI:")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(hex: "#8B5CF6"))
                                .tracking(1.5)
                        }

                        Text("\"Oye Siri, Clarity añade un gasto\"")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#8B5CF6").opacity(0.18), Color(hex: "#6366F1").opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: "#8B5CF6").opacity(0.4), lineWidth: 1))
                    .padding(.top, 12)
                    .padding(.horizontal, 28)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer().frame(height: 28)

                pageText(
                    tag: "GASTOS POR VOZ Y SIRI",
                    title: "Habla, y queda\nregistrado.",
                    subtitle: "Empieza siempre por \"Clarity\" para que Siri te entienda al instante: \"Clarity añade un gasto\", \"Clarity cuánto llevo gastado\"."
                )

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appear = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.6)) { showCard = true }
            withAnimation(.easeOut(duration: 0.3).delay(1.0)) { showSiri = true }
        }
    }
}

// MARK: - Page 2: Add Expense Tutorial

private struct AddExpenseTutorialPage: View {
    @State private var appear = false
    @State private var showStep1 = false
    @State private var showStep2 = false
    @State private var showStep3 = false
    @State private var pulseButton = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(Color(hex: "#F59E0B").opacity(0.15))
                .frame(width: 350)
                .blur(radius: 100)
                .offset(x: 40, y: -80)

            Circle()
                .fill(Color(hex: "#8B5CF6").opacity(0.1))
                .frame(width: 250)
                .blur(radius: 80)
                .offset(x: -60, y: 60)

            VStack(spacing: 0) {
                Spacer().frame(height: 70)

                // Mock "+" button
                ZStack {
                    // Pulse rings
                    ForEach(0..<2) { i in
                        Circle()
                            .strokeBorder(Color(hex: "#8B5CF6").opacity(0.2), lineWidth: 1.5)
                            .frame(width: CGFloat(90 + i * 30), height: CGFloat(90 + i * 30))
                            .scaleEffect(pulseButton ? 1.15 : 1)
                            .opacity(pulseButton ? 0 : 0.6)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.3),
                                value: pulseButton
                            )
                    }

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#8B5CF6"), Color(hex: "#6366F1")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: Color(hex: "#8B5CF6").opacity(0.6), radius: 20, y: 6)

                    Image(systemName: "plus")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(appear ? 1 : 0.4)
                .opacity(appear ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appear)

                Spacer().frame(height: 28)

                // Step-by-step visual hints
                VStack(spacing: 10) {
                    if showStep1 {
                        tutorialStep(
                            number: "1",
                            icon: "plus.circle.fill",
                            text: "Pulsa + para crear un gasto",
                            color: Color(hex: "#8B5CF6")
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if showStep2 {
                        tutorialStep(
                            number: "2",
                            icon: "eurosign.circle.fill",
                            text: "Escribe el monto y elige categoría",
                            color: Color(hex: "#F59E0B")
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if showStep3 {
                        tutorialStep(
                            number: "3",
                            icon: "checkmark.circle.fill",
                            text: "Confirma y listo — queda registrado",
                            color: Color(hex: "#10B981")
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 28)

                // Alt hint
                if showStep3 {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.caption.bold())
                            .foregroundStyle(Color(hex: "#8B5CF6"))
                        Text("O simplemente dilo por voz")
                            .font(.caption.bold())
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer().frame(height: 28)

                pageText(
                    tag: "REGISTRA GASTOS",
                    title: "Añadir un gasto\ntoma 5 segundos.",
                    subtitle: "Escríbelo a mano, dilo por voz o pídelo a Siri. Clarity categoriza automáticamente cada gasto."
                )

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appear = true }
            pulseButton = true
            withAnimation(.easeOut(duration: 0.35).delay(0.5)) { showStep1 = true }
            withAnimation(.easeOut(duration: 0.35).delay(0.9)) { showStep2 = true }
            withAnimation(.easeOut(duration: 0.35).delay(1.3)) { showStep3 = true }
        }
    }

    private func tutorialStep(number: String, icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - (Archived) Recurring Expenses

private struct RecurringPage: View {
    @State private var appear = false

    private let items: [(emoji: String, name: String, amount: String, color: Color)] = [
        ("📺", "Netflix", "15,99 €", Color(hex: "#EF4444")),
        ("🎵", "Spotify", "9,99 €", Color(hex: "#10B981")),
        ("📦", "Amazon Prime", "4,99 €", Color(hex: "#F59E0B")),
        ("☁️", "iCloud", "2,99 €", Color(hex: "#3B82F6")),
        ("🏠", "Alquiler", "750,00 €", Color(hex: "#8B5CF6")),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(Color(hex: "#10B981").opacity(0.15))
                .frame(width: 350)
                .blur(radius: 100)
                .offset(y: -60)

            VStack(spacing: 0) {
                Spacer().frame(height: 70)

                // Stacked cards illustration
                ZStack {
                    ForEach(Array(items.prefix(4).enumerated().reversed()), id: \.offset) { i, item in
                        recurringCard(item: item)
                            .offset(y: CGFloat(i) * -6)
                            .scaleEffect(1 - CGFloat(i) * 0.04)
                            .opacity(appear ? 1 - Double(i) * 0.15 : 0)
                            .offset(y: appear ? 0 : 40)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(i) * 0.07 + 0.1), value: appear)
                    }
                }
                .frame(height: 190)
                .padding(.horizontal, 28)

                // Auto badge
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: "#10B981"))
                    Text("Clarity los registra automáticamente cada mes")
                        .font(.caption.bold())
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(hex: "#10B981").opacity(0.1))
                .clipShape(Capsule())
                .padding(.top, 20)
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.6), value: appear)

                Spacer().frame(height: 28)

                pageText(
                    tag: "GASTOS RECURRENTES",
                    title: "Suscripciones y pagos fijos,\ngestionados solos.",
                    subtitle: "Define una vez tus gastos recurrentes — Netflix, alquiler, gimnasio — y Clarity los crea automáticamente cada mes en la fecha correcta."
                )

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appear = true }
        }
    }

    private func recurringCard(item: (emoji: String, name: String, amount: String, color: Color)) -> some View {
        HStack(spacing: 12) {
            Text(item.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(item.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundStyle(item.color)
                    Text("Mensual")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            Spacer()
            Text(item.amount)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "#111111"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Page 3: Charts & Analytics

private struct ChartsPage: View {
    @State private var appear = false
    @State private var chartProgress: Double = 0

    private let segments: [(color: Color, fraction: Double, label: String, amount: String)] = [
        (Color(hex: "#8B5CF6"), 0.32, "Vivienda",      "768 €"),
        (Color(hex: "#3B82F6"), 0.22, "Alimentación",  "528 €"),
        (Color(hex: "#10B981"), 0.18, "Ocio",           "432 €"),
        (Color(hex: "#F59E0B"), 0.14, "Transporte",     "336 €"),
        (Color(hex: "#EC4899"), 0.14, "Otros",          "336 €"),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(Color(hex: "#3B82F6").opacity(0.12))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(y: -100)

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                // Donut chart
                ZStack {
                    donutChart
                        .frame(width: 170, height: 170)

                    VStack(spacing: 2) {
                        Text("2.400 €")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("este mes")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0.6)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appear)

                Spacer().frame(height: 20)

                // Legend rows
                VStack(spacing: 8) {
                    ForEach(Array(segments.prefix(4).enumerated()), id: \.offset) { i, seg in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(seg.color)
                                .frame(width: 8, height: 8)
                            Text(seg.label)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.white.opacity(0.7))
                            Spacer()
                            // Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.07)).frame(height: 4)
                                    Capsule().fill(seg.color)
                                        .frame(width: geo.size.width * seg.fraction * (appear ? 1 : 0), height: 4)
                                        .animation(.spring(response: 0.7).delay(Double(i) * 0.08 + 0.3), value: appear)
                                }
                            }
                            .frame(width: 80, height: 4)

                            Text(seg.amount)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 52, alignment: .trailing)
                        }
                        .opacity(appear ? 1 : 0)
                        .offset(x: appear ? 0 : 20)
                        .animation(.spring(response: 0.4).delay(Double(i) * 0.07 + 0.2), value: appear)
                    }
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 24)

                pageText(
                    tag: "GRÁFICOS Y ANÁLISIS",
                    title: "Ve a dónde va\ncada euro.",
                    subtitle: "Gráficos de dona por categoría, barras de evolución mensual, y comparativas entre meses — todo actualizado en tiempo real."
                )

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appear = true }
        }
    }

    private var donutChart: some View {
        ZStack {
            Circle().fill(Color(hex: "#111111"))

            ForEach(Array(segments.enumerated()), id: \.offset) { i, seg in
                let start = segments.prefix(i).reduce(0) { $0 + $1.fraction }
                Circle()
                    .trim(from: start, to: start + seg.fraction * chartProgress)
                    .stroke(seg.color, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }

            Circle()
                .fill(Color.black)
                .frame(width: 116, height: 116)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).delay(0.3)) { chartProgress = 1 }
        }
    }
}

// MARK: - Page 4: AI Advisor Clara

private struct AIAdvisorPage: View {
    @State private var showMsg1 = false
    @State private var showMsg2 = false
    @State private var showMsg3 = false
    @State private var showMsg4 = false
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(Color(hex: "#EC4899").opacity(0.15))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(x: 60, y: -80)

            Circle()
                .fill(Color(hex: "#8B5CF6").opacity(0.12))
                .frame(width: 200)
                .blur(radius: 70)
                .offset(x: -80, y: 60)

            VStack(spacing: 0) {
                Spacer().frame(height: 70)

                // Clara avatar + name
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#8B5CF6"), Color(hex: "#EC4899")],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                        Text("✦")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Clara")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Asesora financiera IA")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "#10B981")).frame(width: 7, height: 7)
                        Text("En línea")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "#10B981"))
                    }
                }
                .padding(.horizontal, 28)
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: appear)

                Spacer().frame(height: 20)

                // Chat bubbles
                VStack(spacing: 10) {
                    if showMsg1 {
                        userBubble("¿Cómo voy este mes?")
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    if showMsg2 {
                        claraBubble("Llevas **487 €** gastados — el **43%** de tus ingresos. Ocio sube un 28% respecto a febrero. ⚠️")
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    if showMsg3 {
                        userBubble("¿Qué me recomiendas?")
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    if showMsg4 {
                        claraBubble("Si reduces Ocio 80 €, cierras el mes con 150 € libres. ¿Creo un límite de gasto para esa categoría? 🎯")
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 24)

                pageText(
                    tag: "ASESORA FINANCIERA IA",
                    title: "Clara conoce\ntus finanzas.",
                    subtitle: "Pregúntale lo que quieras: cuánto llevas gastado, dónde puedes ahorrar, cómo van tus metas. Analiza tus datos reales, no respuestas genéricas."
                )

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation { appear = true }
            withAnimation(.easeOut(duration: 0.3).delay(0.4)) { showMsg1 = true }
            withAnimation(.easeOut(duration: 0.3).delay(1.0)) { showMsg2 = true }
            withAnimation(.easeOut(duration: 0.3).delay(1.8)) { showMsg3 = true }
            withAnimation(.easeOut(duration: 0.3).delay(2.4)) { showMsg4 = true }
        }
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(hex: "#8B5CF6"))
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private func claraBubble(_ text: String) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "#8B5CF6"), Color(hex: "#EC4899")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 26, height: 26)
                .overlay(Text("✦").font(.system(size: 11, weight: .bold)).foregroundStyle(.white))

            Text(.init(text))  // attributed for **bold**
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            Spacer()
        }
    }
}

// MARK: - Page 5: Income Setup

private struct IncomePage: View {
    @Binding var income: String
    @Binding var isRecurring: Bool
    @State private var appear = false

    private var parsedIncome: Double {
        Double(income.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(Color(hex: "#10B981").opacity(0.12))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(x: -50, y: -100)

            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                VStack(spacing: 8) {
                    Text("💰")
                        .font(.system(size: 52))
                        .scaleEffect(appear ? 1 : 0.4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appear)

                    Text("¿Cuánto ganas\nal mes?")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .offset(y: appear ? 0 : 20)
                        .opacity(appear ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.1), value: appear)

                    Text("Salario neto. Solo tú lo ves — nunca se comparte.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .offset(y: appear ? 0 : 15)
                        .opacity(appear ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.15), value: appear)
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 40)

                // Income field
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    TextField("0", text: $income)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: 210)
                        .tint(Color(hex: "#8B5CF6"))
                        .keyboardDoneToolbar()
                    Text("€")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(
                    parsedIncome > 0 ? Color(hex: "#8B5CF6").opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1.5))
                .padding(.horizontal, 28)
                .offset(y: appear ? 0 : 20)
                .opacity(appear ? 1 : 0)
                .animation(.spring(response: 0.5).delay(0.2), value: appear)

                if parsedIncome > 0 {
                    Text("≈ \(String(format: "%.0f", parsedIncome / 30))€/día · \(String(format: "%.0f", parsedIncome * 12))€/año")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.35))
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer().frame(height: 28)

                // Recurring toggle
                Button {
                    withAnimation(.spring(response: 0.3)) { isRecurring.toggle() }
                    HapticManager.shared.selection()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: isRecurring ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isRecurring ? Color(hex: "#8B5CF6") : Color.white.opacity(0.3))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cobro fijo mensual")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Clarity crea el presupuesto solo cada mes")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.45))
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(isRecurring ? Color(hex: "#8B5CF6").opacity(0.1) : Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(
                        isRecurring ? Color(hex: "#8B5CF6").opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1))
                }
                .padding(.horizontal, 28)
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.35), value: appear)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appear = true }
        }
    }
}

// MARK: - Page 6: Done

private struct DonePage: View {
    let income: Double
    let isRecurring: Bool
    @State private var appear = false
    @State private var showRows = false

    private let confettiItems = ["✦", "◆", "●", "▲"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Gradient burst
            RadialGradient(
                colors: [Color(hex: "#8B5CF6").opacity(0.3), Color.clear],
                center: .center, startRadius: 0, endRadius: 250
            )
            .ignoresSafeArea()
            .scaleEffect(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: appear)

            // Floating confetti shapes
            ForEach(0..<8, id: \.self) { i in
                Text(confettiItems[i % confettiItems.count])
                    .font(.system(size: CGFloat([12, 8, 10, 6][i % 4])))
                    .foregroundStyle([Color(hex: "#8B5CF6"), Color(hex: "#EC4899"), Color(hex: "#10B981"), Color(hex: "#F59E0B")][i % 4].opacity(0.6))
                    .offset(
                        x: CGFloat([-120, 100, -80, 130, -110, 90, -60, 140][i]),
                        y: CGFloat([-180, -200, -120, -160, -80, -100, -220, -140][i])
                    )
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(Double(i) * 0.06 + 0.3), value: appear)
            }

            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                // Check
                ZStack {
                    Circle()
                        .fill(Color(hex: "#8B5CF6").opacity(0.15))
                        .frame(width: 120, height: 120)
                    Circle()
                        .strokeBorder(
                            LinearGradient(colors: [Color(hex: "#8B5CF6"), Color(hex: "#EC4899")], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2.5
                        )
                        .frame(width: 120, height: 120)
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(appear ? 1 : 0.3)
                .opacity(appear ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.65), value: appear)

                Spacer().frame(height: 28)

                Text("¡Todo listo!")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)
                    .animation(.spring(response: 0.4).delay(0.15), value: appear)

                Text("Clarity está configurado y listo\npara ordenar tus finanzas.")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 8)
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: appear)

                Spacer().frame(height: 32)

                // Summary
                if showRows {
                    VStack(spacing: 0) {
                        if income > 0 {
                            summaryRow(icon: "eurosign.circle.fill", color: Color(hex: "#10B981"),
                                       text: "Salario \(String(format: "%.0f", income))€/mes configurado")
                            Divider().background(Color.white.opacity(0.06))
                        }
                        summaryRow(
                            icon: isRecurring ? "arrow.clockwise.circle.fill" : "hand.tap.fill",
                            color: Color(hex: "#8B5CF6"),
                            text: isRecurring ? "Presupuesto automático activo" : "Presupuesto manual"
                        )
                        Divider().background(Color.white.opacity(0.06))
                        summaryRow(icon: "waveform.circle.fill", color: Color(hex: "#3B82F6"),
                                   text: "Gastos por voz listos")
                        Divider().background(Color.white.opacity(0.06))
                        summaryRow(icon: "sparkles", color: Color(hex: "#EC4899"),
                                   text: "Clara, tu IA financiera, activa")
                    }
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.horizontal, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appear = true }
            withAnimation(.spring(response: 0.5).delay(0.5)) { showRows = true }
        }
    }

    private func summaryRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.8))
            Spacer()
            Image(systemName: "checkmark")
                .font(.caption.bold())
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Shared helpers

private func pageText(tag: String, title: String, subtitle: String) -> some View {
    VStack(spacing: 10) {
        Text(tag)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color(hex: "#8B5CF6"))
            .tracking(2)

        Text(.init(title))
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)

        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(Color.white.opacity(0.5))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, 28)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView { }
}
