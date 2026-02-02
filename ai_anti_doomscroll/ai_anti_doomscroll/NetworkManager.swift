// NetworkManager.swift
import Foundation

final class NetworkManager {
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 20
        cfg.timeoutIntervalForResource = 40
        return URLSession(configuration: cfg)
    }()

    private var phoneHeader: String {
        UserDefaults.standard.string(forKey: "userPhone") ?? "123"
    }

    private func makeRequest(path: String,
                             method: String = "GET",
                             jsonBody: Any? = nil,
                             extraHeaders: [String:String] = [:]) -> URLRequest? {
        guard let url = APIConfig.url(path) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !phoneHeader.isEmpty {
            req.setValue(phoneHeader, forHTTPHeaderField: "x-phone")
        }
        extraHeaders.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        if let jsonBody = jsonBody {
            req.httpBody = try? JSONSerialization.data(withJSONObject: jsonBody)
        }
        return req
    }

    func fetchTodos(phone: String, completion: @escaping (Result<[Todo], Error>) -> Void) {
        guard let req = makeRequest(path: "/todos") else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        session.dataTask(with: req) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let decoded = try? JSONDecoder().decode([String: [Todo]].self, from: data),
                  let todos = decoded["todos"] else {
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            completion(.success(todos))
        }.resume()
    }

    func addTodo(_ task: String, phone: String, appleId: String?, completion: @escaping (Result<Todo, Error>) -> Void) {
        var body: [String: Any] = ["task": task]
        if let appleId = appleId, !appleId.isEmpty {
            body["apple_id"] = appleId
        }
        guard let req = makeRequest(path: "/todos", method: "POST", jsonBody: body) else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        session.dataTask(with: req) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data returned"])))
                return
            }
            
            // Backend returns: {"message": "...", "todo": {...}}
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let todoDict = json["todo"] as? [String: Any] {
                    // Decode the todo object
                    let todoData = try JSONSerialization.data(withJSONObject: todoDict)
                    let todo = try JSONDecoder().decode(Todo.self, from: todoData)
                    completion(.success(todo))
                } else {
                    completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
            } catch {
                print("❌ Failed to decode addTodo response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateTodo(_ id: Int, task: String, phone: String, appleId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        var body: [String: Any] = ["task": task]
        if let appleId = appleId, !appleId.isEmpty {
            body["apple_id"] = appleId
        }
        guard let req = makeRequest(path: "/todos/\(id)", method: "PUT", jsonBody: body) else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        session.dataTask(with: req) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Check status code
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    completion(.success(()))
                } else {
                    let errorMsg = "Update failed with status: \(httpResponse.statusCode)"
                    completion(.failure(NSError(domain: "NetworkManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                }
            } else {
                completion(.success(()))
            }
        }.resume()
    }

    func deleteTodo(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let req = makeRequest(path: "/todos/\(id)", method: "DELETE") else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        session.dataTask(with: req) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }.resume()
    }

    func createHumeSession(todos: [Todo], minutes: Int, completion: @escaping (Result<[String: String], Error>) -> Void) {
        let todoData = todos.map { ["task": $0.task, "id": $0.id] }
        guard let req = makeRequest(path: "/hume/create-session", method: "POST", jsonBody: ["todos": todoData, "minutes": minutes]) else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        
        print("📡 iOS: Sending /hume/create-session request...")
        session.dataTask(with: req) { data, response, error in
            if let error = error {
                print("❌ iOS Network Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ iOS Error: No data returned from server")
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data returned"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    var result: [String: String] = [:]
                    if let wsURL = json["websocket_url"] as? String { result["websocket_url"] = wsURL }
                    if let vars = json["initial_variables"] as? [String: Any],
                       let varsData = try? JSONSerialization.data(withJSONObject: vars),
                       let varsString = String(data: varsData, encoding: .utf8) {
                        result["initial_variables"] = varsString
                    }
                    print("✅ iOS: Received Hume session details")
                    completion(.success(result))
                } else {
                    completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func evaluateTranscript(transcript: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let req = makeRequest(path: "/hume/evaluate-transcript", method: "POST", jsonBody: ["transcript": transcript]) else { return }
        session.dataTask(with: req) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            completion(.success(json))
        }.resume()
    }
    
    // Premium Status Sync
    func syncPremiumStatus(isPremium: Bool, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let req = makeRequest(path: "/profile/sync-premium", method: "POST", jsonBody: ["is_premium": isPremium]) else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        session.dataTask(with: req) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let isPremium = json["is_premium"] as? Bool else {
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            completion(.success(isPremium))
        }.resume()
    }
    
    func getPremiumStatus(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let req = makeRequest(path: "/profile/premium-status") else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        session.dataTask(with: req) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let isPremium = json["is_premium"] as? Bool else {
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            completion(.success(isPremium))
        }.resume()
    }
    
    // Call limit checking and recording
    func checkCallLimit(completion: @escaping (Result<CallLimitInfo, Error>) -> Void) {
        guard let req = makeRequest(path: "/call-usage/check-limit") else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        session.dataTask(with: req) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            let canCall = json["can_call"] as? Bool ?? false
            let remaining = json["remaining_seconds"] as? Double ?? 0.0
            let used = json["used_seconds"] as? Double ?? 0.0
            let limit = json["limit_seconds"] as? Double ?? 60.0
            
            completion(.success(CallLimitInfo(canCall: canCall, remainingSeconds: remaining, usedSeconds: used, limitSeconds: limit)))
        }.resume()
    }
    
    func recordCallDuration(durationSeconds: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let req = makeRequest(path: "/call-usage/record-duration", method: "POST", jsonBody: ["duration_seconds": durationSeconds]) else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        session.dataTask(with: req) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }.resume()
    }
    
    // Manual unblock limit checking and recording
    func checkManualUnblockLimit(completion: @escaping (Result<ManualUnblockLimitInfo, Error>) -> Void) {
        guard let req = makeRequest(path: "/manual-unblock/check-limit") else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        session.dataTask(with: req) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            let canUnblock = json["can_unblock"] as? Bool ?? false
            let remaining = json["remaining_count"] as? Int ?? 0
            let used = json["used_count"] as? Int ?? 0
            let limit = json["limit_count"] as? Int ?? 10
            
            completion(.success(ManualUnblockLimitInfo(canUnblock: canUnblock, remainingCount: remaining, usedCount: used, limitCount: limit)))
        }.resume()
    }
    
    func recordManualUnblock(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let req = makeRequest(path: "/manual-unblock/record", method: "POST") else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        session.dataTask(with: req) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }.resume()
    }
    
    // Chat methods
    func sendChatMessage(message: String, todos: [String], isNewConversation: Bool, completion: @escaping (Result<ChatResponse, Error>) -> Void) {
        guard let req = makeRequest(path: "/chat/message", method: "POST", jsonBody: [
            "message": message,
            "todos": todos,
            "is_new_conversation": isNewConversation
        ]) else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        
        session.dataTask(with: req) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            guard let responseText = json["response"] as? String else {
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "No response text"])))
                return
            }
            
            let conversationEnded = json["conversation_ended"] as? Bool ?? false
            
            completion(.success(ChatResponse(response: responseText, conversationEnded: conversationEnded)))
        }.resume()
    }
    
    func endChatConversation(completion: @escaping (Result<String, Error>) -> Void) {
        guard let req = makeRequest(path: "/chat/end", method: "POST") else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        
        session.dataTask(with: req) { data, response, error in
            if let error = error {
                print("❌ iOS: endChatConversation network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ iOS: endChatConversation - invalid response type")
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])))
                return
            }
            
            print("📱 iOS: endChatConversation status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 404 {
                print("⚠️ iOS: No active conversation found (404)")
                completion(.failure(NSError(domain: "NetworkManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active conversation found"])))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                let responseBody = data.map { String(data: $0, encoding: .utf8) ?? "N/A" } ?? "N/A"
                print("❌ iOS: endChatConversation server error (\(httpResponse.statusCode)): \(responseBody)")
                completion(.failure(NSError(domain: "NetworkManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode) - \(responseBody)"])))
                return
            }
            
            guard let data = data else {
                print("❌ iOS: endChatConversation - no data in response")
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data in response"])))
                return
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "N/A"
            print("📱 iOS: endChatConversation response: \(responseString)")
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ iOS: endChatConversation - failed to parse JSON. Response: \(responseString)")
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON response: \(responseString)"])))
                return
            }
            
            guard let transcript = json["transcript"] as? String else {
                print("❌ iOS: endChatConversation - no 'transcript' field in response. JSON: \(json)")
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "No 'transcript' field in response. Response: \(json)"])))
                return
            }
            
            print("✅ iOS: endChatConversation success. Transcript length: \(transcript.count)")
            completion(.success(transcript))
        }.resume()
    }
    
    func cancelChatConversation(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let req = makeRequest(path: "/chat/cancel", method: "DELETE") else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        
        session.dataTask(with: req) { _, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }.resume()
    }
    
    // Account management
    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let req = makeRequest(path: "/account/delete", method: "DELETE") else {
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Request build failed"])))
            return
        }
        
        session.dataTask(with: req) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                completion(.success(()))
            } else {
                let responseBody = data.map { String(data: $0, encoding: .utf8) ?? "N/A" } ?? "N/A"
                completion(.failure(NSError(domain: "NetworkManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode) - \(responseBody)"])))
            }
        }.resume()
    }
}

struct CallLimitInfo {
    let canCall: Bool
    let remainingSeconds: Double
    let usedSeconds: Double
    let limitSeconds: Double
}

struct ManualUnblockLimitInfo {
    let canUnblock: Bool
    let remainingCount: Int
    let usedCount: Int
    let limitCount: Int
}

struct ChatResponse {
    let response: String
    let conversationEnded: Bool
}
