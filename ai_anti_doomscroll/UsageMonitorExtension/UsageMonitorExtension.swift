import DeviceActivity
import Foundation
import os
import ManagedSettings
import FamilyControls

struct Todo: Identifiable, Codable {
    let id: Int
    var task: String
}

class UsageMonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(subsystem: "ai_anti_doomscroll", category: "UsageMonitor")
    
    // Store application tokens when interval starts so we can use them when threshold is reached
    // This is stored in memory - will be available during the monitoring session
    private var storedApplicationTokens: Set<ApplicationToken> = []
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        logger.log("🟢 intervalDidStart triggered for \(activity.rawValue, privacy: .public)")
        guard let defaults = UserDefaults(suiteName: Shared.appGroupId) else {
            logger.log("❌ Failed to get UserDefaults with suiteName: \(Shared.appGroupId, privacy: .public)")
            return
        }

        // Read shared values saved by the app
        let baseURL = defaults.string(forKey: Shared.baseURLKey) ?? ""
        let phone   = defaults.string(forKey: Shared.phoneKey) ?? ""
        let minutes = defaults.integer(forKey: Shared.minutesKey)

        logger.log("🔍 Loaded values from UserDefaults:")
        logger.log("   baseURL = \(baseURL, privacy: .public)")
        logger.log("   phone   = \(phone, privacy: .public)")
        logger.log("   minutes = \(minutes, privacy: .public)")
        
        // Ensure shield is cleared when monitoring starts (don't block yet)
        let store = ManagedSettingsStore()
        store.shield.applications = nil
        logger.log("🔄 Shield cleared - apps not blocked yet, waiting for threshold")
        }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        logger.log("🔴 intervalDidEnd triggered for \(activity.rawValue, privacy: .public)")
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        logger.log("📱 Threshold reached for \(event.rawValue, privacy: .public) in \(activity.rawValue, privacy: .public)")
        // Called when user exceeds the configured threshold on the selected tokens
        
        // Block apps immediately when threshold is reached
        blockApps(event: event, activity: activity)
        
        // Note: Removed backend call - we'll add web call later when user requests unblock
    }
    
    // MARK: - App Blocking
    
    private func blockApps(event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        guard let defaults = UserDefaults(suiteName: Shared.appGroupId) else {
            logger.log("❌ Failed to get UserDefaults for blocking")
            return
        }
        
        // 1. Get the encoded selection from App Group
        guard let data = defaults.data(forKey: Shared.selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            logger.log("❌ Failed to decode selection from App Group")
            return
        }
        
        // 2. Apply the shield IMMEDIATELY
        let store = ManagedSettingsStore()
        let tokens = selection.applicationTokens
        
        if !tokens.isEmpty {
            store.shield.applications = tokens
            logger.log("✅ Shield applied IMMEDIATELY for \(tokens.count) apps")
            
            // 3. Store blocked state for the UI
            defaults.set(true, forKey: Shared.isBlockedKey)
            defaults.set(Date().timeIntervalSince1970, forKey: Shared.blockedAtKey)
        } else {
            logger.log("⚠️ Selection was empty, nothing to block")
        }
    }

    private func sendToBackend(reason: String) {
        guard let defaults = UserDefaults(suiteName: Shared.appGroupId) else {
            logger.log("❌ Failed to get UserDefaults with suiteName: \(Shared.appGroupId, privacy: .public)")
            return
        }

        logger.log("   reason = \(reason, privacy: .public)")

        // Read shared values saved by the app
        let baseURL = defaults.string(forKey: Shared.baseURLKey) ?? ""
        let phone   = defaults.string(forKey: Shared.phoneKey) ?? ""
        let minutes = defaults.integer(forKey: Shared.minutesKey)

        // 🔎 Read todos JSON from App Group
        var todos: [Todo] = []
        if let data = defaults.data(forKey: Shared.todosKey) {
            do {
                todos = try JSONDecoder().decode([Todo].self, from: data)
            } catch {
                logger.log("⚠️ Failed to decode todos: \(String(describing: error), privacy: .public)")
            }
        }

        logger.log("🔍 Loaded values from UserDefaults:")
        logger.log("   baseURL = \(baseURL, privacy: .public)")
        logger.log("   phone   = \(phone, privacy: .public)")
        logger.log("   minutes = \(minutes, privacy: .public)")
        logger.log("   todos   = \(todos.count, privacy: .public) items")

        guard !baseURL.isEmpty, !phone.isEmpty,
              let url = URL(string: "\(baseURL)/trigger-call") else {
            logger.log("❌ Missing or invalid URL: baseURL = \(baseURL), phone = \(phone)")
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // ✅ Choose how to send todos:
        // A) full array of objects
        let todosJSON: [[String: Any]] = todos.map { ["id": $0.id, "task": $0.task] }

        // Build payload (include one or both)
        let payload: [String: Any] = [
            "phone": phone,
            "minutes": minutes,
            "todos": todosJSON
        ]

        if let body = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: body, encoding: .utf8) {
            req.httpBody = body
            logger.log("📦 Payload: \(jsonString, privacy: .public)")
        } else {
            logger.log("❌ Failed to serialize payload")
        }

        logger.log("🌐 Sending request to: \(url.absoluteString, privacy: .public)")

        URLSession.shared.dataTask(with: req) { [self] data, response, error in
            if let error = error {
                logger.log("❌ Request error: \(error.localizedDescription, privacy: .public)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                logger.log("✅ Response status: \(httpResponse.statusCode)")
            }
            if let data = data,
               let responseBody = String(data: data, encoding: .utf8) {
                logger.log("📩 Response body: \(responseBody, privacy: .public)")
            }
        }.resume()
    }

}
