//
//  IncomeInputView.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-22.
//

import SwiftUI

struct IncomeInputView: View {
    @Binding var income: Double
    var currency: String = "€"
    
    // UI Local State
    @State private var isDragging = false
    @State private var showEditSheet = false
    @State private var tempIncome: String = ""
    
    // Config
    private let maxIncome: Double = 5000 // Visual Max for tank
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Energía Mensual") // Gamified term for "Income"
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                
                Button {
                    tempIncome = String(format: "%.0f", income)
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.clarityPrimary)
                }
            }
            .padding(.horizontal)
            
            // The Energy Tank
            ZStack(alignment: .bottom) {
                // Background Tank
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(uiColor: .systemGray6))
                    .frame(height: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.clarityPrimary.opacity(0.1), lineWidth: 2)
                    )
                
                // Liquid Fill
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [Color.clarityPrimary, Color.clarityPrimary.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: (geo.size.height * CGFloat(min(income / maxIncome, 1.0))))
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: income)
                        
                        // Bubbles/Particles (Optional Deco)
                        if income > 0 {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 10, height: 10)
                                .offset(x: 20, y: -40)
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 20, height: 20)
                                .offset(x: -30, y: -20)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .frame(height: 180)
                
                // Value Overlay
                VStack {
                    Text(Formatters.currency(income))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    
                    Text("Disponible")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.bottom, 60)
            }
            .overlay(
                // Interactive Slider Overlay
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.white.opacity(0.001)) // Invisible touch area
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    let percentage = 1.0 - (value.location.y / geo.size.height)
                                    let newIncome = max(0, percentage * maxIncome)
                                    // Snap to nearest 50
                                    income = round(newIncome / 50) * 50
                                    
                                    // Haptic Feedback
                                    if Int(income) % 100 == 0 {
                                        HapticManager.shared.selection()
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    HapticManager.shared.playSoftImpact()
                                }
                        )
                }
            )
            .padding(.horizontal)
            
            // Helper Text
            Text(incomeTip)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .animation(.default, value: income)
        }
        .padding(.vertical)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .sheet(isPresented: $showEditSheet) {
            editSheet
        }
    }
    
    // MARK: - Subviews
    
    private var editSheet: some View {
        NavigationStack {
            Form {
                Section("Ajuste Manual") {
                    TextField("Cantidad", text: $tempIncome)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                }
            }
            .navigationTitle("Ajustar Energía")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showEditSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if let value = Double(tempIncome) {
                            income = value
                            HapticManager.shared.playSuccess()
                        }
                        showEditSheet = false
                    }
                }
            }
        }
        .presentationDetents([.height(250)])
    }
    
    private var incomeTip: String {
        if income < 1000 {
            return "🔋 Modo Ahorro: Prioriza lo esencial."
        } else if income < 2500 {
            return "⚡ Energía Estable: Buen momento para llenar huchas."
        } else {
            return "🚀 ¡A tope de energía! ¿Invertimos en sueños?"
        }
    }
}
