//
//  RetellCallManager.swift
//  ai_anti_doomscroll
//

import Foundation
import AVFoundation
import Combine

class RetellCallManager: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    @Published var isCalling = false
    @Published var callStatus = "Disconnected"
    @Published var transcript = ""
    
    private var webSocket: URLSessionWebSocketTask?
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    
    // Retell Audio Format: 24kHz, 16-bit Linear PCM (Mono)
    private let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false)!
    
    func startCall(accessToken: String) {
        // Decode JWT to see what endpoint it contains
        // Retell's access_token is a JWT that might contain connection info
        let parts = accessToken.split(separator: ".")
        if parts.count >= 2 {
            if let payloadData = Data(base64Encoded: String(parts[1]), options: .ignoreUnknownCharacters),
               let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                print("🔍 JWT Payload: \(json)")
                
                // Check if there's a video/room field that might indicate the endpoint
                if let video = json["video"] as? [String: Any],
                   let room = video["room"] as? String {
                    print("📍 Found room: \(room)")
                }
            }
        }
        
        // Try Retell's actual WebRTC signaling endpoint
        // Based on Retell docs, web calls use WebRTC, not raw WebSocket
        // The correct approach would be to use their JS SDK or implement WebRTC properly
        // For now, let's try their WebSocket endpoint with the token
        guard let url = URL(string: "wss://api.retellai.com/audio-websocket/\(accessToken)") else {
            print("❌ Invalid WebSocket URL")
            return
        }
        
        self.isCalling = true
        self.callStatus = "Connecting..."
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 30
        
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        // Start receiving immediately to catch any error messages
        receiveMessage()
    }
    
    // MARK: - Retell Handshake
    private func sendConfig() {
        // Retell WebSocket expects a config message with specific format
        // Try different possible formats that Retell might accept
        let config: [String: Any] = [
            "type": "config",
            "sample_rate": 24000,
            "audio_encoding": "s16le",
            "channels": 1
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: config),
           let jsonString = String(data: data, encoding: .utf8) {
            let message = URLSessionWebSocketTask.Message.string(jsonString)
            webSocket?.send(message) { [weak self] error in
                if let error = error {
                    print("❌ Config Send Error: \(error.localizedDescription)")
                } else {
                    print("✅ Retell Handshake Sent")
                    // Wait a moment for Retell to process the config before starting audio
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.setupAudio()
                        self?.receiveMessage()
                    }
                }
            }
        }
    }
    
    private func setupAudio() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try audioSession.setActive(true)
            
            audioEngine.attach(playerNode)
            let mixerFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: mixerFormat)
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, time) in
                // Only send audio once the connection is truly active
                if self?.callStatus == "Listening..." {
                    self?.sendAudioToServer(buffer: buffer)
                }
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            playerNode.play()
            
        } catch {
            print("❌ Audio Engine Error: \(error.localizedDescription)")
            self.callStatus = "Audio Error"
        }
    }
    
    private func sendAudioToServer(buffer: AVAudioPCMBuffer) {
        guard let data = buffer.toData() else { return }
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocket?.send(message) { error in
            if let error = error {
                print("❌ WS Send Error: \(error.localizedDescription)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.handleIncomingAudio(data: data)
                case .string(let text):
                    self.handleMetadata(text: text)
                @unknown default:
                    break
                }
                self.receiveMessage() 
            case .failure(let error):
                print("❌ WS Receive Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.callStatus = "Connection Lost"
                    self.isCalling = false
                }
            }
        }
    }
    
    private func handleIncomingAudio(data: Data) {
        guard let buffer = dataToPCMBuffer(data: data) else { return }
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }
    
    private func handleMetadata(text: String) {
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            if let transcript = json["transcript"] as? String {
                DispatchQueue.main.async { self.transcript = transcript }
            }
            
            if let status = json["call_status"] as? String {
                DispatchQueue.main.async { self.callStatus = status.capitalized }
            }
        }
    }
    
    private func dataToPCMBuffer(data: Data) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(data.count) / 2
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        
        data.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) in
            if let intData = buffer.int16ChannelData?[0] {
                let pcmData = rawBufferPointer.bindMemory(to: Int16.self)
                for i in 0..<Int(frameCount) {
                    intData[i] = pcmData[i]
                }
            }
        }
        return buffer
    }
    
    func stopCall() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        webSocket?.cancel(with: .normalClosure, reason: nil)
        isCalling = false
        callStatus = "Disconnected"
    }
    
    // MARK: - Delegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.callStatus = "Handshaking..."
            // Send config message first - setupAudio and receiveMessage will be called
            // from within sendConfig's completion handler after a short delay
            self.sendConfig()
        }
    }
}

// Extension moved to HumeCallManager.swift to avoid redeclaration
// This file is deprecated - using HumeCallManager instead
