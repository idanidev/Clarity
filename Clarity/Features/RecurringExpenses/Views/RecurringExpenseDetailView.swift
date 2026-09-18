// RecurringExpenseDetailView.swift
// Detail view for recurring expenses with actions

import SwiftUI

private enum EditRecurringField: Hashable {
    case amount, name
}

struct RecurringExpenseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let expense: RecurringExpense
    let onUpdate: () -> Void
    
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var isProcessing = false
    @State private var showAllCharges = false
    
    private var categoryColor: Color {
        UserDataManager.shared.color(for: expense.category)
    }

    /// Cargos reales generados por esta regla, más recientes primero.
    /// Match por recurringId + fallback por nombre (cargos antiguos creados
    /// antes de que se enlazara recurringId no lo tienen).
    private var chargeHistory: [Expense] {
        let ruleId = expense.id ?? ""
        return UserDataManager.shared.expenses
            .filter {
                (!ruleId.isEmpty && $0.recurringId == ruleId)
                    || (($0.isRecurring ?? $0.recurring ?? false) && $0.name == expense.name)
            }
            .sorted { $0.date > $1.date }
    }
    
    private var emoji: String {
        // Use saved icon, fallback to extracting from category or default
        if let icon = expense.icon, !icon.isEmpty {
            return icon
        }
        let components = expense.category.components(separatedBy: " ")
        return components.count > 1 ? components.last ?? "💰" : "💰"
    }
    
    var body: some View {
        Form {
            // Cabecera: la tarjeta de la regla en la lista, en grande.
            Section {
                TarjetaDetalleRecurrente(expense: expense, emoji: emoji, color: categoryColor)
                    .filaTarjetaClarity(arriba: 0, abajo: 0, lados: 0)
            }
            
            // Details
            Section("Información") {
                LabeledContent("Categoría", value: expense.category)
                
                if let subcategory = expense.subcategory {
                    LabeledContent("Subcategoría", value: subcategory)
                }
                
                LabeledContent {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text(expense.frequency.displayName)
                    }
                } label: {
                    Text("Frecuencia")
                }
                
                LabeledContent {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text("Día \(expense.dayOfMonth)")
                    }
                } label: {
                    Text("Día del cargo")
                }
                
                LabeledContent("Método de pago", value: expense.paymentMethod)

                if let fin = expense.endDate {
                    LabeledContent("Final") {
                        if let p = RecurringScheduler.plazos(de: expense, hoy: Date()) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Plazo \(min(p.hechos, p.total)) de \(p.total)").fontWeight(.medium)
                                Text("último \(Formatters.displayDate(fin))").font(.caption).foregroundStyle(Color.textSecondary)
                            }
                        } else {
                            Text(Formatters.displayDate(fin))
                        }
                    }
                }
            }
            
            // Actions — arriba, antes del historial (acceso rápido)
            Section {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Editar", systemImage: "pencil")
                }

                Button {
                    // Acción directa + toast (patrón de la app). Dialogs solo
                    // para acciones destructivas — esto es reversible.
                    Task { await createCharge() }
                } label: {
                    Label("Crear cargo ahora", systemImage: "plus.circle")
                }
                .disabled(isProcessing)

                Button {
                    Task {
                        await toggleActive()
                    }
                } label: {
                    Label(
                        expense.active ? "Pausar" : "Reanudar",
                        systemImage: expense.active ? "pause.circle" : "play.circle"
                    )
                    .foregroundStyle(expense.active ? Color.warning : Color.success)
                }
                .disabled(isProcessing)
            }

            // History — gastos REALES generados por esta regla.
            // Solo el último visible; el resto tras un desplegable.
            Section("Historial") {
                if chargeHistory.isEmpty {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                        Text("Aún no se ha creado ningún cargo")
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                } else {
                    if let last = chargeHistory.first {
                        LabeledContent {
                            Text(Formatters.currency(last.amount))
                                .monospacedDigit()
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        } label: {
                            Label(Formatters.displayDate(last.date), systemImage: "checkmark.circle")
                                .foregroundStyle(Color.success)
                        }
                    }

                    if chargeHistory.count > 1 {
                        DisclosureGroup(isExpanded: $showAllCharges) {
                            ForEach(chargeHistory.dropFirst(), id: \.stableId) { charge in
                                LabeledContent {
                                    Text(Formatters.currency(charge.amount))
                                        .monospacedDigit()
                                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                                } label: {
                                    Label(Formatters.displayDate(charge.date), systemImage: "checkmark.circle")
                                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                                }
                            }
                        } label: {
                            Text("Ver anteriores (\(chargeHistory.count - 1))")
                                .font(.subheadline)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }
                    }
                }
            }

            // Delete
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Eliminar Gasto Recurrente", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text("Esta acción no se puede deshacer.")
                    .font(.caption2)
            }
        }
        .fondoClarity()
        .navigationTitle(expense.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditSheet) {
            EditRecurringExpenseSheet(expense: expense) {
                onUpdate()
            }
        }
        .confirmationDialog(
            "¿Eliminar \"\(expense.name)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                Task {
                    await deleteExpense()
                }
            }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
    
    private func toggleActive() async {
        guard let id = expense.id else { return }
        isProcessing = true
        
        do {
            try await DependencyContainer.shared.recurringExpenseRepository.toggleActive(id: id, active: !expense.active)
            HapticManager.shared.notification(.success)
            onUpdate()
            dismiss()
        } catch {
            HapticManager.shared.notification(.error)
            isProcessing = false
        }
    }
    
    private func createCharge() async {
        isProcessing = true
        defer { isProcessing = false }

        let today = Formatters.isoString(from: Date())
        let currentMonth = String(today.prefix(7))  // YYYY-MM
        let ruleId = expense.id ?? ""

        // Dedupe: ¿ya hay un cargo de esta regla este mes? Antes creaba siempre
        // → duplicados + decía "Cargo creado" aunque ya estuviera (falso positivo).
        let alreadyExists = UserDataManager.shared.expenses.contains {
            !ruleId.isEmpty && $0.recurringId == ruleId && $0.date.hasPrefix(currentMonth)
        }
        guard !alreadyExists else {
            HapticManager.shared.notification(.warning)
            FeedbackManager.shared.show(
                .info,
                title: "Ya existe el cargo de este mes",
                message: "\(expense.name) ya tiene un cargo en \(Formatters.monthYear(from: Date()))."
            )
            return
        }

        // Mismo id determinista que el cargo automático del mes: si el automático
        // corre después, sobrescribe este doc (idempotente) en vez de duplicarlo.
        let newExpense = Expense(
            id: ruleId.isEmpty ? nil : RecurringScheduler.chargeDocumentId(ruleId: ruleId, month: currentMonth),
            amount: expense.amount,
            name: expense.name,
            category: expense.category,
            subcategory: expense.subcategory,
            date: today,
            paymentMethod: expense.paymentMethod,
            notes: "Cargo manual de gasto recurrente",
            isRecurring: true,
            recurringId: expense.id  // enlazar → aparece en historial + dedupe futuro
        )

        do {
            _ = try await DependencyContainer.shared.expenseRepository.addExpense(newExpense)
            HapticManager.shared.notification(.success)
            NotificationCenter.default.post(name: .expenseDidChange, object: nil)
            FeedbackManager.shared.show(
                .success,
                title: "Cargo creado",
                message: "\(expense.name) — \(Formatters.currency(expense.amount)) añadido a hoy"
            )
            dismiss()
        } catch {
            HapticManager.shared.notification(.error)
            FeedbackManager.shared.show(
                .error,
                title: "Error al crear el cargo",
                message: error.safeUserMessage
            )
        }
    }
    
    private func deleteExpense() async {
        guard let id = expense.id else { return }
        
        do {
            try await DependencyContainer.shared.recurringExpenseRepository.delete(id: id)
            HapticManager.shared.notification(.success)
            onUpdate()
            dismiss()
        } catch {
            HapticManager.shared.notification(.error)
        }
    }
}

