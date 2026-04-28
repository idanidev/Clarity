// SpeechRecognitionManager.swift
// Native iOS speech recognition with robust audio session handling
// Optimized for co-existence with System Sounds + AirPods + maximum accuracy

import AVFoundation
import Foundation
import OSLog
import Observation
import Speech

@MainActor
@Observable
class SpeechRecognitionManager {
    var isListening = false
    var transcript = ""
    var interimTranscript = ""
    var audioLevel: Float = 0.0
    var hasPermission = false
    var lastError: RecognitionError?

    /// Circular buffer of recent audio levels for waveform visualizer (last 30 samples)
    var waveformLevels: [Float] = Array(repeating: 0, count: 30)

    static let shared = SpeechRecognitionManager()

    // Internal
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()

    // Safety & Logging
    private var bufferCount: Int = 0
    private let maxBuffers = 1600  // Safety limit (~16 seconds at 100 buffers/s)
    private let logger = Logger(subsystem: "com.clarity.app", category: "Voice")
    private var isConfiguring = false

    // Audio Session Resilience (iOS 26)
    private var audioSessionState: AudioSessionState = .idle
    private var retryAttempts = 0
    private let maxRetries = 3
    private var wasInterrupted = false
    nonisolated(unsafe) private var interruptionObserverTask: Task<Void, Never>?  // safe: Task.cancel() is thread-safe

    // Silence Detection
    private var silenceDetectionTimer: Timer?
    private var lastAudioActivity: Date = Date()
    private let silenceThreshold: Float = 0.02   // muy sensible para capturar voz suave
    private let silenceTimeout: TimeInterval = 2.2 // tolerante para hablar con pausa natural
    /// Indica si ya se ha detectado audio real. El timer de silencio NO
    /// empieza hasta que el micrófono reciba audio por primera vez.
    private var hasDetectedAudioInput = false

    // Auto-retry on recognition failure
    nonisolated(unsafe) private var retryRecognitionTask: Task<Void, Never>?  // safe: Task.cancel() is thread-safe
    private var currentSessionUsedOnDevice = false

    // Waveform ring buffer index
    private var waveformIndex = 0

    // Vocabulary hints for Spanish expense dictation
    private static let expenseContextualStrings: [String] = [
        "euros", "céntimos", "euro", "€",
        "supermercado", "mercadona", "carrefour", "lidl", "aldi", "dia", "eroski",
        "restaurante", "cafetería", "café", "bar", "almuerzo", "cena", "desayuno",
        "gasolina", "gasolinera", "repsol", "bp", "cepsa",
        "farmacia", "médico", "dentista", "clínica",
        "transporte", "metro", "bus", "taxi", "uber", "cabify", "renfe",
        "electricidad", "agua", "gas", "internet", "teléfono", "seguro",
        "amazon", "zara", "el corte inglés", "h&m", "ikea",
        "gym", "gimnasio", "netflix", "spotify", "apple",
        "añade", "agrega", "anota", "gasto", "compra", "pagué", "pago",
        "veinte", "treinta", "cuarenta", "cincuenta", "cien", "doscientos"
    ]

