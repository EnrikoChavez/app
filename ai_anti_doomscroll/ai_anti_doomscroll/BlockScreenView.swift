//
//  BlockScreenView.swift
//  ai_anti_doomscroll
//
//  Shows when apps are blocked and provides option to unblock
//

import SwiftUI

struct BlockScreenView: View {
    @Binding var isBlocked: Bool
    let blockedAt: Date?
    let onUnblock: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Blocked icon
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            // Title
            Text("Apps Blocked")
                .font(.largeTitle)
                .bold()
            
            // Message
            VStack(spacing: 8) {
                Text("You've exceeded your screen time limit.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                
                if let blockedAt = blockedAt {
                    Text("Blocked at: \(blockedAt, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Unblock button
            Button {
                onUnblock()
            } label: {
                Text("Unblock Apps")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    BlockScreenView(
        isBlocked: .constant(true),
        blockedAt: Date(),
        onUnblock: {}
    )
}
