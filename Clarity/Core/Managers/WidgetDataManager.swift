// WidgetDataManager.swift
// Manages data sharing between main app and widget via App Group

import Foundation
import OSLog
import WidgetKit

@MainActor
final class WidgetDataManager {
    static let shared = WidgetDataManager()

    private let appGroupID  = "group.com.idanidev.clarity"
    private let widgetKey   = "widgetData_v2"
    private let logger = Logger(subsystem: "com.idanidev.clarity", category: "WidgetDataManager")

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private init() {}

    // MARK: - Public API

    /// Full update: call this whenever expenses or budget changes.
    func updateFromExpenses(_ expenses: [Expense], monthBudget: Double? = nil) {
        let calendar = Calendar.current
        let now      = Date()

        let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        ) ?? now
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? now

        // ── Single-pass accumulation ──
        var todayTotal: Double = 0
        var weekTotal: Double = 0
        var monthTotal: Double = 0
        var todayCategoryTotals: [String: Double] = [:]
        var monthCategoryTotals: [String: Double] = [:]

        for expense in expenses {
            guard let d = Formatters.date(from: expense.date) else { continue }
            let amount = expense.amount

            if d >= monthStart && d <= now {
                monthTotal += amount
                monthCategoryTotals[expense.category, default: 0] += amount
            }
            if d >= weekStart && d <= now {
                weekTotal += amount
            }
            if calendar.isDateInToday(d) {
                todayTotal += amount
                todayCategoryTotals[expense.category, default: 0] += amount
            }
        }

        let topCategory = todayCategoryTotals.max(by: { $0.value < $1.value })?.key
        let topEmoji = topCategory.map { categoryEmoji(for: $0) } ?? "💳"

        // ── Top 3 categorías del mes ──
        let topMonthCats: [WidgetCategoryStat] = monthCategoryTotals
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { (cat, amount) in
                WidgetCategoryStat(
                    name: cat,
                    emoji: categoryEmoji(for: cat),
                    amount: amount,
                    percent: monthTotal > 0 ? min(amount / monthTotal, 1.0) : 0
                )
            }

        // ── Recent 5 expenses (partial sort) ──
        let recentExpenses = expenses
            .sorted { ($0.date, $0.name) > ($1.date, $1.name) }
            .prefix(5)
            .map { e -> WidgetExpense in
                WidgetExpense(
                    name:     e.name,
                    amount:   e.amount,
                    emoji:    categoryEmoji(for: e.category),
                    category: e.category,
                    timeAgo:  formatTimeAgo(e.date, calendar: calendar)
                )
            }

        // ── Month name ──
        let monthName = Formatters.fullMonthName(from: now)

        var data = SharedWidgetData(
            todayTotal:       todayTotal,
            weekTotal:        weekTotal,
            monthTotal:       monthTotal,
            monthBudget:      monthBudget,   // Lo pasa el caller (HomeVM con income - savings)
            recentExpenses:   Array(recentExpenses),
            topCategoryEmoji: topEmoji,
            currency:         "€",
            monthName:        monthName,
            updatedAt:        now
        )
        data.topMonthCategories = topMonthCats

        save(data)
        logger.debug("✅ [Widget] Updated — Hoy: \(todayTotal)€, Mes: \(monthTotal)€")

