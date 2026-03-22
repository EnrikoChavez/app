import DeviceActivity
import Foundation
import os
import ManagedSettings
import FamilyControls


class UsageMonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(subsystem: "ai_anti_doomscroll", category: "UsageMonitor")
    
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

        let warningsEnabled = UserDefaults(suiteName: Shared.appGroupId)?
            .bool(forKey: Shared.warningsEnabledKey) ?? true

        if event.rawValue.hasPrefix("warningThreshold_") && warningsEnabled {
            showWarningShield()
        } else if event.rawValue.hasPrefix("warningThreshold_") {
            // Warnings disabled — ignore this event entirely
            logger.log("ℹ️ Warning event ignored (warnings disabled)")
        } else {
            // Full block — clear warning flag first, then block
            clearWarningShield()
            blockApps()
        }
    }
    
    // MARK: - Warning Shield (translucent, dismissable)

    private func showWarningShield() {
        guard let defaults = UserDefaults(suiteName: Shared.appGroupId),
              let data = defaults.data(forKey: Shared.selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            logger.log("❌ Failed to decode selection for warning shield")
            return
        }

        let appTokens      = selection.applicationTokens
        let categoryTokens = selection.categoryTokens
        let webDomainTokens = selection.webDomainTokens
        let hasAnything = !appTokens.isEmpty || !categoryTokens.isEmpty || !webDomainTokens.isEmpty
        guard hasAnything else { return }

        // Mark this as a warning shield so ShieldConfigurationExtension shows the translucent UI
        defaults.set(true, forKey: Shared.isWarningShieldKey)

        let store = ManagedSettingsStore()
        if !appTokens.isEmpty       { store.shield.applications = appTokens }
        if !categoryTokens.isEmpty  { store.shield.applicationCategories = .specific(categoryTokens) }
        if !webDomainTokens.isEmpty { store.shield.webDomains = webDomainTokens }

        logger.log("⚠️ Warning shield applied — 5 minutes remaining")
    }

    private func clearWarningShield() {
        guard let defaults = UserDefaults(suiteName: Shared.appGroupId) else { return }
        defaults.set(false, forKey: Shared.isWarningShieldKey)
    }

    // MARK: - Full Block Shield

    private func blockApps() {
        guard let defaults = UserDefaults(suiteName: Shared.appGroupId) else {
            logger.log("❌ Failed to get UserDefaults for blocking")
            return
        }
        
        guard let data = defaults.data(forKey: Shared.selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            logger.log("❌ Failed to decode selection from App Group")
            return
        }
        
        let store = ManagedSettingsStore()
        let appTokens       = selection.applicationTokens
        let categoryTokens  = selection.categoryTokens
        let webDomainTokens = selection.webDomainTokens
        let hasAnything = !appTokens.isEmpty || !categoryTokens.isEmpty || !webDomainTokens.isEmpty

        if hasAnything {
            if !appTokens.isEmpty       {
                store.shield.applications = appTokens
                logger.log("✅ Shield applied for \(appTokens.count) apps")
            }
            if !categoryTokens.isEmpty  {
                store.shield.applicationCategories = .specific(categoryTokens)
                logger.log("✅ Shield applied for \(categoryTokens.count) categories")
            }
            if !webDomainTokens.isEmpty {
                store.shield.webDomains = webDomainTokens
                logger.log("✅ Shield applied for \(webDomainTokens.count) web domains")
            }

            defaults.set(true, forKey: Shared.isBlockedKey)
            defaults.set(Date().timeIntervalSince1970, forKey: Shared.blockedAtKey)
        } else {
            logger.log("⚠️ Selection was empty, nothing to block")
        }
    }
}
