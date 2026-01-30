// Shared.swift
import Foundation
import Combine
import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

// MARK: - App Group & shared keys
enum Shared {
    /// ⚠️ Change to your real App Group ID and enable App Groups in both targets
    static let appGroupId = "group.OrgIdentifier.ai-anti-doomscroll"

    /// Shared UserDefaults (App Group)
    static let defaults = UserDefaults(suiteName: appGroupId)!

    // Keys used by ContentView / NetworkManager
    static let selectionKey = "fc.selection"   // selection persistence (no-op wrapper below)
    static let minutesKey   = "fc.minutes"     // threshold minutes for monitoring
    static let phoneKey     = "userPhone"      // saved after OTP
    static let baseURLKey   = "baseURL"
    static let todosKey     = "todos_json"   // <— add this
    
    // Keys for app blocking
    static let isBlockedKey  = "isBlocked"     // whether apps are currently blocked
    static let blockedAtKey  = "blockedAt"     // timestamp when apps were blocked
    static let blockedAppsKey = "blockedApps"  // JSON array of blocked app tokens
    static let applicationTokensKey = "applicationTokens"  // stored application tokens for blocking
}

// MARK: - Selection persistence (App ↔ Extension via App Group)
final class SelectionStore: ObservableObject {
    #if canImport(FamilyControls)
    @Published var selection = FamilyActivitySelection() {
        didSet { persist() }
    }
    #else
    // Fallback for targets that don't support FamilyControls (like some extensions)
    var selection = "No Selection" 
    #endif

    init() {
        #if canImport(FamilyControls)
        if let data = Shared.defaults.data(forKey: Shared.selectionKey),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = decoded
        }
        #endif
    }

    private func persist() {
        #if canImport(FamilyControls)
        if let data = try? JSONEncoder().encode(selection) {
            Shared.defaults.set(data, forKey: Shared.selectionKey)
        }
        #endif
    }
}
