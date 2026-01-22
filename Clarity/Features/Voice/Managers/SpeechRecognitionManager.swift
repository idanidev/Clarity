// SpeechRecognitionManager.swift
// Native iOS speech recognition with robust audio session handling
// Optimized for co-existence with System Sounds

import Foundation
import Speech
import AVFoundation
import Observation
import OSLog

@Observable
class SpeechRecognitionManager {
    var isListening = false
    var transcript = ""
    var interimTranscript = ""
    var audioLevel: Float = 0.0
    var hasPermission = false
    var lastError: RecognitionError?
    
    // Internal
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    // Safety & Logging
    private var bufferCount: Int = 0
    private let maxBuffers = 800 // Safety limit (~8 seconds)
    private let logger = Logger(subsystem: "com.clarity.app", category: "Voice")
    
    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    }
    
    // MARK: - Pre-warming (Crucial for Speed)
    
    func prepare() {
        Task {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                // .playAndRecord is key here. .duckOthers lowers music instead of stopping it.
                // .defaultToSpeaker ensures we don't go to receiver (earpiece).
                try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                logger.info("🔥 Audio Engine Pre-warmed")
            } catch {
                logger.error("❌ Pre-warming failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() throws {
        logger.info("🎤 Starting recording pipeline...")
        
        // 1. Clean previous state
        cleanupResources()
        transcript = ""
        interimTranscript = ""
        lastError = nil
        bufferCount = 0
        
        // 2. Configure Audio Session (Robust)
        let audioSession = AVAudioSession.sharedInstance()
        do {
                try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("❌ Audio Session Config Failed: \(error.localizedDescription)")
            throw RecognitionError.audioEngineFailure
        }
        
        // 3. Create Request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create request") }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Allow server-side for better accuracy if needed
        
        // 4. Configure Input Node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Safety check for valid format (prevents crash on silent input)
        guard recordingFormat.sampleRate > 0 else {
            logger.error("❌ Invalid Audio Format: Sample rate is 0")
            throw RecognitionError.microphoneUnavailable
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)
            self.extractAudioLevel(from: buffer)
            
            // Memory Safety Limit
            self.bufferCount += 1
            if self.bufferCount > self.maxBuffers {
                self.stopRecording()
            }
        }
        
        // 5. Start Engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            logger.error("❌ Audio Engine Start Failed: \(error.localizedDescription)")
            throw RecognitionError.audioEngineFailure
        }
        
        // 6. Start Task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let bestString = result.bestTranscription.formattedString
                // Update properties on Main Actor through Observation machinery (implicitly)
                DispatchQueue.main.async {
                    if result.isFinal {
                        self.transcript = bestString
                        self.interimTranscript = ""
                        self.logger.info("✅ Final Transcript: \(bestString)")
                    } else {
                        self.interimTranscript = bestString
                    }
                }
            }
            
            if let error = error {
                // Ignore "Success" or "User Cancelled" type errors usually
                if (error as NSError).code != 203 { // 203 is Retry usually, but let's log everything for now
                     self.logger.error("❌ Recognition error: \(error.localizedDescription)")
                }
                
                DispatchQueue.main.async {
                    self.lastError = .unknownError(error)
                }
                // Don't necessarily stop here, let the UI decide, unless it's fatal
            }
        }
        
        isListening = true
        logger.info("✅ Recording active")
    }
    
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            isListening = false
            logger.info("🛑 Recording stopped")
        }
    }
    
    private func cleanupResources() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Always remove tap if it persists, regardless of engine state
        // Wrapped in try-catch logic implicitly by API safety, but direct call is safe
        audioEngine.inputNode.removeTap(onBus: 0)
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }
    
    private func extractAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
            .map { channelDataValue[$0] }
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalizedLevel = max(0, min(1, (avgPower + 50) / 50))
        
        DispatchQueue.main.async {
            self.audioLevel = normalizedLevel
        }
    }
    
    // Permission Helpers
    func checkPermissions() -> Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized && AVAudioApplication.shared.recordPermission == .granted
    }
    
    enum RecognitionError: Error, LocalizedError {
        case audioEngineFailure
        case microphoneUnavailable
        case unknownError(Error)
        
        var errorDescription: String? {
            switch self {
            case .audioEngineFailure: return "Error en el motor de audio"
            case .microphoneUnavailable: return "Micrófono no disponible"
            case .unknownError(let e): return e.localizedDescription
            }
        }
    }
}