        // Único punto donde coinciden gasto del mes y presupuesto, así que es
        // aquí donde se detecta que el usuario se pasa del límite (#41).
        AnalyticsService.shared.trackBudgetThresholdIfCrossed(
            spent: monthTotal, budget: monthBudget)
    }

    // MARK: - Read (for debugging)

    func getCurrentWidgetData() -> SharedWidgetData? {
        guard
            let defaults = sharedDefaults,
            let raw      = defaults.data(forKey: widgetKey)
        else { return nil }
        do {
            return try JSONDecoder().decode(SharedWidgetData.self, from: raw)
        } catch {
            // Lo que lee el widget ya no casa con el modelo (un campo que
            // cambió de forma): sin esto, el widget en blanco no tenía causa.
            // El error, con la privacidad por defecto: un `DecodingError` puede
            // citar el valor que no supo leer, y aquí hay nombres e importes.
            logger.error("⚠️ [Widget] Datos compartidos ilegibles (\(raw.count) bytes): \(String(describing: error))")
            return nil
        }
    }

    // MARK: - Clear

    func clearWidgetData() {
        sharedDefaults?.removeObject(forKey: widgetKey)
        WidgetCenter.shared.reloadAllTimelines()
        logger.debug("🗑️ [Widget] Data cleared")
    }

    // MARK: - Private

    private func save(_ data: SharedWidgetData) {
        guard let defaults = sharedDefaults else {
            logger.warning("⚠️ [Widget] Cannot access App Group UserDefaults (\(self.appGroupID))")
            return
        }
        if let encoded = try? JSONEncoder().encode(data) {
            // Los datos, siempre y al momento; la recarga, agrupada.
            defaults.set(encoded, forKey: widgetKey)
            pedirRecarga()
        }
    }

    // MARK: - Recarga agrupada

    private var agrupador = AgrupadorDeRecargas()
    private var recargaProgramada: Task<Void, Never>?

    /// Pide una recarga de los widgets sin lanzarla en el acto.
    ///
    /// Guardar un gasto por voz escribe aquí dos veces seguidas (el gasto puesto
    /// a mano en la lista y el refresco que lo reconcilia), y un dictado con N
    /// gastos, 2N. Cada escritura acababa en un `reloadAllTimelines()`, que
    /// vuelve a pintar todos los widgets. Como lo que leen es siempre lo último
    /// escrito, basta una recarga cuando la ráfaga se calma.
    private func pedirRecarga() {
        agrupador.pedir(a: Date())
        // Ya hay una tarea esperando: al despertar verá el vencimiento nuevo.
        guard recargaProgramada == nil else { return }
        recargaProgramada = Task { [weak self] in
            while let falta = self?.agrupador.vencimiento?.timeIntervalSinceNow, falta > 0 {
                // Nadie cancela esta tarea; si algún día pasa, que no se quede
                // dando vueltas con un `sleep` que ya no duerme.
                do { try await Task.sleep(for: .seconds(falta)) } catch { break }
            }
            guard let self else { return }
            self.agrupador.recargada()
            self.recargaProgramada = nil
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Category → Emoji
    // Las categorías de Clarity ya llevan el emoji dentro (ej: "Ocio 🍻", "Alimentación 🛒")
    // Lo extraemos directamente en lugar de usar una tabla hardcodeada.

    private func categoryEmoji(for category: String) -> String {
        // Buscar el primer emoji real (codepoint > 127) en la cadena
        for scalar in category.unicodeScalars {
            if scalar.properties.isEmoji && scalar.value > 127 {
                return String(scalar)
            }
        }
        return "💳"
    }

    /// Elimina los emojis del nombre de categoría para mostrar solo el texto
    private func cleanCategory(_ raw: String) -> String {
        raw.unicodeScalars
            .filter { !$0.properties.isEmoji || $0.value < 127 }
            .map { Character($0) }
            .reduce("") { $0 + String($1) }
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Time Ago

    private func formatTimeAgo(_ dateString: String, calendar: Calendar) -> String {
        guard let date = Formatters.date(from: dateString) else { return "" }
        if calendar.isDateInToday(date) {
            return Formatters.time(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Ayer"
        } else {
            let diff = calendar.dateComponents([.day], from: date, to: Date())
            return "Hace \(diff.day ?? 0)d"
        }
    }
}

// MARK: - Política de agrupación

/// Cuándo toca recargar los widgets, dadas las peticiones que van llegando.
///
/// Sin reloj propio ni tareas: recibe la hora desde fuera para poder probarse.
/// Espera a que pase `margen` sin peticiones nuevas, pero nunca más de `tope`
/// desde la primera: una ráfaga que no para no deja el widget sin actualizar.
struct AgrupadorDeRecargas {
    let margen: TimeInterval
    let tope: TimeInterval

    private var primeraPeticion: Date?
    private var ultimaPeticion: Date?

    init(margen: TimeInterval = 1, tope: TimeInterval = 3) {
        self.margen = margen
        self.tope = tope
    }

    var hayPendiente: Bool { primeraPeticion != nil }

    /// Momento en que toca recargar, o `nil` si no hay nada pendiente.
    var vencimiento: Date? {
        guard let primeraPeticion, let ultimaPeticion else { return nil }
        return min(ultimaPeticion.addingTimeInterval(margen), primeraPeticion.addingTimeInterval(tope))
    }

    mutating func pedir(a ahora: Date) {
        if primeraPeticion == nil { primeraPeticion = ahora }
        ultimaPeticion = ahora
    }

    /// La recarga ya se ha lanzado: la siguiente petición abre otra ráfaga.
    mutating func recargada() {
        primeraPeticion = nil
        ultimaPeticion = nil
    }
}
