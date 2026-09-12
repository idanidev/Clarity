// OnboardingView.swift
// Onboarding premium con mockups visuales de cada feature

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - OnboardingView

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var page = 0
    @State private var isSaving = false
    /// Si el usuario apuntó su primer gasto sin salir del onboarding.
    @State private var primerGastoHecho = false

    /// Las páginas, por nombre. Antes esto era aritmética sobre
    /// `totalFeaturePages` ("+1", "+2") y había que contar con los dedos para
    /// saber de qué pantalla hablaba cada rama.
    private enum Pagina {
        static let bienvenida = 0
        static let primerGasto = 1
        static let listo = 2
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dark premium base
            Color.black.ignoresSafeArea()

            // Page content
            TabView(selection: $page) {
                WelcomePage().tag(Pagina.bienvenida)
                PrimerGastoPage(yaRegistrado: $primerGastoHecho).tag(Pagina.primerGasto)
                DonePage(conGasto: primerGastoHecho).tag(Pagina.listo)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .task {
                trackOnboardingStart()
                trackOnboardingPage(page)
            }
            .onChange(of: page) { _, nueva in
                trackOnboardingPage(nueva)
            }
            .animation(.easeInOut(duration: 0.35), value: page)
            .ignoresSafeArea()

            // Bottom overlay
            VStack(spacing: 0) {
                Spacer()

                // Dot indicators
                if page <= Pagina.listo {
                    HStack(spacing: 6) {
                        ForEach(Pagina.bienvenida...Pagina.listo, id: \.self) { i in
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
                        withAnimation { page = Pagina.listo }
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
        case Pagina.bienvenida: return "Vamos a probarlo"
        // En la página del primer gasto el botón deja de empujar: si ya se
        // apuntó algo, celebra; si no, permite pasar sin culpabilizar.
        case Pagina.primerGasto: return primerGastoHecho ? "Genial, sigue" : "Lo hago luego"
        case Pagina.listo: return "Empezar"
        default: return "Siguiente"
        }
    }

    /// Nombre de cada página del onboarding. Sin esto se sabe cuántos empiezan
    /// y cuántos acaban, pero no en cuál se caen —que es el dato que dice qué
    /// pantalla arreglar—. Va por `onChange` y no por `.trackScreen` en cada
    /// página porque el TabView precarga las vecinas: con `.task` contaría como
    /// vistas páginas por las que nadie ha pasado.
    private func trackOnboardingPage(_ index: Int) {
        let nombre: String
        switch index {
        case Pagina.bienvenida: nombre = "onboarding_bienvenida"
        case Pagina.primerGasto: nombre = "onboarding_primer_gasto"
        default: nombre = "onboarding_listo"
        }
        AnalyticsService.shared.track(.screenViewed(name: nombre))
    }

    private func trackOnboardingStart() {
        AnalyticsService.shared.track(.onboardingStarted)
    }

    private func nextPage() {
        if page == Pagina.listo {
            saveAndComplete()
        } else {
            page += 1
        }
    }

    private func saveAndComplete() {
        AnalyticsService.shared.track(.onboardingCompleted)
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
                // La nómina ya no se pide aquí (#49): el asistente de presupuesto
                // salta solo al entrar en Metas, que es donde hace falta.
                try await Firestore.firestore().collection("users").document(userId).updateData([
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                await UserDataManager.shared.loadUserData()
            } catch { /* el onboarding se marca igual en local */ }
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
                    // Sin "sparkles": prometía la IA, que está deshabilitada y ya
                    // no tiene ni entrada en la app.
                    ForEach(["mic.fill", "repeat", "chart.pie.fill"], id: \.self) { icon in
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

// MARK: - Página final

private struct DonePage: View {
    /// El resumen no promete: cuenta lo que el usuario acaba de hacer.
    var conGasto: Bool = false
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
                        summaryRow(icon: conGasto ? "checkmark.circle.fill" : "waveform.circle.fill",
                                   color: Color(hex: "#3B82F6"),
                                   text: conGasto ? "Tu primer gasto ya está dentro" : "Gastos por voz listos")
                        Divider().background(Color.white.opacity(0.06))
                        summaryRow(icon: "mic.circle.fill", color: Color(hex: "#8B5CF6"),
                                   text: "Con Siri: «Clarity, añade un gasto»")
                        Divider().background(Color.white.opacity(0.06))
                        summaryRow(icon: "chart.pie.fill", color: Color(hex: "#10B981"),
                                   text: "Tu presupuesto, cuando lo necesites")
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

// MARK: - Primer gasto, dentro del onboarding
//
// De cada 64 personas que instalan, 43 terminan el onboarding y solo 30 llegan
// a registrar un gasto: más de la mitad se va sin usar la app ni una vez, y en
// una app de gastos quien no apunta el primero no vuelve (#57).
//
// Las tres pantallas anteriores explican que se puede hablar. Ésta lo hace
// pasar: se apunta un gasto de verdad, aquí, antes de salir. No es una demo —
// el gasto queda guardado.

private struct PrimerGastoPage: View {
    @Binding var yaRegistrado: Bool

    @State private var viewModel = DependencyContainer.shared.makeHomeViewModel()
    @State private var mostrarManual = false
    @State private var appear = false
    @State private var pulso = false

    /// Nº de gastos al entrar. Comparar contra esto es lo que dice si el que
    /// acaba de aparecer lo ha metido el usuario ahora.
    @State private var gastosAlEmpezar: Int?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(Color(hex: "#8B5CF6").opacity(0.18))
                .frame(width: 420)
                .blur(radius: 110)
                .offset(y: -120)

            VStack(spacing: 0) {
                Spacer().frame(height: 90)

                Text(yaRegistrado ? "¡Ya está!" : "Pruébalo ahora")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 12)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appear)

                Text(yaRegistrado
                     ? "Eso es todo. Así de rápido cada vez."
                     : "Pulsa el micro y di lo que te has gastado.\nPor ejemplo: «tres euros en un café».")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.08), value: appear)

                Spacer()

                if yaRegistrado {
                    VStack(spacing: 22) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 88, weight: .light))
                            .foregroundStyle(Color(hex: "#10B981"))
                            .shadow(color: Color(hex: "#10B981").opacity(0.5), radius: 26, y: 8)

                        // La prueba de que ha funcionado es el gasto, no un icono.
                        if let gasto = viewModel.allExpenses.first {
                            HStack(spacing: 12) {
                                Text(gasto.category.categoryNameEmoji.emoji ?? "💸")
                                    .font(.system(size: 22))
                                Text(gasto.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer(minLength: 12)
                                Text(Formatters.currency(gasto.amount))
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Color(hex: "#C9C3FF"))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .padding(.horizontal, 40)
                        }
                    }
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                } else {
                    ZStack {
                        // Los mismos anillos que la pantalla de la voz: dicen
                        // "háblale a esto" sin una sola palabra, y hacen que
                        // esta pantalla no desentone con sus vecinas.
                        ForEach(0..<3) { i in
                            Circle()
                                .strokeBorder(
                                    Color(hex: "#8B5CF6").opacity(0.16 - Double(i) * 0.04),
                                    lineWidth: 1.5
                                )
                                .frame(width: CGFloat(150 + i * 58), height: CGFloat(150 + i * 58))
                                .scaleEffect(pulso ? 1.04 : 0.97)
                                .animation(
                                    .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.18),
                                    value: pulso
                                )
                        }

                        SimpleVoiceButton(
                            viewModel: viewModel,
                            categories: UserDataManager.shared.categories
                        )
                        .scaleEffect(1.35)
                    }
                    .opacity(appear ? 1 : 0)
                    .scaleEffect(appear ? 1 : 0.7)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.16), value: appear)

                    Button {
                        mostrarManual = true
                        HapticManager.shared.selection()
                    } label: {
                        Text("Prefiero escribirlo")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.top, 56)
                    }
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: appear)
                }

                Spacer()
                Spacer()
            }
        }
        .sheet(isPresented: $mostrarManual) {
            AddExpenseSheet {
                registrado(metodo: "manual")
            }
            .presentationDetents([.large])
        }
        .task {
            await viewModel.loadIfNeeded()
            if gastosAlEmpezar == nil { gastosAlEmpezar = viewModel.allExpenses.count }
            appear = true
            pulso = true
        }
        // La voz guarda por su cuenta y no avisa por callback: se detecta
        // porque la lista crece.
        .onChange(of: viewModel.allExpenses.count) { _, nuevos in
            guard let base = gastosAlEmpezar, nuevos > base, !yaRegistrado else { return }
            registrado(metodo: "voz")
        }
    }

    private func registrado(metodo: String) {
        guard !yaRegistrado else { return }
        AnalyticsService.shared.track(.onboardingFirstExpense(method: metodo))
        HapticManager.shared.notification(.success)
        withAnimation(.spring(response: 0.5)) { yaRegistrado = true }
    }
}
