// AddExpenseSheet.swift
// Add new expense form
//
// Diseño (#65): lo obligatorio cabe en una pantalla sin desplegar nada.
//
// De las seis secciones que tenía, solo dos son obligatorias —importe y
// categoría— y la categoría casi nunca hay que tocarla: escribir el nombre la
// deduce sola desde lo aprendido, el historial o las palabras clave. El
// problema era que esa deducción ocurría en una fila plegada al fondo, así que
// el usuario bajaba a comprobarla igualmente y el trabajo del parser no se veía.
//
// Ahora importe, nombre y categoría van juntos arriba; la categoría deducida se
// enseña resuelta y se cambia en un toque desde los chips, sin salir de la
// pantalla. Fecha, método de pago y notas bajan a "Más detalles", que muestra en
// su cabecera lo que lleva dentro para no tener que abrirlo a comprobarlo.

import SwiftUI


enum AddExpField: Hashable {
    case amount, name, notes
    /// Campos del modo regalo, uno por deudor (#37).
    case debtorName(String)
    case debtorAmount(String)
}

struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddExpenseViewModel()
    @FocusState private var focused: AddExpField?
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                AddExpEssentialsSection(viewModel: viewModel, focused: $focused)
                AddExpCategorySection(viewModel: viewModel)
                AddExpDetailsSection(viewModel: viewModel, focused: $focused)
                GiftModeSection(
                    isShared: $viewModel.isShared,
                    debtors: $viewModel.debtors,
                    totalAmount: viewModel.amount ?? 0,
                    focused: $focused
                )
            }
            .scrollDismissesKeyboard(.interactively)
            .trackScreen("anadir_gasto")
            .navigationTitle("Nuevo Gasto")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.warmup()
                // Foco inicial en importe
                if focused == nil { focused = .amount }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    AddExpSaveToolbarButton(viewModel: viewModel, onSave: onSave, dismiss: dismiss)
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Hecho") { focused = nil }
                            .fontWeight(.semibold)
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Error desconocido")
            }
        }
    }
}

// MARK: - Sections (structs separadas para que @Observable solo re-renderice
// las secciones cuyas propiedades cambian — evita re-render global al teclear)

/// Importe y descripción, los dos campos que hay que escribir sí o sí.
/// Van juntos porque se rellenan seguidos y porque el nombre es lo que dispara
/// la categorización: separarlos escondía esa relación.
private struct AddExpEssentialsSection: View {
    @Bindable var viewModel: AddExpenseViewModel
    var focused: FocusState<AddExpField?>.Binding

