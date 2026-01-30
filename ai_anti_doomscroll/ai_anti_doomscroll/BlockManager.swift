//
//  BlockManager.swift
//  ai_anti_doomscroll
//
//  Manages app blocking using ManagedSettings.Shield
//

import Foundation
import ManagedSettings
import FamilyControls

#if canImport(FamilyControls)
import FamilyControls
#endif

@available(iOS 16.0, *)
class BlockManager {
    static let shared = BlockManager()
    
    private let store = ManagedSettingsStore()
    
    private init() {}
    
    // MARK: - Block Apps
    
    /// Block the selected apps using ManagedSettings.Shield
    func blockApps(_ selection: FamilyActivitySelection) {
        guard let defaults = UserDefaults(suiteName: Shared.appGroupId) else {
            print("❌ BlockManager: Failed to get UserDefaults")
            return
        }
        
        // Extract application tokens from selection
        let applicationTokens = selection.applicationTokens
        
        guard !applicationTokens.isEmpty else {
            print("⚠️ BlockManager: No apps selected to block")
            return
        }
        
        // Apply shield to block apps
        store.shield.applications = applicationTokens
        
        // Store blocked state
        defaults.set(true, forKey: Shared.isBlockedKey)
        defaults.set(Date().timeIntervalSince1970, forKey: Shared.blockedAtKey)
        
        // Note: Cannot store ApplicationToken directly (not Codable, no rawValue)
        // The tokens are already applied via shield
        
        print("✅ BlockManager: Blocked \(applicationTokens.count) apps")
    }
    
    /// Block apps using application tokens directly
    func blockApps(tokens: Set<ApplicationToken>) {
        guard let defaults = UserDefaults(suiteName: Shared.appGroupId) else {
            print("❌ BlockManager: Failed to get UserDefaults")
            return
        }
        
        guard !tokens.isEmpty else {
            print("⚠️ BlockManager: No app tokens provided")
            return
        }
        
        // Apply shield to block apps
        store.shield.applications = tokens
        
        // Store blocked state
        defaults.set(true, forKey: Shared.isBlockedKey)
        defaults.set(Date().timeIntervalSince1970, forKey: Shared.blockedAtKey)
        
        // Note: Cannot store ApplicationToken directly (not Codable)
        // The tokens are already applied via shield
        
        print("✅ BlockManager: Blocked \(tokens.count) apps")
    }
    
    // MARK: - Unblock Apps
    
    /// Remove shield to unblock all apps
    func unblockApps() {
        print("🛡️ BlockManager: Requesting shield removal...")
        guard let defaults = UserDefaults(suiteName: Shared.appGroupId) else {
            print("❌ BlockManager: Failed to get UserDefaults")
            return
        }
        
        // Remove shield
        store.shield.applications = nil
        print("🛡️ BlockManager: store.shield.applications set to nil")
        
        // Clear blocked state
        defaults.set(false, forKey: Shared.isBlockedKey)
        defaults.removeObject(forKey: Shared.blockedAtKey)
        defaults.removeObject(forKey: Shared.blockedAppsKey)
        
        print("✅ BlockManager: Unblocked all apps")
    }
    
    // MARK: - Check Block Status
    
    /// Check if apps are currently blocked
    var isBlocked: Bool {
        guard let defaults = UserDefaults(suiteName: Shared.appGroupId) else {
            return false
        }
        return defaults.bool(forKey: Shared.isBlockedKey)
    }
    
    /// Get the date when apps were blocked
    var blockedAt: Date? {
        guard let defaults = UserDefaults(suiteName: Shared.appGroupId) else {
            return nil
        }
        let timestamp = defaults.double(forKey: Shared.blockedAtKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    /// Get currently blocked application tokens
    var blockedApplicationTokens: Set<ApplicationToken> {
        return store.shield.applications ?? []
    }
}
