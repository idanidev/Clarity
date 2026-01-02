// CustomTabBar.swift
// Custom tab bar with floating center button

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let onAddTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Tab 0: Tabla
            TabBarButton(
                icon: "tablecells",
                title: "Tabla",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }
            
            // Tab 1: Gráfico
            TabBarButton(
                icon: "chart.pie.fill",
                title: "Gráfico",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }
            
            // Center: Add Button
            Button(action: onAddTap) {
                ZStack {
                    Circle()
                        .fill(Color.brandGradient)
                        .frame(width: Spacing.fabSize, height: Spacing.fabSize)
                        .shadow(color: Color.clarityPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -Spacing.fabOffset)
            
            // Tab 2: Asistente IA
            TabBarButton(
                icon: "sparkles",
                title: "IA",
                isSelected: selectedTab == 2
            ) {
                selectedTab = 2
            }
            
            // Tab 3: Presupuestos
            TabBarButton(
                icon: "target",
                title: "Objetivos",
                isSelected: selectedTab == 3
            ) {
                selectedTab = 3
            }
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.top, Spacing.xs)
        .padding(.bottom, 24) // Safe area
        .background(Color.bgSecondary)
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
            .background(
                Group {
                    if isSelected {
                        Color.clarityPrimary
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            )
        }
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        
        VStack {
            Spacer()
            CustomTabBar(selectedTab: .constant(0)) {
                print("Add tapped")
            }
        }
    }
    .preferredColorScheme(.dark)
}