    private init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
        self.speechRecognizer?.defaultTaskHint = .dictation
        setupInterruptionObservers()
    }

    deinit {
        interruptionObserverTask?.cancel()
        retryRecognitionTask?.cancel()
    }

    // MARK: - Pre-warming (Crucial for Speed)

    func prepare() {
        Task {
            #if targetEnvironment(simulator)
            logger.info("🔧 Simulador detectado — skip pre-warm de audio engine")
            return
            #else
            SoundManager.shared.configureAudioSession()
            // Pre-warm speech recognizer by checking availability
            guard let recognizer = speechRecognizer else { return }
            if !recognizer.isAvailable {
                logger.warning("⚠️ Speech recognizer not available during pre-warm")
                return
            }
            // Touch the audio engine to pre-initialize hardware
            _ = audioEngine.inputNode
            logger.info("🔥 Speech Engine Pre-warmed — on-device: \(recognizer.supportsOnDeviceRecognition)")
            #endif
        }
    }

    // MARK: - Recording Control

    func startRecording() async throws {
        #if targetEnvironment(simulator)
        logger.warning("🔧 Simulador detectado — micrófono no disponible")
        throw RecognitionError.microphoneUnavailable
        #endif
        guard !isListening, !isConfiguring else { return }
        isConfiguring = true
        defer { isConfiguring = false }

        logger.info("🎤 Starting recording...")
        retryRecognitionTask?.cancel()
        retryRecognitionTask = nil

        // Clean previous state
        cleanupResources()
        transcript = ""
        interimTranscript = ""
        lastError = nil
        bufferCount = 0
        hasDetectedAudioInput = false
        waveformLevels = Array(repeating: 0, count: 30)
        waveformIndex = 0

        // Configure audio session for recording
        // (sin .defaultToSpeaker para compatibilidad con AirPods y Bluetooth)
        SoundManager.shared.configureForRecording()

        // Create Request with maximum quality settings
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw RecognitionError.audioEngineFailure
        }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

        // Prefer on-device (faster, private, works offline) with server fallback
        if speechRecognizer?.supportsOnDeviceRecognition == true {
            recognitionRequest.requiresOnDeviceRecognition = true
            currentSessionUsedOnDevice = true
            logger.info("📱 Using on-device recognition (fast + private)")
        } else {
            recognitionRequest.requiresOnDeviceRecognition = false
            currentSessionUsedOnDevice = false
            logger.info("☁️ Using server-side recognition")
        }

        // Vocabulary hints to improve accuracy for expense dictation in Spanish
        recognitionRequest.contextualStrings = Self.expenseContextualStrings

        // Configure Input Node
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        let recordingFormat = inputNode.inputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0 else {
            logger.error("❌ Invalid Audio Format (0 Hz) from inputNode.inputFormat")
            throw RecognitionError.microphoneUnavailable
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
            [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)

            let level = self.extractAudioLevel(from: buffer)

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.audioLevel = level

                // Update waveform ring buffer
                self.waveformLevels[self.waveformIndex % self.waveformLevels.count] = level
                self.waveformIndex += 1

                if level > self.silenceThreshold {
                    self.lastAudioActivity = Date()
                    if !self.hasDetectedAudioInput {
                        self.hasDetectedAudioInput = true
                        self.logger.info("🎙️ Audio input detected — starting silence timer")
                    }
                    self.resetSilenceTimer()
                }
            }

            self.bufferCount += 1
            if self.bufferCount > self.maxBuffers {
                self.logger.warning("⚠️ Max buffer limit reached — stopping recording")
                self.stopRecording()
            }
        }

        // Start Engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            logger.error("❌ Audio Engine Start Failed: \(error.localizedDescription)")
            throw RecognitionError.audioEngineFailure
        }

        // Start Recognition Task
        startRecognitionTask(with: recognitionRequest)

        isListening = true
        lastAudioActivity = Date()
        logger.info("✅ Recording active (on-device: \(self.currentSessionUsedOnDevice))")
    }

    /// Starts (or restarts) a recognition task. Separated so retry logic can call it.
    private func startRecognitionTask(with request: SFSpeechAudioBufferRecognitionRequest) {
        recognitionTask?.cancel()
        recognitionTask = speechRecognizer?.recognitionTask(with: request) {
            [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let bestString = result.bestTranscription.formattedString
                Task { @MainActor [weak self] in
                    guard let self else { return }
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
                let nsError = error as NSError
                // Code 203 = "Retry" / kLSRErrorDomain recognition cancelled
                // Code 209 = on-device model not downloaded yet
                // Code 301 = network error (server recognition failed)
                let ignoredCodes = [203, 216, 1110]  // Cancelled / no speech / user stopped
                if !ignoredCodes.contains(nsError.code) {
                    self.logger.error("❌ Recognition error [\(nsError.code)]: \(error.localizedDescription)")
                }

                Task { @MainActor [weak self] in
                    guard let self else { return }

                    // If on-device failed with "model unavailable" (209) → retry with server
                    if nsError.code == 209 && self.currentSessionUsedOnDevice {
                        self.logger.info("🔄 On-device model unavailable — retrying with server recognition")
                        self.retryWithServerRecognition()
                        return
                    }

                    // For network errors during server recognition, surface the error
                    if nsError.code == 301 {
                        self.lastError = .networkError
                        return
                    }

                    if !ignoredCodes.contains(nsError.code) {
                        self.lastError = .unknownError(error)
                    }
                }
            }
        }
    }

    /// Retries recognition using server-side when on-device model is unavailable.
    private func retryWithServerRecognition() {
        guard isListening, let existingRequest = recognitionRequest else { return }
        currentSessionUsedOnDevice = false
        existingRequest.requiresOnDeviceRecognition = false
        logger.info("☁️ Switched to server-side recognition mid-session")
        // The existing request is already receiving buffers — just restart the task
        startRecognitionTask(with: existingRequest)
    }

    func stopRecording() {
        silenceDetectionTimer?.invalidate()
        silenceDetectionTimer = nil
        hasDetectedAudioInput = false
        retryRecognitionTask?.cancel()
        retryRecognitionTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            isListening = false
            // Reset waveform to idle
            waveformLevels = Array(repeating: 0, count: 30)
            logger.info("🛑 Recording stopped")
            SoundManager.shared.restoreAfterRecording()
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

    private func extractAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
            .map { channelDataValue[$0] }

        let rms = sqrt(
            channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalizedLevel = max(0, min(1, (avgPower + 50) / 50))
        // Note: audioLevel is updated by the caller on @MainActor
        return normalizedLevel
    }

    // Permission Helpers
    func checkPermissions() -> Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized
            && AVAudioApplication.shared.recordPermission == .granted
    }

    func requestPermissions() async throws {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            throw RecognitionError.microphoneUnavailable
        }

        let audioStatus = await AVAudioApplication.requestRecordPermission()
        guard audioStatus else {
            throw RecognitionError.microphoneUnavailable
        }

        hasPermission = true
    }

    // MARK: - Audio Session Resilience (iOS 26 — AsyncSequence notifications)

    private func setupInterruptionObservers() {
        interruptionObserverTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance()
            )
            for await notification in notifications {
                self?.handleInterruptionSync(notification: notification)
            }
        }
        logger.info("🔔 Audio interruption observer Task started (iOS 26 async)")
    }

    @MainActor
    private func handleInterruptionSync(notification: Notification) {
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }

        switch type {
        case .began:
            logger.warning("⚠️ Audio interruption BEGAN (incoming call/notification)")
            audioSessionState = .interrupted
            wasInterrupted = true

            if isListening {
                logger.info("📦 Saving state and cleaning buffers...")
                audioEngine.pause()
                recognitionTask?.finish()
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
                logger.error(
                    "❌ Recovery attempt \(self.retryAttempts)/\(self.maxRetries) failed: \(error.localizedDescription)"
                )

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

    // MARK: - Silence Detection

    private func resetSilenceTimer() {
        silenceDetectionTimer?.invalidate()
        silenceDetectionTimer = Timer.scheduledTimer(
            withTimeInterval: silenceTimeout, repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.autoStopDueToSilence()
            }
        }
    }

    private func autoStopDueToSilence() {
        guard isListening else { return }
        logger.info("🔇 Auto-stopping due to silence")
        stopRecording()
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
        case networkError
        case unknownError(Error)

        var errorDescription: String? {
            switch self {
            case .audioEngineFailure: return "Error en el motor de audio"
            case .microphoneUnavailable: return "Micrófono no disponible"
            case .networkError: return "Sin conexión — activa el reconocimiento en el dispositivo en Ajustes"
            case .unknownError(let e): return e.localizedDescription
            }
        }
    }
}
