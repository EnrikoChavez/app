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

    func fetchTodos(completion: @escaping ([Todo]) -> Void) {
        guard let req = makeRequest(path: "/todos") else { completion([]); return }
        session.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let decoded = try? JSONDecoder().decode([String:[Todo]].self, from: data),
                  let todos = decoded["todos"] else {
                completion([]); return
            }
            completion(todos)
        }.resume()
    }

    func addTodo(_ task: String, completion: @escaping ([Todo]) -> Void) {
        guard let req = makeRequest(path: "/todos", method: "POST", jsonBody: ["task": task]) else { return }
        session.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let decoded = try? JSONDecoder().decode([String:[Todo]].self, from: data),
                  let todos = decoded["todos"] else { completion([]); return }
            completion(todos)
        }.resume()
    }

    func deleteTodo(id: Int, completion: @escaping ([Todo]) -> Void) {
        guard let req = makeRequest(path: "/todos/\(id)", method: "DELETE") else { return }
        session.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let decoded = try? JSONDecoder().decode([String:[Todo]].self, from: data),
                  let todos = decoded["todos"] else { completion([]); return }
            completion(todos)
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
}
