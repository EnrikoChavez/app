//
//  ChatView.swift
//  ai_anti_doomscroll
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var chatManager: ChatManager
    var todos: [Todo]
    var onEndChat: () -> Void
    
    @State private var messageText = ""
    @State private var wasCancelled = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Chat")
                        .font(.headline)
                    Text("Convince me you finished your tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    wasCancelled = true
                    chatManager.cancelConversation()
                    onEndChat()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(chatManager.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if chatManager.isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("AI is thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding()
                }
                .onChange(of: chatManager.messages.count) { _ in
                    if let lastMessage = chatManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input area
            VStack(spacing: 8) {
                // Always show input field
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            TextField("Type your message...", text: $messageText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(1...5)
                                .focused($isTextFieldFocused)
                                .onSubmit {
                                    sendMessage()
                                }
                            
                            Button(action: sendMessage) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                            }
                            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatManager.isLoading)
                        }
                        .padding(.horizontal)
                        
                        // Character count (invisible unless approaching limit)
                        if messageText.count > 2500 {
                            HStack {
                                Spacer()
                                Text("\(messageText.count)/3000")
                                    .font(.caption2)
                                    .foregroundColor(messageText.count >= 3000 ? .red : .secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 8)
                
                // Always show End Conversation button
                Button(action: {
                    handleEndConversation()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("End Conversation & Evaluate")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(chatManager.conversationEnded ? Color.blue : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Enforce character limit client-side (backend also enforces)
        if text.count > 3000 {
            // Truncate to 3000 characters
            let truncated = String(text.prefix(3000))
            messageText = truncated
            return
        }
        
        messageText = ""
        isTextFieldFocused = false
        
        chatManager.sendMessage(text, todos: todos) { result in
            switch result {
            case .success:
                // Message added to UI by ChatManager
                break
            case .failure(let error):
                print("Failed to send message: \(error.localizedDescription)")
                // Error is handled silently - user can try again
            }
        }
        
        // Refocus after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTextFieldFocused = true
        }
    }
    
    private func handleEndConversation() {
        wasCancelled = false // Mark as properly ended, not cancelled
        chatManager.endConversation { result in
            switch result {
            case .success(let transcript):
                // Transcript will be evaluated in ContentView's handleChatEnd
                onEndChat()
            case .failure(let error):
                print("Failed to end conversation: \(error.localizedDescription)")
                onEndChat() // Still close the view even if there's an error
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatManager.ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user
                            ? Color.blue
                            : Color(.systemGray5)
                    )
                    .foregroundColor(
                        message.role == .user
                            ? .white
                            : .primary
                    )
                    .cornerRadius(18)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 50)
            }
        }
    }
}

#Preview {
    ChatView(
        chatManager: ChatManager(),
        todos: [],
        onEndChat: {}
    )
}
