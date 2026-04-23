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
    @State private var showFilePicker = false
    @State private var pickedFileURL: URL? = nil
    @AppStorage("useClonedVoice") private var useClonedVoice = false

    var activeFileURL: URL? { pickedFileURL ?? recorder.recordedFileURL }

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
        .sheet(isPresented: $showFilePicker) {
            AudioFilePicker { url in
                pickedFileURL = url
                recorder.recordedFileURL = nil
            }
        }
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

                Toggle("Use my cloned voice in calls", isOn: $useClonedVoice)
                    .font(.subheadline)

                HStack(spacing: 12) {
                    Button("Re-clone") {
                        networkManager.showReclone = true
                        recorder.recordedFileURL = nil
                        pickedFileURL = nil
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
                            useClonedVoice = false
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
                        Text("Recording... \(recorder.durationString)")
                            .font(.subheadline).foregroundColor(.red)
                        Spacer()
                    }

                    if recorder.duration > 180 {
                        Text("Max 3 minutes — stop recording now")
                            .font(.caption).foregroundColor(.orange)
                    }

                    Button(action: {
                        recorder.stopRecording()
                        pickedFileURL = nil
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
                                    pickedFileURL = nil
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

                    Button(action: { showFilePicker = true }) {
                        Label("Upload Audio File", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }

                if let url = activeFileURL {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text(url == pickedFileURL ? "File selected: \(url.lastPathComponent)" : "Recorded: \(recorder.durationString)")
                            .font(.caption)
                        Spacer()
                        Button(action: {
                            recorder.recordedFileURL = nil
                            pickedFileURL = nil
                        }) {
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

            Text("By uploading this audio sample, you confirm that:\n• You are the speaker, or have explicit consent from the speaker to clone this voice\n• You agree to ElevenLabs' Terms of Service and usage policies\n• This voice will only be used within this app")
                .font(.caption)
                .foregroundColor(.secondary)

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
                    useClonedVoice = true
                    networkManager.showReclone = false
                    recorder.recordedFileURL = nil
                    pickedFileURL = nil
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

// MARK: - Audio File Picker

struct AudioFilePicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.audio, .mp3, .wav, UTType("public.aiff-audio")!, UTType("com.apple.m4a-audio")!].compactMap { $0 }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: tmp)
            url.stopAccessingSecurityScopedResource()
            onPick(tmp)
        }
    }
}

import UniformTypeIdentifiers