    var body: some View {
        Section {
            HStack(alignment: .center) {
                Text("€")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                TextField("0.00", text: $viewModel.amountText)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    // Responsive: expresiones largas ("1,50 + 2 × 3") encogen para caber
                    // en pantallas pequeñas (iPhone SE) en vez de cortarse.
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .focused(focused, equals: .amount)
                    .submitLabel(.next)
                    .accessibilityLabel("Cantidad del gasto")
            }
            .padding(.vertical, Spacing.sm)

            // Total en vivo en su PROPIA línea → nunca compite por el ancho ni se corta.
            if viewModel.amountIsExpression {
                HStack(spacing: 6) {
                    Image(systemName: "equal.circle.fill")
                        .foregroundStyle(Color.clarityPrimary)
                    Text(viewModel.amount.map { Formatters.currency($0) } ?? "—")
                        .fontWeight(.bold)
                        .foregroundStyle(viewModel.amount == nil ? .secondary : Color.clarityPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .font(.headline)
            }

            TextField("¿En qué gastaste?", text: $viewModel.name)
                .font(.clarityBody)
                .focused(focused, equals: .name)
                .submitLabel(.done)
                .onSubmit { focused.wrappedValue = nil }
                .accessibilityLabel("Descripción del gasto")
                .onChange(of: viewModel.name) { _, newValue in
                    viewModel.onNameChange(newValue)
                }

            // Operadores para combinar importes en un mismo gasto (una fanta y unas patatas).
            // El teclado numérico no los tiene → estos botones los insertan. Solo aparecen
            // con el importe enfocado: el resto del tiempo ocupaban sitio sin poder usarse.
            if focused.wrappedValue == .amount {
                HStack(spacing: 8) {
                    operatorButton("+", icon: "plus")
                    operatorButton("-", icon: "minus")
                    operatorButton("×", icon: "multiply")
                    operatorButton("÷", icon: "divide")
                    Spacer(minLength: 0)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }
        } footer: {
            if focused.wrappedValue == .amount {
                Text("¿Varias cosas en un ticket? Escribe un importe, pulsa un operador y añade el siguiente.")
            }
        }
    }

    /// Botón de operador (icono compacto) que lo inserta en el importe y mantiene el foco.
    private func operatorButton(_ symbol: String, icon: String) -> some View {
        Button {
            viewModel.appendAmountOperator(symbol)
            focused.wrappedValue = .amount
        } label: {
            Image(systemName: icon)
                .frame(minWidth: 24, minHeight: 20)
        }
        .accessibilityLabel(operatorLabel(symbol))
    }

    private func operatorLabel(_ symbol: String) -> String {
        switch symbol {
        case "+": return "Sumar"
        case "-": return "Restar"
        case "×": return "Multiplicar"
        case "÷": return "Dividir"
        default: return symbol
        }
    }
}

/// Categoría: se enseña ya resuelta y se cambia sin salir de la pantalla.
///
/// Antes era un `NavigationLink` a otra pantalla: tres toques para algo que el
/// parser suele acertar solo. Los chips ponen las categorías del usuario a un
/// toque, y el enlace de siempre sigue disponible en cuanto hay una elegida,
/// para subcategorías y para quien tenga muchas.
private struct AddExpCategorySection: View {
    @Bindable var viewModel: AddExpenseViewModel
    @State private var userData = UserDataManager.shared

    var body: some View {
        Section {
            if viewModel.category.isEmpty {
                categoryChips
            } else {
                chosenCategoryRow
            }
        } header: {
            Text("Categoría")
        }
    }

    /// Las categorías del usuario en horizontal. Un toque y queda elegida.
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(userData.categories) { category in
                    Button {
                        viewModel.category = category.name
                        viewModel.categoryPickedByUser(category.name)
                        HapticManager.shared.selection()
                    } label: {
                        Text(category.name)
                            .font(.subheadline)
                            .lineLimit(1)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(Color.clarityPrimary)
                }
            }
            .padding(.vertical, Spacing.xxs)
        }
        .scrollClipDisabled()
    }

    /// Ya hay categoría: se enseña con su subcategoría y se entra a cambiarla.
    /// La chispa marca que la puso la app y no el usuario, así se sabe de un
    /// vistazo si conviene revisarla.
    private var chosenCategoryRow: some View {
        NavigationLink {
            CategoryPickerView(
                selectedCategory: $viewModel.category,
                selectedSubcategory: $viewModel.subcategory
            )
            .onAppear {
                viewModel.wasAutoCategorized = false
            }
            .onChange(of: viewModel.category) { _, newValue in
                viewModel.categoryPickedByUser(newValue)
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(viewModel.category)
                    .foregroundStyle(.primary)

                if viewModel.wasAutoCategorized {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Categoría deducida automáticamente")
                }

                Spacer()

                if let sub = viewModel.subcategory {
                    Text(sub)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// Todo lo que tiene un valor por defecto razonable: hoy, tarjeta y sin notas.
/// Plegado, pero con el resumen en la cabecera para no tener que abrirlo solo a
/// comprobar que la fecha es la de hoy.
private struct AddExpDetailsSection: View {
    @Bindable var viewModel: AddExpenseViewModel
    var focused: FocusState<AddExpField?>.Binding
    @State private var expanded = false

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $expanded) {
                DatePicker(
                    "Fecha",
                    selection: $viewModel.date,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .tint(Color.clarityPrimary)
                .accessibilityLabel("Fecha del gasto")

                // Solo los métodos comunes (la gente usa 4-5). Gasto nuevo → no hay valor legacy.
                Picker("Método de pago", selection: $viewModel.paymentMethod) {
                    ForEach(PaymentMethod.pickerOptions) { method in
                        Label(method.rawValue, systemImage: method.icon)
                            .tag(method)
                    }
                }
                .pickerStyle(.navigationLink)

                TextField("Notas", text: $viewModel.notes, axis: .vertical)
                    .focused(focused, equals: .notes)
                    .lineLimit(3...6)
            } label: {
                HStack {
                    Text("Más detalles")
                    Spacer()
                    if !expanded {
                        Text(resumen)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    /// Lo que lleva dentro, en una línea: "Hoy · Tarjeta".
    private var resumen: String {
        var partes: [String] = [fechaCorta, viewModel.paymentMethod.rawValue]
        if !viewModel.notes.isEmpty { partes.append("nota") }
        return partes.joined(separator: " · ")
    }

    private var fechaCorta: String {
        let cal = Calendar.current
        if cal.isDateInToday(viewModel.date) { return "Hoy" }
        if cal.isDateInYesterday(viewModel.date) { return "Ayer" }
        // Mismo camino que usa `save()` para la fecha del gasto, así que lo que
        // se lee aquí es exactamente lo que se va a guardar.
        return Formatters.shortDisplay(Formatters.localDayString(from: viewModel.date))
    }
}

private struct AddExpSaveToolbarButton: View {
    @Bindable var viewModel: AddExpenseViewModel
    let onSave: () -> Void
    let dismiss: DismissAction

    var body: some View {
        Button("Guardar") {
            Task {
                await viewModel.save()
                guard !viewModel.showError else { return }
                UserDataManager.shared.completeOnboarding()
                onSave()
                dismiss()
            }
        }
        .fontWeight(.semibold)
        .disabled(!viewModel.isValid)
    }
}

#Preview {
    AddExpenseSheet(onSave: {})
}
