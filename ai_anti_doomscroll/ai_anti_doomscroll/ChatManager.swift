//
//  ChatManager.swift
//  ai_anti_doomscroll
//

import Foundation
import Combine

class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isChatting = false
    @Published var isLoading = false
    @Published var conversationEnded = false
    
    private let networkManager = NetworkManager()
    private var phone: String {
        UserDefaults.standard.string(forKey: "userPhone") ?? ""
    }
    
    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: MessageRole
        let content: String
        let timestamp: Date
        
        enum MessageRole {
            case user
            case assistant
        }
    }
    
    func startChat(todos: [Todo]) {
        messages = []
        isChatting = true
        conversationEnded = false
        wasCancelled = false
        
        // Add welcome message
        let welcomeMessage = ChatMessage(
            role: .assistant,
            content: "I see you have some tasks to complete. Let's talk about them. What have you been up to?",
            timestamp: Date()
        )
        messages.append(welcomeMessage)
    }
    
    func sendMessage(_ text: String, todos: [Todo], completion: @escaping (Result<String, Error>) -> Void) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add user message to UI immediately
        let userMessage = ChatMessage(
            role: .user,
            content: text,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        isLoading = true
        
        // Check if this is a new conversation (first message)
        let isNewConversation = messages.filter { $0.role == .user }.count == 1
        
        // Get todo tasks as strings
        let todoTasks = todos.map { $0.task }
        
        networkManager.sendChatMessage(
            message: text,
            todos: todoTasks,
            isNewConversation: isNewConversation
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let response):
                    // Add AI response to UI
                    let aiMessage = ChatMessage(
                        role: .assistant,
                        content: response.response,
                        timestamp: Date()
                    )
                    self?.messages.append(aiMessage)
                    
                    // Check if conversation ended
                    if response.conversationEnded {
                        self?.conversationEnded = true
                    }
                    
                    completion(.success(response.response))
                    
                case .failure(let error):
                    print("❌ Chat error: \(error.localizedDescription)")
                    // Add error message
                    let errorMessage = ChatMessage(
                        role: .assistant,
                        content: "Sorry, I encountered an error. Please try again.",
                        timestamp: Date()
                    )
                    self?.messages.append(errorMessage)
                    completion(.failure(error))
                }
            }
        }
    }
    
    func endConversation(completion: @escaping (Result<String, Error>) -> Void) {
        print("📱 ChatManager: Ending conversation...")
        
        // Build transcript from local messages if backend fails
        let localTranscript = messages.map { msg in
            let role = msg.role == .user ? "You" : "AI"
            return "\(role): \(msg.content)"
        }.joined(separator: "\n")
        
        networkManager.endChatConversation { [weak self] result in
            DispatchQueue.main.async {
                self?.isChatting = false
                
                switch result {
                case .success(let transcript):
                    print("✅ ChatManager: Got transcript from backend")
                    completion(.success(transcript))
                case .failure(let error):
                    let nsError = error as NSError
                    if nsError.code == 404 {
                        // No conversation on backend, use local transcript
                        print("⚠️ ChatManager: No backend conversation, using local transcript")
                        if !localTranscript.isEmpty {
                            completion(.success(localTranscript))
                        } else {
                            completion(.failure(error))
                        }
                    } else {
                        print("❌ ChatManager: Error ending conversation: \(error.localizedDescription)")
                        // Try to use local transcript as fallback
                        if !localTranscript.isEmpty {
                            print("📱 ChatManager: Using local transcript as fallback")
                            completion(.success(localTranscript))
                        } else {
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
    }
    
    @Published var wasCancelled = false
    
    func cancelConversation() {
        wasCancelled = true
        networkManager.cancelChatConversation { [weak self] _ in
            DispatchQueue.main.async {
                self?.isChatting = false
                self?.messages = []
                self?.conversationEnded = false
            }
        }
    }
}
