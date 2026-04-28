// MonthSelectorView.swift
// Compact month navigation control with prev/next arrows and month picker

import SwiftUI

struct MonthSelectorView: View {
    @Binding var currentMonth: Date
    let onMonthChanged: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter
    }

    var body: some View {
        HStack(spacing: 0) {
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
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(uiColor: .tertiarySystemFill), in: Circle())
            }

            Spacer()

            // Mes Actual (tap para month picker)
            Menu {
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
                VStack(spacing: 1) {
                    Text(monthFormatter.string(from: currentMonth).capitalized)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)

                    if isCurrentMonth {
                        Text("mes actual")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Botón Mes Siguiente
            Button {
                if let nextMonth = Calendar.current.date(
                    byAdding: .month, value: 1, to: currentMonth),
                    nextMonth <= Date()
                {
                    currentMonth = nextMonth
                    onMonthChanged()
                }
                HapticManager.shared.selection()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canGoForward ? .primary : .tertiary)
                    .frame(width: 36, height: 36)
                    .background(
                        canGoForward
                            ? Color(uiColor: .tertiarySystemFill)
                            : Color.clear,
                        in: Circle()
                    )
            }
            .disabled(!canGoForward)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.black.opacity(0.08),
                    lineWidth: 1
                )
        )
        .shadow(
            color: colorScheme == .dark ? .clear : .black.opacity(0.06),
            radius: 4, x: 0, y: 2
        )
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
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
        MonthSelectorView(currentMonth: .constant(Date())) {}
            .padding()

        MonthSelectorView(
            currentMonth: .constant(
                Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date())
        ) {}
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}
