// MonthSelectorView.swift
// Compact month navigation control with prev/next arrows and month picker

import SwiftUI

struct MonthSelectorView: View {
    @Binding var currentMonth: Date
    let onMonthChanged: () -> Void

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter
    }

    var body: some View {
        HStack(spacing: 12) {
            // Botón Mes Anterior
            Button {
                if let prevMonth = Calendar.current.date(
                    byAdding: .month, value: -1, to: currentMonth)
                {
                    currentMonth = prevMonth
                    onMonthChanged()
                }
                HapticManager.shared.selection()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mes Actual (tap para month picker)
            Menu {
                // Últimos 12 meses
                ForEach(0..<12, id: \.self) { offset in
                    if let month = Calendar.current.date(
                        byAdding: .month, value: -offset, to: Date())
                    {
                        Button {
                            currentMonth = month
                            onMonthChanged()
                        } label: {
                            HStack {
                                Text(monthFormatter.string(from: month).capitalized)

                                // Checkmark si es el mes seleccionado
                                if Calendar.current.isDate(
                                    month, equalTo: currentMonth, toGranularity: .month)
                                {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(monthFormatter.string(from: currentMonth).capitalized)
                        .font(.system(size: 17, weight: .semibold))

                    Image(systemName: "calendar.circle.fill")
                        .font(.caption)
                }
                .foregroundStyle(.primary)
            }

            Spacer()

            // Botón Mes Siguiente (disabled si es futuro)
            Button {
                if let nextMonth = Calendar.current.date(
                    byAdding: .month, value: 1, to: currentMonth),
                    nextMonth <= Date()
                {  // No permitir futuro
                    currentMonth = nextMonth
                    onMonthChanged()
                }
                HapticManager.shared.selection()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundColor(canGoForward ? .secondary : .gray.opacity(0.3))
            }
            .disabled(!canGoForward)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var canGoForward: Bool {
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth)
        else {
            return false
        }
        return nextMonth <= Date()
    }
}

#Preview {
    VStack(spacing: 20) {
        MonthSelectorView(currentMonth: .constant(Date())) {
            print("Month changed")
        }
        .padding()

        MonthSelectorView(
            currentMonth: .constant(
                Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date())
        ) {
            print("Month changed (3 months ago)")
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
