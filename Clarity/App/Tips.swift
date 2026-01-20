// Tips.swift
// Definiciones de Tips para el onboarding usando TipKit

import SwiftUI
import TipKit

// MARK: - Add Expense Tip
struct AddExpenseTip: Tip {
    var title: Text {
        Text("Añade tu primer gasto")
            .foregroundStyle(.primary)
    }
    
    var message: Text? {
        Text("Toca el botón + para añadir un gasto manualmente o mantén pulsado para usar el menú rápido.")
            .foregroundStyle(.secondary)
    }
    
    var image: Image? {
        Image(systemName: "plus.circle.fill")
    }
}

// MARK: - Filter Tip
struct FilterTip: Tip {
    var title: Text {
        Text("Filtra tus gastos")
            .foregroundStyle(.primary)
    }
    
    var message: Text? {
        Text("Usa los filtros para ver gastos por categoría, fecha o método de pago.")
            .foregroundStyle(.secondary)
    }
    
    var image: Image? {
        Image(systemName: "line.3.horizontal.decrease.circle")
    }
}
