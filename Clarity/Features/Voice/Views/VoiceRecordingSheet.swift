// VoiceRecordingSheet.swift
// Modal sheet shown while recording voice

import SwiftUI
import Combine

struct VoiceRecordingSheet: View {
    @ObservedObject var speechManager: SpeechRecognitionManager
    @Binding var isPresented: Bool
    
    @State private var currentExampleIndex = 0
    
    private let examples = [
        "💡 \"25 en supermercado\"",
        "💡 \"Cena con amigos 37€\"",
        "💡 \"50 de gasolina\"",
        "💡 \"9.60 en tabaco\"",
        "💡 \"He gastado 12 en café\"",
        "💡 \"18€ en copas\""
    ]
    
    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with status
            HStack {
                Spacer()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 4)
                                .scaleEffect(speechManager.isListening ? 1.5 : 1.0)
                                .opacity(speechManager.isListening ? 0 : 1)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: false), value: speechManager.isListening)
                        )
                    
                    Text("Grabando")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            }
            .padding()
            
            Spacer()
            
            // Title
            Text("🎤 Di tu gasto")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.bottom)
            
            // Audio Wave
            AudioWaveVisualizer(
                audioLevel: speechManager.audioLevel,
                isActive: speechManager.isListening
            )
            .padding(.horizontal)
            .padding(.bottom, 24)
            
            // Transcript area
            VStack(alignment: .leading, spacing: 12) {
                let fullText = (speechManager.transcript + " " + speechManager.interimTranscript).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if fullText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Escuchando...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        // Rotating examples
                        ForEach(0..<examples.count, id: \.self) { index in
                            Text(examples[index])
                                .font(.system(size: 12))
                                .foregroundColor(index == currentExampleIndex ? .purple : .secondary.opacity(0.3))
                                .animation(.easeInOut(duration: 0.3), value: currentExampleIndex)
                        }
                        .onReceive(timer) { _ in
                            currentExampleIndex = (currentExampleIndex + 1) % examples.count
                        }
                    }
                } else {
                    Text(fullText)
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .frame(minHeight: 120)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)
            
            Spacer()
            
            // Stop button
            Button {
                speechManager.stopRecording()
                isPresented = false
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Detener grabación")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(16)
            }
            .padding()
        }
        .background(.ultraThinMaterial)
    }
}
