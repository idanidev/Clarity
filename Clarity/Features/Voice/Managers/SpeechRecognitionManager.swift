// SpeechRecognitionManager.swift
// Native iOS speech recognition with audio level monitoring

import Foundation
import Speech
import AVFoundation
import Combine

class SpeechRecognitionManager: ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var interimTranscript = ""
    @Published var audioLevel: Float = 0.0
    @Published var hasPermission = false
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    private var silenceTimer: Timer?
    private var settings: VoiceSettings
    
    init(settings: VoiceSettings = .load()) {
        self.settings = settings
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    }
    
    // MARK: - Permission Handling
    
    func requestPermissions() async -> Bool {
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
        // Cancel any ongoing tasks
        stopRecording()
        
        // Reset state
        transcript = ""
        interimTranscript = ""
        
        // Setup audio session - use .playAndRecord for better compatibility
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
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
        
        // Reset buffer count
        bufferCount = 0
        
        // Install tap with the input node's output format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)
            self.extractAudioLevel(from: buffer)
            
            // Memory Safety: Stop if we exceed buffer limit
            self.bufferCount += 1
            if self.bufferCount > self.maxBuffers {
                DispatchQueue.main.async {
                    print("⚠️ Auto-stopping recording to prevent OOM")
                    self.stopRecording()
                }
            }
        }
        
        // Prepare and start the audio engine AFTER installing the tap
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let bestTranscription = result.bestTranscription
                
                DispatchQueue.main.async {
                    if result.isFinal {
                        self.transcript = (self.transcript + " " + bestTranscription.formattedString).trimmingCharacters(in: .whitespacesAndNewlines)
                        self.interimTranscript = ""
                    } else {
                        self.interimTranscript = bestTranscription.formattedString
                    }
                    
                    // Reset silence timer on speech activity
                    self.resetSilenceTimer()
                }
            }
            
            if error != nil || result?.isFinal == true {
                // Stop recognition if there's an error or final result
                if error != nil {
                    DispatchQueue.main.async {
                        self.stopRecording()
                    }
                }
            }
        }
        
        isListening = true
    }
    
    func stopRecording() {
        // Stop silence timer
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        // Stop audio engine safely
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Stop recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        isListening = false
        audioLevel = 0.0
    }
    
    // MARK: - Silence Detection
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        
        silenceTimer = Timer.scheduledTimer(withTimeInterval: settings.silenceTimeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.stopRecording()
            }
        }
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
    
    enum RecognitionError: Error {
        case requestCreationFailed
        case audioEngineFailure
        case permissionDenied
    }
}
