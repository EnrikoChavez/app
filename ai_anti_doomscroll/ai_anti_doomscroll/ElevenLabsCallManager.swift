import Foundation
import AVFoundation

class ElevenLabsCallManager: NSObject, ObservableObject, URLSessionWebSocketDelegate, AnyCallManager {
    @Published var isCalling = false
    @Published var callStatus = "Disconnected"
    @Published var transcript = ""
    @Published var isMuted = false

    var onCallEnded: (() -> Void)?

    private var webSocket: URLSessionWebSocketTask?
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    // ElevenLabs uses 16 kHz mono 16-bit PCM
    private let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!
    private let playbackFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

    private var audioConverter: AVAudioConverter?
    private var voiceId: String?
    private var initialVariables: [String: String]?
    private var routeChangeObserver: Any?

    private var callStartTime: Date?
    var lastRecordedDuration: TimeInterval = 0
    private var maxCallDuration: TimeInterval = 0
    private var callTimer: Timer?

    var callDuration: TimeInterval {
        guard let startTime = callStartTime else { return lastRecordedDuration }
        return Date().timeIntervalSince(startTime)
    }

    var remainingTime: TimeInterval {
        guard maxCallDuration > 0 else { return 0 }
        return max(0, maxCallDuration - callDuration)
    }

