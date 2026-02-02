//
//  HumeCallManager.swift
//  ai_anti_doomscroll
//

import Foundation
import AVFoundation
import Combine

class HumeCallManager: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    @Published var isCalling = false
    @Published var callStatus = "Disconnected"
    @Published var transcript = ""
    @Published var isMuted = false
    
    // Callback for when call ends (used for automatic termination)
    var onCallEnded: (() -> Void)?
    
    private var webSocket: URLSessionWebSocketTask?
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    
    // Formats for Hume (48kHz mono)
    private let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 1, interleaved: false)!
    private let playbackFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: false)!
    
    private var audioConverter: AVAudioConverter?
    private var initialVariables: [String: String]?
    
    // Call duration tracking
    private var callStartTime: Date?
    private var lastRecordedDuration: TimeInterval = 0
    private var maxCallDuration: TimeInterval = 0 // Maximum allowed call duration in seconds
    private var callTimer: Timer?
    
    var callDuration: TimeInterval {
        guard let startTime = callStartTime else {
            // If startTime is nil, return the last recorded duration (in case stopCall was already called)
            return lastRecordedDuration
        }
        let duration = Date().timeIntervalSince(startTime)
        return duration
    }
    
    var remainingTime: TimeInterval {
        guard maxCallDuration > 0 else { return 0 }
        let elapsed = callDuration
        return max(0, maxCallDuration - elapsed)
    }
    
    func startCall(websocketURL: String, initialVariables: [String: String]?, maxDurationSeconds: TimeInterval = 0) {
        guard let url = URL(string: websocketURL) else {
            print("❌ Invalid Hume WebSocket URL")
            return
        }
        
        self.initialVariables = initialVariables
        self.isCalling = true
        self.isMuted = false
        self.transcript = ""
        self.callStatus = "Connecting..."
        self.callStartTime = Date() // Track call start time
        self.lastRecordedDuration = 0 // Reset last recorded duration
        self.maxCallDuration = maxDurationSeconds // Set maximum call duration
        print("📱 HumeCallManager: Call started at \(self.callStartTime?.description ?? "nil") with max duration: \(maxDurationSeconds)s")
        
        let request = URLRequest(url: url)
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        
        webSocket = session.webSocketTask(with: request)
        webSocket?.resume()
        
        receiveMessage()
        
        // Start timer to monitor call duration and auto-end when limit reached
        if maxDurationSeconds > 0 {
            startCallTimer()
        }
    }
    
    private func startCallTimer() {
        // Check every 0.5 seconds if we've reached the time limit
        callTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if let startTime = self.callStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                let remaining = self.maxCallDuration - elapsed
                
                // If we've reached or exceeded the limit, end the call
                if remaining <= 0 {
                    print("⏰ Call time limit reached! Elapsed: \(elapsed)s, Limit: \(self.maxCallDuration)s")
                    DispatchQueue.main.async {
                        self.callStatus = "Time limit reached"
                        // Give a brief moment for the status to update, then end call
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.stopCall()
                            // Trigger callback if set
                            self.onCallEnded?()
                        }
                    }
                } else if remaining <= 5 {
                    // Warn when 5 seconds remaining
                    DispatchQueue.main.async {
                        self.callStatus = "\(Int(remaining))s remaining"
                    }
                }
            }
        }
    }
    
    private func sendSessionSettings() {
        let settings: [String: Any] = [
            "type": "session_settings",
            "audio": ["encoding": "linear16", "sample_rate": 48000, "channels": 1],
            "variables": initialVariables ?? [:]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: settings),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            webSocket?.send(.string(jsonString)) { [weak self] error in
                if error == nil {
                    print("✅ Session Settings Sent")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self?.setupAudio() }
                }
            }
        }
    }
    
    private func setupAudio() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            if audioEngine.isRunning { audioEngine.stop() }
            
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playbackFormat)
            
            let inputNode = audioEngine.inputNode
            let hardwareFormat = inputNode.outputFormat(forBus: 0)
            
            audioConverter = AVAudioConverter(from: hardwareFormat, to: recordingFormat)
            
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] (buffer, time) in
                self?.processAndSendAudio(buffer: buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            playerNode.play()
            
            DispatchQueue.main.async { self.callStatus = "Listening..." }
        } catch {
            print("❌ Audio Error: \(error.localizedDescription)")
            DispatchQueue.main.async { self.callStatus = "Audio Error" }
        }
    }
    
    private func processAndSendAudio(buffer: AVAudioPCMBuffer) {
        guard !isMuted else { return }
        guard let converter = audioConverter else { return }
        let ratio = recordingFormat.sampleRate / buffer.format.sampleRate
        let targetFrameCount = UInt32(Double(buffer.frameLength) * ratio)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: recordingFormat, frameCapacity: targetFrameCount) else { return }
        
        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        if let data = outputBuffer.toData() {
            let msg: [String: Any] = ["type": "audio_input", "data": data.base64EncodedString()]
            if let json = try? JSONSerialization.data(withJSONObject: msg), let str = String(data: json, encoding: .utf8) {
                webSocket?.send(.string(str)) { _ in }
            }
        }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text): self.handleIncomingMessage(text: text)
                case .data(let data): self.handleIncomingData(data: data)
                @unknown default: break
                }
                self.receiveMessage()
            case .failure(let error):
                print("❌ WS Error: \(error.localizedDescription)")
                DispatchQueue.main.async { self.isCalling = false }
            }
        }
    }
    
    private func handleIncomingData(data: Data) {
        let frameCount = UInt32(data.count) / 2
        guard let buffer = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        
        data.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) in
            let pcmData = rawBufferPointer.bindMemory(to: Int16.self)
            if let floatData = buffer.floatChannelData?[0] {
                for i in 0..<Int(frameCount) {
                    floatData[i] = Float(pcmData[i]) / 32768.0
                }
            }
        }
        
        // Apply micro-fade to eliminate clicks at buffer boundaries
        buffer.applyMicroFade()
        
        // Immediate scheduling
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }
    
    private func handleIncomingMessage(text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        if let type = json["type"] as? String {
            switch type {
            case "audio_output":
                if let base64 = json["data"] as? String, let audioData = Data(base64Encoded: base64) {
                    handleIncomingData(data: audioData)
                }
            case "user_interruption":
                playerNode.stop()
                playerNode.play() // Keep player ready
            case "user_message", "assistant_message":
                let content = (json["message"] as? [String: Any])?["content"] as? String 
                           ?? json["content"] as? String 
                           ?? (json["message"] as? String)
                if let msg = content {
                    DispatchQueue.main.async {
                        self.transcript += "\n\(type == "user_message" ? "You: " : "AI: ")\(msg)"
                    }
                }
            default: break
            }
        }
    }
    
    func stopCall() {
        // Stop the timer first
        callTimer?.invalidate()
        callTimer = nil
        
        // Store duration before resetting startTime
        if let startTime = callStartTime {
            lastRecordedDuration = Date().timeIntervalSince(startTime)
            print("📱 HumeCallManager: stopCall() called. Final duration: \(lastRecordedDuration)s")
        } else {
            print("⚠️ HumeCallManager: stopCall() called but callStartTime was already nil. Using last recorded: \(lastRecordedDuration)s")
        }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        webSocket?.cancel(with: .normalClosure, reason: nil)
        isCalling = false
        callStatus = "Disconnected"
        callStartTime = nil // Reset call start time (but keep lastRecordedDuration)
        maxCallDuration = 0 // Reset max duration
        onCallEnded = nil // Clear callback
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.callStatus = "Configuring..."
            self.sendSessionSettings()
        }
    }
}

extension AVAudioPCMBuffer {
    func toData() -> Data? {
        let length = Int(self.frameLength)
        if self.format.commonFormat == .pcmFormatInt16 {
            return Data(bytes: self.int16ChannelData![0], count: length * 2)
        }
        return nil
    }
    
    func applyMicroFade() {
        guard let channelData = floatChannelData?[0] else { return }
        let frameCount = Int(frameLength)
        let fadeFrames = min(frameCount / 2, 960) // ~20ms fade at 48kHz
        
        // Fade in
        for i in 0..<fadeFrames {
            let gain = Float(i) / Float(fadeFrames)
            channelData[i] *= gain
        }
        
        // Fade out
        for i in 0..<fadeFrames {
            let gain = Float(i) / Float(fadeFrames)
            channelData[frameCount - 1 - i] *= gain
        }
    }
}
