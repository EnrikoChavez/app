import DeviceActivity
import Foundation
import os
import ManagedSettings
import FamilyControls


class UsageMonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(subsystem: "ai_anti_doomscroll", category: "UsageMonitor")
    
    // Store application tokens when interval starts so we can use them when threshold is reached
    // This is stored in memory - will be available during the monitoring session
    private var storedApplicationTokens: Set<ApplicationToken> = []
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        logger.log("🟢 intervalDidStart triggered for \(activity.rawValue, privacy: .public)")
        // Block intentionally NOT cleared here — if the user was blocked yesterday
        // they stay blocked until they talk to the AI and get manually unblocked.
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


}
