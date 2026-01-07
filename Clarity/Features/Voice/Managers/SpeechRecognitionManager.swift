// SpeechRecognitionManager.swift
// Native iOS speech recognition with audio level monitoring

import Foundation
import Speech
import AVFoundation
import Combine
import os.log

class SpeechRecognitionManager: ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var interimTranscript = ""
    @Published var audioLevel: Float = 0.0
    @Published var hasPermission = false
    @Published var lastError: RecognitionError?
    @Published var didStopDueToSilence = false  // Flag for UI to observe
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    // Use DispatchWorkItem instead of Timer for thread safety
    private var silenceWorkItem: DispatchWorkItem?
    private var settings: VoiceSettings
    
    // Buffer management
    private var bufferCount: Int = 0
    private let maxBuffers: Int = 500  // ~5 seconds at 100 buffers/sec
    
    // Retry logic
    private var retryCount = 0
    private let maxRetries = 2
    
    // Logging
    private let logger = Logger(subsystem: "com.clarity.app", category: "Voice")
    
    init(settings: VoiceSettings = .load()) {
        self.settings = settings
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    }
    
    // MARK: - Permission Handling
    
    func requestPermissions() async -> Bool {
        logger.info("🎤 Requesting permissions...")
        
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        // Request microphone permission
        let micStatus = await AVAudioApplication.requestRecordPermission()
        
        let granted = speechStatus && micStatus
        await MainActor.run {
            self.hasPermission = granted
        }
        
        logger.info("🎤 Permissions: speech=\(speechStatus), mic=\(micStatus)")
        return granted
    }
    
    func checkPermissions() -> Bool {
        let speechStatus = SFSpeechRecognizer.authorizationStatus() == .authorized
        let micStatus = AVAudioApplication.shared.recordPermission == .granted
        let granted = speechStatus && micStatus
        hasPermission = granted
        return granted
    }
    
    // MARK: - Recording Control
    
    func startRecording() throws {
        logger.info("🎤 Starting recording...")
        
        // Reset silence flag
        didStopDueToSilence = false
        
        // Cancel any ongoing tasks first
        cleanupResources()
        
        // Reset state
        transcript = ""
        interimTranscript = ""
        lastError = nil
        bufferCount = 0
        
        // Setup audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("❌ Audio session setup failed: \(error.localizedDescription)")
            throw RecognitionError.audioEngineFailure
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw RecognitionError.requestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Get the input node and its output format
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Validate format
        guard recordingFormat.sampleRate > 0 else {
            logger.error("❌ Invalid audio format")
            throw RecognitionError.microphoneUnavailable
        }
        
        // Install tap with the input node's output format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)
            self.extractAudioLevel(from: buffer)
            
            // Memory Safety: Stop if we exceed buffer limit
            self.bufferCount += 1
            if self.bufferCount > self.maxBuffers {
                DispatchQueue.main.async {
                    self.logger.warning("⚠️ Auto-stopping: buffer limit reached")
                    self.stopRecording()
                }
            }
        }
        
        // Prepare and start the audio engine
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            logger.error("❌ Audio engine start failed: \(error.localizedDescription)")
            cleanupResources()
            throw RecognitionError.audioEngineFailure
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let bestTranscription = result.bestTranscription
                
                DispatchQueue.main.async {
                    if result.isFinal {
                        self.transcript = (self.transcript + " " + bestTranscription.formattedString)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        self.interimTranscript = ""
                        self.logger.info("✅ Final transcript: '\(self.transcript)'")
                    } else {
                        self.interimTranscript = bestTranscription.formattedString
                    }
                    
                    // Reset silence timer on speech activity
                    self.resetSilenceTimer()
                }
            }
            
            if let error = error {
                self.logger.error("❌ Recognition error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.lastError = .unknownError(error)
                    self.stopRecording()
                }
            }
        }
        
        isListening = true
        retryCount = 0  // Reset retry count on successful start
        logger.info("✅ Recording started successfully")
    }
    
    func stopRecording() {
        logger.info("🛑 Stopping recording...")
        cleanupResources()
        logger.info("✅ Recording stopped. Transcript: '\(self.transcript)'")
    }
    
    // MARK: - Cleanup
    
    private func cleanupResources() {
        // 1. Cancel silence timer first
        silenceWorkItem?.cancel()
        silenceWorkItem = nil
        
        // 2. Stop recognition
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // 3. Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // 4. Deactivate audio session
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        
        // 5. Reset state
        isListening = false
        audioLevel = 0.0
        bufferCount = 0
    }
    
    // MARK: - Retry Logic
    
    func startRecordingWithRetry() async throws {
        do {
            try startRecording()
            retryCount = 0
        } catch {
            lastError = .unknownError(error)
            
            if retryCount < maxRetries {
                retryCount += 1
                logger.warning("⚠️ Retry \(self.retryCount)/\(self.maxRetries)")
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                try await startRecordingWithRetry()
            } else {
                logger.error("❌ Max retries reached")
                throw error
            }
        }
    }
    
    // MARK: - Silence Detection (Thread-safe with DispatchWorkItem)
    
    private func resetSilenceTimer() {
        // Cancel previous work item
        silenceWorkItem?.cancel()
        
        // Create new work item
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.logger.info("🔇 Silence detected, stopping...")
            DispatchQueue.main.async {
                self.didStopDueToSilence = true
            }
            self.stopRecording()
        }
        
        silenceWorkItem = workItem
        
        // Schedule on main queue
        DispatchQueue.main.asyncAfter(
            deadline: .now() + settings.silenceTimeout,
            execute: workItem
        )
    }
    
    // MARK: - Audio Level Extraction
    
    private func extractAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
            .map { channelDataValue[$0] }
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        
        // Normalize to 0-1 range (assuming -50 to 0 dB range)
        let normalizedLevel = max(0, min(1, (avgPower + 50) / 50))
        
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = normalizedLevel
        }
    }
    
    // MARK: - Update Settings
    
    func updateSettings(_ newSettings: VoiceSettings) {
        self.settings = newSettings
    }
    
    // MARK: - Error Types
    
    enum RecognitionError: LocalizedError {
        case requestCreationFailed
        case audioEngineFailure
        case microphoneUnavailable
        case recognitionTimeout
        case permissionDenied
        case unknownError(Error)
        
        var errorDescription: String? {
            switch self {
            case .requestCreationFailed:
                return "No se pudo crear la solicitud de reconocimiento."
            case .audioEngineFailure:
                return "No se pudo iniciar el micrófono. Intenta de nuevo."
            case .microphoneUnavailable:
                return "Micrófono no disponible. Verifica los permisos."
            case .recognitionTimeout:
                return "Tiempo de espera agotado. Intenta hablar más claro."
            case .permissionDenied:
                return "Se necesitan permisos de micrófono y reconocimiento de voz."
            case .unknownError(let error):
                return error.localizedDescription
            }
        }
    }
}

