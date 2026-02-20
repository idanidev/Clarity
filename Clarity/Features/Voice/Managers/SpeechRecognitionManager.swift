// SpeechRecognitionManager.swift
// Native iOS speech recognition with robust audio session handling
// Optimized for co-existence with System Sounds

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

    static let shared = SpeechRecognitionManager()

    // Internal
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()

    // Safety & Logging
    private var bufferCount: Int = 0
    private let maxBuffers = 800  // Safety limit (~8 seconds)
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
    private let silenceThreshold: Float = 0.05
    private let silenceTimeout: TimeInterval = 1.5

    private init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
        setupInterruptionObservers()
    }

    deinit {
        interruptionObserverTask?.cancel()
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
        guard !isListening, !isConfiguring else { return }
        isConfiguring = true
        defer { isConfiguring = false }

        logger.info("🎤 Starting recording...")

        // Clean previous state
        cleanupResources()
        transcript = ""
        interimTranscript = ""
        lastError = nil
        bufferCount = 0

        // Configure audio session
        SoundManager.shared.configureAudioSession()

        // 3. Create Request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw RecognitionError.audioEngineFailure
        }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false  // Allow server-side for better accuracy if needed

        // 4. Configure Input Node
        let inputNode = audioEngine.inputNode

        // Remove existing tap if any (Extra safety)
        inputNode.removeTap(onBus: 0)

        // Use inputFormat(forBus: 0) which usually reflects the hardware sample rate (e.g. 24000 or 44100 or 48000)
        // outputFormat(forBus: 0) can sometimes be the canonical format of the bus which might mismatch hardware.
        // For installing a tap, we should generally use the node's input format OR 0 (nil) if we want standard.
        // But `installTap` requires a valid format.
        let recordingFormat = inputNode.inputFormat(forBus: 0)

        // Sometimes inputFormat is 0Hz if not initialized? Check against outputs too if valid.
        // But typically, on iOS, inputFormat(forBus: 0) provides the correct hardware format.

        // Safety check for valid format
        guard recordingFormat.sampleRate > 0 else {
            // Fallback: Try output format, but this was causing the crash?
            logger.error("❌ Invalid Audio Format (0 Hz) from inputNode.inputFormat")
            throw RecognitionError.microphoneUnavailable
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) {
            [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)

            let level = self.extractAudioLevel(from: buffer)

            // Update UI state and silence detection on MainActor (Swift 6 safe)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.audioLevel = level
                if level > self.silenceThreshold {
                    self.lastAudioActivity = Date()
                    self.resetSilenceTimer()
                }
            }

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
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) {
            [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let bestString = result.bestTranscription.formattedString
                // Update properties on Main Actor
                Task { @MainActor in
                    if result.isFinal {
                        self.transcript = bestString
                        self.interimTranscript = ""
                        self.logger.info("✅ Final Transcript: \(bestString)")
                    } else {
                        self.interimTranscript = bestString
                        self.logger.info("📝 Interim: \(bestString)")
                    }
                }
            }

            if let error = error {
                // Ignore "Success" or "User Cancelled" type errors usually
                if (error as NSError).code != 203 {
                    self.logger.error("❌ Recognition error: \(error.localizedDescription)")
                }

                Task { @MainActor [weak self] in
                    self?.lastError = .unknownError(error)
                }
                // Don't necessarily stop here, let the UI decide, unless it's fatal
            }
        }

        isListening = true
        lastAudioActivity = Date()
        resetSilenceTimer()
        logger.info("✅ Recording active")
    }

    func stopRecording() {
        silenceDetectionTimer?.invalidate()
        silenceDetectionTimer = nil

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
