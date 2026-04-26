import SwiftUI
import AVFoundation

class VoiceRecorderManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordedFileURL: URL? = nil
    @Published var duration: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func startRecording() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice_sample_\(Date().timeIntervalSince1970).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.record()
            isRecording = true
            recordedFileURL = nil
            duration = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.duration += 1
            }
        } catch {
            print("❌ Recording failed: \(error)")
        }
    }

    func stopRecording() {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        recordedFileURL = recorder?.url
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag { recordedFileURL = recorder.url }
    }

    var durationString: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct VoiceCloneView: View {
    @StateObject private var recorder = VoiceRecorderManager()
    @StateObject private var networkManager = VoiceCloneNetworkManager()
    @Environment(\.colorScheme) private var colorScheme

    @State private var consentGiven = false
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    @State private var showDeleteConfirm = false
    @AppStorage("userHasClonedVoice") private var userHasClonedVoice = false

    private let sampleText = """
        There's something really nice about a slow morning walk. The trees are doing their thing, the birds are being a little dramatic about it — honestly, one of them was way too excited about a worm — and somewhere nearby a river is just quietly minding its own business. Good for the river! I think we could all learn something from that. Just flowing along, not making a big deal out of anything, maybe stopping to enjoy a flower or two along the way. The air smells different in the morning, kind of fresh and a little earthy, like the whole world just woke up and hasn't checked its phone yet. That's the best part, really — just being outside, no rush, nowhere specific to be, just walking and noticing things. A good leaf here, a nice cloud there. Simple stuff. The best stuff.
        """

    var activeFileURL: URL? { recorder.recordedFileURL }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status card
                statusCard
                    .padding(.horizontal)
                    .padding(.top, 20)

                // Clone your voice card (only if no clone yet, or re-cloning)
                if !networkManager.hasClonedVoice || networkManager.showReclone {
                    cloneCard
                        .padding(.horizontal)
                }

                // Consent
                if !networkManager.hasClonedVoice || networkManager.showReclone {
                    consentCard
                        .padding(.horizontal)
                }

                if let error = uploadError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color.clear.ignoresSafeArea())
        .onAppear { networkManager.loadStatus() }
    }

    // MARK: - Status Card

    var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Voice for Calls")
                .font(.title3).bold()

            if networkManager.isLoading {
                HStack { ProgressView(); Text("Checking status...").foregroundColor(.secondary) }
            } else if networkManager.hasClonedVoice {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cloned voice active")
                            .font(.subheadline).bold()
                        Text("Your voice is used for AI calls")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    Button("Re-clone") {
                        networkManager.showReclone = true
                        recorder.recordedFileURL = nil
                        consentGiven = false
                    }
                    .font(.caption).bold()
                    .foregroundColor(.blue)

                    Button("Delete Voice") { showDeleteConfirm = true }
                        .font(.caption).bold()
                        .foregroundColor(.red)
                }
                .confirmationDialog("Delete your cloned voice?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        networkManager.deleteVoice {
                            userHasClonedVoice = false
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No cloned voice")
                            .font(.subheadline).bold()
                        Text("Preset voices used — clone yours below")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(AppTheme.cardBg(for: colorScheme))
        .cornerRadius(20)
        .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    // MARK: - Clone Card

    var cloneCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Clone Your Voice")
                    .font(.title3).bold()
                Text("Record or upload 1–2 minutes of clear speech. No background noise.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Record section
            VStack(spacing: 12) {
                if recorder.isRecording {
                    HStack {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                            .opacity(recorder.duration.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0.3)
                        Text("Recording... \(recorder.durationString)")
                            .font(.subheadline).bold().foregroundColor(.red)
                        Spacer()
                        if recorder.duration >= 30 {
                            Text("✓ Enough!")
                                .font(.caption).bold()
                                .foregroundColor(.green)
                        }
                    }

                    // Sample text to read aloud
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.quote")
                                .font(.caption).foregroundColor(.blue)
                            Text("Read this aloud:")
                                .font(.caption).bold().foregroundColor(.blue)
                        }
                        Text(sampleText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.2), lineWidth: 1))

                    if recorder.duration > 180 {
                        Text("Max 3 minutes — stop recording now")
                            .font(.caption).foregroundColor(.orange)
                    }

                    Button(action: {
                        recorder.stopRecording()
                    }) {
                        Label("Stop Recording", systemImage: "stop.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                } else {
                    Button(action: {
                        AVAudioSession.sharedInstance().requestRecordPermission { granted in
                            DispatchQueue.main.async {
                                if granted {
                                    recorder.startRecording()
                                } else {
                                    uploadError = "Microphone permission denied. Enable in Settings."
                                }
                            }
                        }
                    }) {
                        Label("Record Sample", systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    // Sample text preview so user can read it before hitting record
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.quote")
                                .font(.caption).foregroundColor(.secondary)
                            Text("You'll read this when recording:")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Text(sampleText)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                if activeFileURL != nil {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("Recorded: \(recorder.durationString)")
                            .font(.caption)
                        Spacer()
                        Button(action: { recorder.recordedFileURL = nil }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(8)

                    if recorder.duration > 0 && recorder.duration < 30 {
                        Text("⚠️ At least 30 seconds recommended for a good clone")
                            .font(.caption).foregroundColor(.orange)
                    }
                }
            }

            if activeFileURL != nil && consentGiven {
                Button(action: uploadVoice) {
                    if isUploading {
                        HStack { ProgressView().tint(.white); Text("Cloning...") }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    } else {
                        Label("Create My Voice", systemImage: "waveform.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .disabled(isUploading)
            }
        }
        .padding(20)
        .background(AppTheme.cardBg(for: colorScheme))
        .cornerRadius(20)
        .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    // MARK: - Consent Card

    var consentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Consent")
                .font(.subheadline).bold()

            VStack(alignment: .leading, spacing: 6) {
                Text("By recording this sample, you confirm that:")
                    .font(.caption).foregroundColor(.secondary)
                Text("• You are the speaker and consent to cloning your own voice")
                    .font(.caption).foregroundColor(.secondary)
                Text("• This voice will only be used within this app")
                    .font(.caption).foregroundColor(.secondary)
                HStack(spacing: 0) {
                    Text("• You agree to ElevenLabs' ")
                        .font(.caption).foregroundColor(.secondary)
                    Link("Terms of Service & Usage Policy", destination: URL(string: "https://elevenlabs.io/terms-of-use")!)
                        .font(.caption).bold()
                }
            }

            Toggle(isOn: $consentGiven) {
                Text("I confirm I have the right to clone this voice")
                    .font(.caption).bold()
            }
            .toggleStyle(CheckboxToggleStyle())
        }
        .padding(16)
        .background(AppTheme.cardBg(for: colorScheme))
        .cornerRadius(16)
        .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    // MARK: - Actions

    private func uploadVoice() {
        guard let fileURL = activeFileURL else { return }
        isUploading = true
        uploadError = nil

        networkManager.cloneVoice(fileURL: fileURL) { result in
            DispatchQueue.main.async {
                isUploading = false
                switch result {
                case .success:
                    userHasClonedVoice = true
                    networkManager.showReclone = false
                    recorder.recordedFileURL = nil
                    consentGiven = false
                case .failure(let error):
                    uploadError = "Clone failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Checkbox style

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? .blue : .secondary)
                    .font(.body)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Network Manager for Voice Clone

class VoiceCloneNetworkManager: ObservableObject {
    @Published var hasClonedVoice = false
    @Published var isLoading = false
    @Published var showReclone = false

    private let session = URLSession.shared

    func loadStatus() {
        isLoading = true
        guard let url = APIConfig.url("/voice/status") else { isLoading = false; return }
        var req = URLRequest(url: url)
        if let token = KeychainHelper.getToken() { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        session.dataTask(with: req) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                self?.isLoading = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                self?.hasClonedVoice = json["has_cloned_voice"] as? Bool ?? false
            }
        }.resume()
    }

    func cloneVoice(fileURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = APIConfig.url("/voice/clone") else { return }

        guard let audioData = try? Data(contentsOf: fileURL) else {
            completion(.failure(NSError(domain: "VoiceClone", code: 400, userInfo: [NSLocalizedDescriptionKey: "Could not read audio file"])))
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let token = KeychainHelper.getToken() { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let filename = fileURL.lastPathComponent
        let mimeType = filename.hasSuffix(".mp3") ? "audio/mpeg" : filename.hasSuffix(".wav") ? "audio/wav" : "audio/m4a"

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
        body.append("My Voice\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        var uploadReq = req
        uploadReq.timeoutInterval = 60

        session.dataTask(with: uploadReq) { [weak self] data, response, error in
            if let error = error { completion(.failure(error)); return }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let msg = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                completion(.failure(NSError(domain: "VoiceClone", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])))
                return
            }
            DispatchQueue.main.async { self?.hasClonedVoice = true }
            completion(.success(()))
        }.resume()
    }

    func deleteVoice(completion: @escaping () -> Void) {
        guard let url = APIConfig.url("/voice/clone") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        if let token = KeychainHelper.getToken() { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        session.dataTask(with: req) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.hasClonedVoice = false
                self?.showReclone = false
                completion()
            }
        }.resume()
    }
}