    override init() {
        super.init()
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, self.isCalling else { return }
            guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let changeReason = AVAudioSession.RouteChangeReason(rawValue: reason) else { return }
            switch changeReason {
            case .oldDeviceUnavailable, .newDeviceAvailable:
                self.restartAudioTap()
            default: break
            }
        }
    }

    deinit {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func activateAudioSession() {
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try s.setActive(true)
        } catch {
            print("⚠️ ElevenLabsCallManager: audio session pre-activation failed: \(error.localizedDescription)")
        }
    }

    func startCall(websocketURL: String, voiceId: String?, initialVariables: [String: String]?, maxDurationSeconds: TimeInterval = 0) {
        guard let url = URL(string: websocketURL) else { return }
        self.voiceId = voiceId
        self.initialVariables = initialVariables
        self.isCalling = true
        self.isMuted = false
        self.transcript = ""
        self.callStatus = "Connecting..."
        self.callStartTime = Date()
        self.lastRecordedDuration = 0
        self.maxCallDuration = maxDurationSeconds

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        webSocket = session.webSocketTask(with: URLRequest(url: url))
        webSocket?.resume()
        receiveMessage()

        if maxDurationSeconds > 0 { startCallTimer() }
    }

    private func startCallTimer() {
        callTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            if let start = self.callStartTime {
                let remaining = self.maxCallDuration - Date().timeIntervalSince(start)
                if remaining <= 0 {
                    DispatchQueue.main.async {
                        self.callStatus = "Time limit reached"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.stopCall()
                            self.onCallEnded?()
                        }
                    }
                } else if remaining <= 5 {
                    DispatchQueue.main.async { self.callStatus = "\(Int(remaining))s remaining" }
                }
            }
        }
    }

    private func sendInitiationData() {
        var payload: [String: Any] = ["type": "conversation_initiation_client_data"]

        var ttsOverride: [String: Any] = ["output_format": "pcm_16000"]
        if let voiceId = voiceId { ttsOverride["voice_id"] = voiceId }
        payload["conversation_config_override"] = ["tts": ttsOverride]

        if let vars = initialVariables, !vars.isEmpty {
            payload["dynamic_variables"] = vars
        }

        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let str = String(data: data, encoding: .utf8) {
            webSocket?.send(.string(str)) { [weak self] error in
                if error == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self?.setupAudio() }
                }
            }
        }
    }

    private func setupAudio() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
            if audioEngine.isRunning { audioEngine.stop() }

            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playbackFormat)

            let currentSampleRate = audioSession.sampleRate
            let hardwareFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: currentSampleRate, channels: 1, interleaved: false)!
            audioConverter = AVAudioConverter(from: hardwareFormat, to: recordingFormat)

            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] buffer, _ in
                self?.processAndSendAudio(buffer: buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            playerNode.play()
            DispatchQueue.main.async { self.callStatus = "Listening..." }
        } catch {
            print("❌ ElevenLabs Audio Error: \(error.localizedDescription)")
            DispatchQueue.main.async { self.callStatus = "Audio Error" }
        }
    }

    private func processAndSendAudio(buffer: AVAudioPCMBuffer) {
        guard !isMuted, let converter = audioConverter else { return }
        let ratio = recordingFormat.sampleRate / buffer.format.sampleRate
        let targetFrameCount = UInt32(Double(buffer.frameLength) * ratio)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: recordingFormat, frameCapacity: targetFrameCount) else { return }

        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard let channelData = outputBuffer.int16ChannelData else { return }
        let data = Data(bytes: channelData[0], count: Int(outputBuffer.frameLength) * 2)
        let msg: [String: Any] = ["user_audio_chunk": data.base64EncodedString()]
        if let json = try? JSONSerialization.data(withJSONObject: msg),
           let str = String(data: json, encoding: .utf8) {
            webSocket?.send(.string(str)) { _ in }
        }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message { self.handleMessage(text: text) }
                self.receiveMessage()
            case .failure(let error):
                print("❌ ElevenLabs WS Error: \(error.localizedDescription)")
                DispatchQueue.main.async { self.isCalling = false }
            }
        }
    }

    private func handleMessage(text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "audio":
            if let event = json["audio_event"] as? [String: Any],
               let b64 = event["audio_base_64"] as? String,
               let audioData = Data(base64Encoded: b64) {
                playPCMData(audioData)
            }
        case "interruption":
            playerNode.stop()
            playerNode.play()
        case "agent_response":
            if let event = json["agent_response_event"] as? [String: Any],
               let msg = event["agent_response"] as? String {
                DispatchQueue.main.async { self.transcript += "\nAI: \(msg)" }
            }
        case "user_transcript":
            if let event = json["user_transcription_event"] as? [String: Any],
               let msg = event["user_transcript"] as? String {
                DispatchQueue.main.async { self.transcript += "\nYou: \(msg)" }
            }
        case "ping":
            if let event = json["ping_event"] as? [String: Any],
               let eventId = event["event_id"] as? Int {
                let pong: [String: Any] = ["type": "pong", "event_id": eventId]
                if let d = try? JSONSerialization.data(withJSONObject: pong),
                   let s = String(data: d, encoding: .utf8) {
                    webSocket?.send(.string(s)) { _ in }
                }
            }
        case "conversation_initiation_metadata":
            print("✅ ElevenLabs conversation initiated")
        default:
            break
        }
    }

    private func playPCMData(_ data: Data) {
        let frameCount = UInt32(data.count) / 2
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        data.withUnsafeBytes { raw in
            let pcm = raw.bindMemory(to: Int16.self)
            if let floatData = buffer.floatChannelData?[0] {
                for i in 0..<Int(frameCount) { floatData[i] = Float(pcm[i]) / 32768.0 }
            }
        }

        buffer.applyMicroFade()
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    private func restartAudioTap() {
        guard audioEngine.isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        let currentSampleRate = AVAudioSession.sharedInstance().sampleRate
        let newFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: currentSampleRate, channels: 1, interleaved: false)!
        audioConverter = AVAudioConverter(from: newFormat, to: recordingFormat)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: newFormat) { [weak self] buffer, _ in
            self?.processAndSendAudio(buffer: buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("❌ ElevenLabs: failed to restart audio: \(error.localizedDescription)")
        }
    }

    func stopCall() {
        callTimer?.invalidate()
        callTimer = nil
        if let start = callStartTime { lastRecordedDuration = Date().timeIntervalSince(start) }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        webSocket?.cancel(with: .normalClosure, reason: nil)
        isCalling = false
        callStatus = "Disconnected"
        callStartTime = nil
        maxCallDuration = 0
        onCallEnded = nil
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.callStatus = "Configuring..."
            self.sendInitiationData()
        }
    }
}
