// MainTabView.swift
// Main tab navigation with native iOS TabView and center add button

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showAddExpense = false
    @State private var showVoiceInput = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Native TabView with 5 tabs (center one is dummy for spacing)
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Image(systemName: "tablecells")
                        Text("Tabla")
                    }
                    .tag(0)
                
                ChartsView()
                    .tabItem {
                        Image(systemName: "chart.pie.fill")
                        Text("Gráfico")
                    }
                    .tag(1)
                
                // Dummy center tab (hidden by the floating button)
                Color.clear
                    .tabItem {
                        Text(" ")
                    }
                    .tag(2)
                
                AIAssistantView()
                    .tabItem {
                        Image(systemName: "sparkles")
                        Text("Asistente")
                    }
                    .tag(3)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("Ajustes")
                    }
                    .tag(4)
            }
            .tint(Color.clarityPrimary)
            
            // Floating center "+" button (over the center tab)
            Button {
                showAddExpense = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.brandGradient)
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.clarityPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -26)
            
            // Floating mic button (bottom right, above tab bar)
            FloatingMicButton {
                showVoiceInput = true
            }
            .padding(.trailing, Spacing.md)
            .padding(.bottom, 100)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet {
                // Refresh after adding
            }
        }
        .sheet(isPresented: $showVoiceInput) {
            VoiceInputSheet()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Intercept center tab selection and show add sheet instead
            if newValue == 2 {
                selectedTab = oldValue
                showAddExpense = true
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Voice Input Sheet
struct VoiceInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechManager = SpeechRecognitionManager()
    @State private var pulse = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                Spacer()
                
                // Mic Button with Pulse Animation
                ZStack {
                    if speechManager.isRecording {
                        Circle()
                            .fill(Color.clarityPrimary.opacity(0.3))
                            .frame(width: 140, height: 140)
                            .scaleEffect(pulse ? 1.2 : 1.0)
                            .opacity(pulse ? 0.0 : 1.0)
                            .onAppear {
                                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                                    pulse = true
                                }
                            }
                    }
                    
                    Button {
                        toggleRecording()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(speechManager.isRecording ? Color.red : Color.clarityPrimary.opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 32))
                                .foregroundColor(speechManager.isRecording ? .white : .clarityPrimary)
                        }
                    }
                }
                
                // Status Text
                Text(speechManager.isRecording ? "Escuchando..." : "Toca para hablar")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                // Transcription
                if !speechManager.transcription.isEmpty {
                    ScrollView {
                        Text(speechManager.transcription)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.bgCard)
                            .cornerRadius(12)
                    }
                    .frame(maxHeight: 200)
                    .padding(.horizontal)
                } else {
                    Text("Por ejemplo: \"Café en Starbucks 4 euros\"")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                if let error = speechManager.error {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.top)
                }
                
                Spacer()
                
                // Action Buttons
                if !speechManager.transcription.isEmpty && !speechManager.isRecording {
                    Button {
                        // TODO: Send to AI for processing
                        dismiss()
                    } label: {
                        Text("Procesar Gasto")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.brandGradient)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.bgPrimary)
            .navigationTitle("Entrada por Voz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        speechManager.stopRecording()
                        dismiss()
                    }
                }
            }
            .onAppear {
                try? speechManager.startRecording()
            }
            .onDisappear {
                speechManager.stopRecording()
            }
        }
    }
    
    private func toggleRecording() {
        if speechManager.isRecording {
            speechManager.stopRecording()
        } else {
            try? speechManager.startRecording()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
