// AddRecurringExpenseSheet.swift
// Form to add a new recurring expense

import SwiftUI

private enum RecurringField: Hashable {
    case amount, name
}

struct AddRecurringExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: RecurringField?
    let onSuccess: () -> Void
    
    private let repository = DependencyContainer.shared.recurringExpenseRepository
    
    @State private var amountString = ""
    @State private var name = ""
    @State private var selectedCategory = ""
    @State private var selectedSubcategory: String? = nil
    @State private var paymentMethod = "Tarjeta"
    @State private var frequency: RecurringFrequency = .monthly
    @State private var dayOfMonth: Int = 1
    @State private var billingMonth: Int = Calendar.current.component(.month, from: Date())  // Current month
    @State private var selectedIcon = "💰"
    @State private var showEmojiPicker = false
    @State private var isSaving = false
    @State private var fin: FinRecurrente = .nunca
    @State private var fechaFin: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var numeroPlazos = 12
    /// «Cancelar» con cambios: pregunta antes de tirarlos (`confirmarDescarte`).
    @State private var preguntarDescarte = false
    /// Foto del formulario al abrir, para saber si el usuario ha cambiado algo.
    @State private var estadoInicial: EstadoFormularioRecurrente?
    
    private let monthNames = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                              "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
    
    // Cached data from singleton
    private var categories: [Category] { UserDataManager.shared.categories }
    private var paymentMethods: [String] { UserDataManager.shared.paymentMethods }
    
    var body: some View {
        NavigationStack {
            Form {
                // Icon section
                Section {
                    HStack {
                        Text("Icono")
                        Spacer()
                        Button {
                            showEmojiPicker = true
                        } label: {
                            // Círculo como en la lista; el emoji sigue siendo
                            // `Text` para que VoiceOver lo lea igual que antes.
                            Text(selectedIcon)
                                .scaledFont(size: 30)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                                .frame(width: 56, height: 56)
                                .background(Color.clarityPrimary.opacity(0.22), in: Circle())
                                .overlay(Circle().strokeBorder(Color.clarityPrimary.opacity(0.5), lineWidth: 0.5))
                        }
                    }
                }
                
                Section {
                    TextField("0.00", text: $amountString)
                        .keyboardType(.decimalPad)
                        .scaledFont(size: 32, weight: .bold, design: .rounded)
                        .focused($focused, equals: .amount)

                    TextField("Nombre (ej. Netflix)", text: $name)
                        .focused($focused, equals: .name)
                        .submitLabel(.done)
                        .onSubmit { focused = nil }
                }
                
                Section {
                    NavigationLink(destination: CategoryPickerView(
                        selectedCategory: $selectedCategory,
                        selectedSubcategory: $selectedSubcategory
                    )) {
                        HStack {
                            Text("Categoría")
                            Spacer()
                            Text(formatCategorySelection())
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    
                    Picker("Método de Pago", selection: $paymentMethod) {
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                }
                
                Section {
                    Picker("Frecuencia", selection: $frequency) {
                        ForEach(RecurringFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    
                    Picker("Día del cargo", selection: $dayOfMonth) {
                        ForEach(1...31, id: \.self) { day in
                            Text("Día \(day)").tag(day)
                        }
                    }
                    
                    // Month picker - only for non-monthly frequencies
                    if frequency.needsMonthSelection {
                        Picker("Mes de cobro", selection: $billingMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(monthNames[month - 1]).tag(month)
                            }
                        }
                    }
                } header: {
                    Text("Programación")
                } footer: {
                    if frequency.needsMonthSelection {
                        Text("Se cobrará el día \(dayOfMonth) de \(monthNames[billingMonth - 1])")
                    } else {
                        Text("Se cobrará el día \(dayOfMonth) de cada mes")
                    }
                }

                SeccionFinRecurrente(
                    fin: $fin, fecha: $fechaFin, plazos: $numeroPlazos,
                    importe: Double(amountString.replacingOccurrences(of: ",", with: ".")) ?? 0,
                    ultimoCargoPlazos: RecurringScheduler.fechaFin(
                        plazos: numeroPlazos, frecuencia: frequency, dia: dayOfMonth,
                        billingMonth: billingMonth, desde: Date())
                )
            }
            .fondoClarity()
            .navigationTitle("Nuevo Recurrente")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BotonCancelarFormulario(
                        preguntando: $preguntarDescarte,
                        hayCambios: hayCambios
                    ) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveExpense()
                    }
                    .disabled(amountString.isEmpty || name.isEmpty || selectedCategory.isEmpty || isSaving)
                    .fontWeight(.semibold)
                }

                // Hasta iOS 26 inclusive. En iOS 27 esta barra de accesorio se
                // descuelga al cambiar de teclado dentro de una hoja, se queda
                // flotando en medio del formulario y se traga los toques; allí el
                // teclado se cierra arrastrando o tocando otro campo. En iOS 26 hace
                // falta: sin ella (2.2.1) el formulario se congelaba en algunos iPhone.
                if #unavailable(iOS 27) {
                    ToolbarItem(placement: .keyboard) {
                        HStack {
                            Spacer()
                            Button("Hecho") { focused = nil }
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerView(selectedEmoji: $selectedIcon)
            }
            // Una sola vez: `onAppear` vuelve a saltar al regresar del selector
            // de categoría, y para entonces la foto ya no sería la del principio.
            .onAppear { if estadoInicial == nil { estadoInicial = estadoActual } }
            .confirmarDescarte(
                preguntando: $preguntarDescarte,
                hayCambios: hayCambios
            ) { dismiss() }
        }
    }

    private var estadoActual: EstadoFormularioRecurrente {
        EstadoFormularioRecurrente(
            importe: amountString, nombre: name, categoria: selectedCategory,
            subcategoria: selectedSubcategory, metodoDePago: paymentMethod,
            frecuencia: frequency, dia: dayOfMonth, mesDeCobro: billingMonth,
            icono: selectedIcon, fin: fin, fechaFin: fechaFin, plazos: numeroPlazos)
    }

    private var hayCambios: Bool {
        guard let estadoInicial else { return false }
        return estadoInicial != estadoActual
    }
    
    private func saveExpense() {
        guard let amount = Double(amountString.replacingOccurrences(of: ",", with: ".")) else { return }
        
        isSaving = true
        
        let newExpense = RecurringExpense(
            id: nil,
            amount: amount,
            name: name,
            category: selectedCategory,
            subcategory: selectedSubcategory,
            paymentMethod: paymentMethod,
            frequency: frequency,
            dayOfMonth: dayOfMonth,
            billingMonth: billingMonth,
            active: true,
            icon: selectedIcon,
            startDate: Formatters.isoString(from: Date()),
            endDate: endDateCalculado,
            lastCreated: nil,
            createdAt: Formatters.isoString(from: Date()),
            updatedAt: Formatters.isoString(from: Date())
        )
        
        Task {
            do {
                let newId = try await repository.add(newExpense)
                // Si el día de cobro de este mes ya pasó (p.ej. hoy 11, cobro el 9),
                // crear el gasto AL MOMENTO — no esperar al chequeo del día siguiente.
                var saved = newExpense
                saved.id = newId
                await LocalRecurringExpenseManager.shared.createCurrentPeriodExpenseIfDue(for: saved)
                HapticManager.shared.notification(.success)
                onSuccess()
                dismiss()
            } catch {
                isSaving = false
            }
        }
    }
    
    private var endDateCalculado: String? {
        switch fin {
        case .nunca: nil
        case .fecha: Formatters.localDayString(from: fechaFin)
        case .plazos: RecurringScheduler.fechaFin(plazos: numeroPlazos, frecuencia: frequency, dia: dayOfMonth,
                                                 billingMonth: billingMonth, desde: Date())
        }
    }

    private func formatCategorySelection() -> String {
        if selectedCategory.isEmpty { return "Requerido" }
        if let sub = selectedSubcategory {
            return "\(selectedCategory) > \(sub)"
        }
        return selectedCategory
    }
}

