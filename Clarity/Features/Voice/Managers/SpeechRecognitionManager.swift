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
    
    // Audio Session Resilience (iOS 26 Elite)
    private var audioSessionState: AudioSessionState = .idle
    private var retryAttempts = 0
    private let maxRetries = 3
    private var wasInterrupted = false
    private var hasRegisteredObservers = false
    
    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
        setupInterruptionObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Pre-warming (Crucial for Speed)
    
    func prepare() {
        Task {
            // Delegate to Pro SoundManager
            SoundManager.shared.configureAudioSession()
            logger.info("🔥 Audio Engine Pre-warmed (Pro)")
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() async throws {
        logger.info("🎤 Starting recording pipeline (Pro)...")
        
        // 1. Play Start Sound & Haptics (Immediate Feedback)
        SoundManager.shared.play(.startRecording)
        
        // 2. Technical Delay (0.2s) - Clean Input Channel
        // This prevents the "ding" sound from being recorded in the transcript
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // 3. Clean previous state
        cleanupResources()
        transcript = ""
        interimTranscript = ""
        lastError = nil
        bufferCount = 0
        
        // 4. Ensure Audio Session is Robust
        SoundManager.shared.configureAudioSession()
        
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
    
    
    // MARK: - Audio Session Resilience (iOS 26 Elite)
    
    private func setupInterruptionObservers() {
        // Prevent duplicate registrations (memory leak fix)
        guard !hasRegisteredObservers else {
            return
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        hasRegisteredObservers = true
        logger.info("🔔 Audio interruption observers registered")
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            logger.warning("⚠️ Audio interruption BEGAN (incoming call/notification)")
            audioSessionState = .interrupted
            wasInterrupted = true
            
            // Pause, clean buffers, save state
            if isListening {
                logger.info("📦 Saving state and cleaning buffers...")
                audioEngine.pause()
                recognitionTask?.finish() // Gracefully finish instead of cancel
                isListening = false
            }
            
        case .ended:
            logger.info("✅ Audio interruption ENDED - Attempting recovery")
            
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) {
                logger.info("🔄 System suggests resuming - Reactivating audio session")
                attemptAudioRecovery()
            } else {
                logger.warning("🚫 System does not suggest resuming - Manual restart required")
                audioSessionState = .needsRecovery
            }
            
        @unknown default:
            logger.error("❓ Unknown interruption type")
        }
    }
    
    private func attemptAudioRecovery() {
        Task {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                audioSessionState = .active
                wasInterrupted = false
                retryAttempts = 0
                logger.info("✅ Audio session recovered successfully")
            } catch {
                retryAttempts += 1
                logger.error("❌ Recovery attempt \(self.retryAttempts)/\(self.maxRetries) failed: \(error.localizedDescription)")
                
                if self.retryAttempts < self.maxRetries {
                    // Exponential backoff: 0.5s, 1s, 2s
                    let delay = pow(2.0, Double(self.retryAttempts - 1)) * 0.5
                    logger.info("🔄 Retrying in \(delay)s...")
                    
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attemptAudioRecovery()
                } else {
                    logger.error("🚫 Max retries reached - Audio session in zombie state")
                    audioSessionState = .failed
                }
            }
        }
    }
    
    // Expose session state for UI
    var sessionState: AudioSessionState {
        audioSessionState
    }
    
    enum AudioSessionState {
        case idle
        case active
        case interrupted
        case needsRecovery
        case failed
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