// MARK: - Cabecera

/// La regla en grande, continuación de su tarjeta en la lista: icono, cifra,
/// cada cuánto se cobra, el próximo cargo y, si va a plazos, cómo van.
private struct TarjetaDetalleRecurrente: View {
    let expense: RecurringExpense
    let emoji: String
    let color: Color

    var body: some View {
        let plazos = RecurringScheduler.plazos(de: expense, hoy: Date())

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                CirculoIconoClarity(icono: emoji, color: color, tamano: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text(expense.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Text(detalle)
                        .font(.subheadline)
                        .foregroundStyle(expense.isValid ? Color.textSecondary : Color.error)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                estado
            }

            Text(Formatters.currency(expense.amount))
                .estiloCifraClarity()
                .padding(.top, 16)

            if expense.frequency != .monthly {
                Text("≈ \(Formatters.currency(alMes))/mes")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }

            if let proximo = proximoCargo {
                HStack {
                    Text("Próximo cargo")
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(cuando(proximo))
                        .fontWeight(.medium)
                }
                .font(.footnote)
                .padding(.top, 14)
            }

            if let plazos {
                let hechos = min(plazos.hechos, plazos.total)

                BarraProgresoClarity(
                    progreso: Double(hechos) / Double(max(plazos.total, 1)),
                    color: color
                )
                .padding(.top, 16)

                HStack {
                    Text("Plazo \(hechos) de \(plazos.total)")
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text("quedan \(Formatters.currency(Double(plazos.total - hechos) * expense.amount))")
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
                .font(.footnote)
                .padding(.top, 8)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: CornerRadius.xlarge)
        .accessibilityElement(children: .combine)
    }

    private var estado: some View {
        HStack(spacing: 4) {
            Image(systemName: expense.active ? "checkmark.circle.fill" : "pause.circle.fill")
            Text(expense.active ? "Activo" : "Pausado")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(expense.active ? Color.success : Color.warning)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background((expense.active ? Color.success : Color.warning).opacity(0.16), in: Capsule())
    }

    /// Frecuencia y día, con los mismos textos que la fila de la lista.
    private var detalle: String {
        if expense.dayOfMonth == 0 { return "Falta el día de cobro" }
        if expense.frequency.needsMonthSelection {
            guard expense.billingMonth > 0 else { return "Falta el mes de cobro" }
            return "\(expense.frequency.displayName) · \(expense.dayOfMonth) \(Formatters.shortMonthName(expense.billingMonth).lowercased())"
        }
        return "\(expense.frequency.displayName) · día \(expense.dayOfMonth)"
    }

    /// Lo que cuesta repartido por meses: un anual de 120 € son 10 €.
    private var alMes: Double {
        expense.amount / Double(RecurringScheduler.mesesEntreCargos(expense.frequency))
    }

    /// El siguiente cargo de hoy en adelante, sin pasar de la fecha fin. Una
    /// regla pausada o incompleta no tiene próximo cargo que enseñar.
    private var proximoCargo: Date? {
        guard expense.active, expense.isValid else { return nil }
        let hoy = Date()
        let hoyTexto = Formatters.localDayString(from: hoy)
        // Hay reglas guardadas con `endDate` vacío: eso es "sin fin", no un tope.
        let fin: String? = expense.endDate.flatMap { $0.count >= 10 ? String($0.prefix(10)) : nil }
        let siguiente: String? = RecurringScheduler.fechasDeCargo(
            frecuencia: expense.frequency, dia: expense.dayOfMonth, billingMonth: expense.billingMonth,
            desde: hoy, hasta: fin, limite: 3
        )
        .first(where: { $0 >= hoyTexto })
        return siguiente.flatMap { Self.fechaLocal($0) }
    }

    private func cuando(_ fecha: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(fecha) { return "Hoy" }
        if cal.isDateInTomorrow(fecha) { return "Mañana" }
        return fecha.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    /// "yyyy-MM-dd" como medianoche local. `Formatters.date(from:)` da
    /// medianoche UTC, que al oeste de Greenwich cae en el día anterior.
    private static func fechaLocal(_ texto: String) -> Date? {
        let partes = texto.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard partes.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: partes[0], month: partes[1], day: partes[2]))
    }
}

// MARK: - Edit Sheet (reuses AddRecurringExpenseSheet pattern)

struct EditRecurringExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: EditRecurringField?
    let expense: RecurringExpense
    let onSuccess: () -> Void
    
    @State private var amountString: String
    @State private var name: String
    @State private var selectedCategory: String
    @State private var selectedSubcategory: String?
    @State private var paymentMethod: String
    @State private var frequency: RecurringFrequency
    @State private var dayOfMonth: Int
    @State private var billingMonth: Int
    @State private var selectedIcon: String
    @State private var showEmojiPicker = false
    @State private var isSaving = false
    @State private var fin: FinRecurrente
    @State private var fechaFin: Date
    @State private var numeroPlazos: Int
    
    private let monthNames = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                              "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
    
    private var categories: [Category] { UserDataManager.shared.categories }
    private var paymentMethods: [String] { UserDataManager.shared.paymentMethods }
    
    init(expense: RecurringExpense, onSuccess: @escaping () -> Void) {
        self.expense = expense
        self.onSuccess = onSuccess
        _amountString = State(initialValue: String(format: "%.2f", expense.amount))
        _name = State(initialValue: expense.name)
        _selectedCategory = State(initialValue: expense.category)
        _selectedSubcategory = State(initialValue: expense.subcategory)
        _paymentMethod = State(initialValue: expense.paymentMethod)
        _frequency = State(initialValue: expense.frequency)
        _dayOfMonth = State(initialValue: expense.dayOfMonth)
        _billingMonth = State(initialValue: expense.billingMonth > 0 ? expense.billingMonth : Calendar.current.component(.month, from: Date()))
        _selectedIcon = State(initialValue: expense.icon ?? "💰")
        // Con fecha fin se abre en "Fecha": los plazos se calculan al guardar y
        // lo que queda en la regla es el último día de cobro.
        let fechaGuardada = expense.endDate.flatMap { Formatters.date(from: $0) }
        _fin = State(initialValue: fechaGuardada == nil ? .nunca : .fecha)
        _fechaFin = State(initialValue: fechaGuardada ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
        _numeroPlazos = State(initialValue: RecurringScheduler.plazos(de: expense, hoy: Date())?.total ?? 12)
    }

    private var inicioPlan: Date { expense.startDate.flatMap { Formatters.date(from: $0) } ?? Date() }
    
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
                        .buttonStyle(.plain)
                    }
                }
                
