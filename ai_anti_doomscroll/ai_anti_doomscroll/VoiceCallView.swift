//
//  VoiceCallView.swift
//  ai_anti_doomscroll
//

import SwiftUI

struct VoiceCallView: View {
    @ObservedObject var callManager: HumeCallManager
    var accessToken: String?  // Kept for compatibility but not used with Hume
    var onHangUp: () -> Void
    
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // AI Avatar / Pulsing Circle
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .opacity(isPulsing ? 0.0 : 1.0)
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "brain.head.profile")
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
                Text("AI Coaching Session")
                    .font(.title2).bold()
                Text(callManager.callStatus)
                    .foregroundColor(.secondary)
                
                // Show remaining time if call is active
                if callManager.isCalling && callManager.remainingTime > 0 {
                    Text("\(Int(callManager.remainingTime))s remaining")
                        .font(.caption)
                        .foregroundColor(callManager.remainingTime <= 10 ? .orange : .secondary)
                        .padding(.top, 4)
                }
            }
            
            // Real-time Transcript
            ScrollView {
                Text(callManager.transcript.isEmpty ? "AI is listening..." : callManager.transcript)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .foregroundColor(.secondary)
            }
            .frame(maxHeight: 150)
            
            Spacer()
            
            // Controls
            HStack(spacing: 60) {
                Button(action: {
                    callManager.isMuted.toggle()
                }) {
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
                    // Get call duration BEFORE stopCall() resets it
                    let duration = callManager.callDuration
                    print("📱 VoiceCallView: Call duration before stop: \(duration)s")
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
