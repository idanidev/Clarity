// VoiceSettingsPanel.swift
// Settings panel for voice expense feature

import SwiftUI

struct VoiceSettingsPanel: View {
    @Binding var settings: VoiceSettings
    @State private var showStats = false
    @State private var stats = VoiceStats.load()
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "mic.circle.fill")
                    .scaledFont(size: 24)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Entrada por Voz")
                        .scaledFont(size: 18, weight: .semibold)
                    
                    Text("Ajusta cómo se comporta el micrófono")
                        .scaledFont(size: 14)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Settings
            VStack(spacing: 16) {
                // Auto-confirm
                SettingRow(
                    icon: "checkmark.circle.fill",
                    title: "Confirmación automática",
                    description: "Guardar sin mostrar diálogo",
                    isOn: $settings.autoConfirm
                )
                .onChange(of: settings.autoConfirm) { _, _ in
                    settings.save()
                }
                
                Divider()
                
                // Vibration
                SettingRow(
                    icon: "iphone.radiowaves.left.and.right",
                    title: "Vibración",
                    description: "Feedback táctil al detectar y guardar",
                    isOn: $settings.vibration
                )
                .onChange(of: settings.vibration) { _, _ in
                    settings.save()
                }
                
                Divider()
                
                // Suggestions
                SettingRow(
                    icon: "lightbulb.fill",
                    title: "Sugerencias inteligentes",
                    description: "Mostrar ejemplos mientras hablas",
                    isOn: $settings.showSuggestions
                )
                .onChange(of: settings.showSuggestions) { _, _ in
                    settings.save()
                }
                
                Divider()
                
                // Silence timeout
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(.purple)
                        
                        Text("Tiempo de silencio")
                            .scaledFont(size: 16, weight: .medium)

                        Spacer()

                        Text(String(format: "%.1fs", settings.silenceTimeout))
                            .scaledFont(size: 14, weight: .medium)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $settings.silenceTimeout, in: 1...5, step: 0.5)
                        .tint(.purple)
                        .onChange(of: settings.silenceTimeout) { _, _ in
                            settings.save()
                        }
                    
                    Text("Tiempo de silencio para detectar fin de frase")
                        .scaledFont(size: 12)
                        .foregroundColor(.secondary)
                }
            }
            
            // Stats button
            Button {
                showStats.toggle()
                if showStats {
                    stats = VoiceStats.load()
                }
            } label: {
                HStack {
                    Image(systemName: "chart.bar.fill")
                    Text(showStats ? "Ocultar Estadísticas" : "Ver Estadísticas")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(12)
            }
            
            // Stats display
            if showStats {
                VStack(spacing: 12) {
                    Text("📊 Estadísticas de Uso")
                        .scaledFont(size: 16, weight: .semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let lastUsed = stats.lastUsed {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Última vez usado")
                                .scaledFont(size: 12, weight: .medium)
                                .foregroundColor(.secondary)

                            Text("\(lastUsed, style: .date) \(lastUsed, style: .time)")
                                .scaledFont(size: 14)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    HStack(spacing: 12) {
                        StatCard(
                            title: "Total",
                            value: "\(stats.totalUses)",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "Exitosos",
                            value: "\(stats.successfulUses)",
                            color: .green
                        )
                        
                        if stats.failedUses > 0 {
                            StatCard(
                                title: "Fallidos",
                                value: "\(stats.failedUses)",
                                color: .red
                            )
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Supporting Views

struct SettingRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .scaledFont(size: 20)
                .foregroundColor(.purple)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .scaledFont(size: 16, weight: .medium)

                Text(description)
                    .scaledFont(size: 12)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}



#Preview {
    VoiceSettingsPanel(settings: .constant(.default))
        .padding()
}