                Section {
                    TextField("0.00", text: $amountString)
                        .keyboardType(.decimalPad)
                        .scaledFont(size: 32, weight: .bold, design: .rounded)
                        .focused($focused, equals: .amount)

                    TextField("Nombre", text: $name)
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
                        billingMonth: billingMonth, desde: inicioPlan)
                )
            }
            .fondoClarity()
            .navigationTitle("Editar Recurrente")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
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
            .fullScreenCover(isPresented: $showEmojiPicker) {
                EmojiPickerView(selectedEmoji: $selectedIcon)
            }
        }
    }
    
    private func saveExpense() {
        guard let amount = Double(amountString.replacingOccurrences(of: ",", with: ".")) else {
            return
        }
        guard let id = expense.id else {
            return
        }

        isSaving = true
        
        let updated = RecurringExpense(
            id: id,
            amount: amount,
            name: name,
            category: selectedCategory,
            subcategory: selectedSubcategory,
            paymentMethod: paymentMethod,
            frequency: frequency,
            dayOfMonth: dayOfMonth,
            billingMonth: billingMonth,
            active: expense.active,
            icon: selectedIcon,
            startDate: expense.startDate,
            endDate: {
                switch fin {
                case .nunca: return nil
                case .fecha: return Formatters.localDayString(from: fechaFin)
                case .plazos: return RecurringScheduler.fechaFin(plazos: numeroPlazos, frecuencia: frequency, dia: dayOfMonth,
                                                                 billingMonth: billingMonth, desde: inicioPlan)
                }
            }(),
            lastCreated: expense.lastCreated,
            createdAt: expense.createdAt,
            updatedAt: Formatters.isoString(from: Date())
        )
        
        Task {
            do {
                try await DependencyContainer.shared.recurringExpenseRepository.update(updated)
                // Si tras editar (p.ej. cambió el día de cobro) el cobro de este mes
                // ya tocaba, crear el gasto AL MOMENTO (dedupe por mes incluido).
                await LocalRecurringExpenseManager.shared.createCurrentPeriodExpenseIfDue(for: updated)
                await MainActor.run {
                    HapticManager.shared.notification(.success)
                    onSuccess()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
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

#Preview {
    NavigationStack {
        RecurringExpenseDetailView(expense: .sample, onUpdate: {})
    }
}
