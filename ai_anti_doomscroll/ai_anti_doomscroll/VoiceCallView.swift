import SwiftUI

protocol AnyCallManager: ObservableObject {
    var isCalling: Bool { get }
    var callStatus: String { get }
    var transcript: String { get }
    var isMuted: Bool { get set }
    var remainingTime: TimeInterval { get }
    var callDuration: TimeInterval { get }
    func stopCall()
}

struct VoiceCallView<Manager: AnyCallManager>: View {
    @ObservedObject var callManager: Manager
    var onHangUp: () -> Void

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .opacity(isPulsing ? 0.0 : 1.0)

                Circle()
                    .fill(Color.blue)
                    .frame(width: 100, height: 100)

                Image(systemName: "phone")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white)
            }
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }

            VStack(spacing: 8) {
                Text("AI Companion Session")
                    .font(.title2).bold()
                Text(callManager.callStatus)
                    .foregroundColor(.secondary)

                if callManager.isCalling && callManager.remainingTime > 0 {
                    Text("\(Int(callManager.remainingTime))s remaining")
                        .font(.caption)
                        .foregroundColor(callManager.remainingTime <= 10 ? .orange : .secondary)
                        .padding(.top, 4)
                }
            }

            ScrollView {
                Text(callManager.transcript.isEmpty ? "AI is listening..." : callManager.transcript)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .foregroundColor(.secondary)
            }
            .frame(maxHeight: 250)

            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "speaker.wave.2")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("AI interrupts itself on speaker mode, to help prevent, use headphones, mute, or lower volume. Try restarting call if you don't hear audio.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 24)

            Spacer()

            HStack(spacing: 60) {
                Button(action: { callManager.isMuted.toggle() }) {
                    VStack {
                        Image(systemName: callManager.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.title)
                            .padding()
                            .background(Circle().fill(callManager.isMuted ? Color.red.opacity(0.1) : Color(.systemGray5)))
                            .foregroundColor(callManager.isMuted ? .red : .primary)
                        Text(callManager.isMuted ? "Unmute" : "Mute").font(.caption)
                    }
                }

                Button(action: {
                    callManager.stopCall()
                    onHangUp()
                }) {
                    VStack {
                        Image(systemName: "phone.down.fill")
                            .font(.title)
                            .padding()
                            .background(Circle().fill(Color.red))
                            .foregroundColor(.white)
                        Text("End Call").font(.caption)
                    }
                }
            }
            .padding(.bottom, 50)
        }
        .padding()
    }
}

#Preview {
    VoiceCallView(callManager: HumeCallManager(), onHangUp: {})
}
