// Shared.swift
import Foundation
import Combine
import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
import DeviceActivity
import ManagedSettings
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

    // Keys for monitoring state display
    static let isMonitoringActiveKey = "isMonitoringActive"
    static let monitoringMinutesKey  = "monitoringMinutes"

    // Warning shield: true when the 5-min warning shield is active (dismissable)
    static let isWarningShieldKey = "isWarningShield"
    // Whether warning notifications are enabled for the current monitoring session
    static let warningsEnabledKey = "warningsEnabled"
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

    #if canImport(FamilyControls)
    /// Restart monitoring with a fresh schedule so thresholds reset from zero.
    /// Called after unblocking so the timer starts fresh.
    func restartMonitoring() {
        let baseMinutes = Shared.defaults.integer(forKey: Shared.minutesKey)
        guard baseMinutes > 0 else { return }
        guard !selection.applicationTokens.isEmpty
           || !selection.categoryTokens.isEmpty
           || !selection.webDomainTokens.isEmpty else { return }

        let maxMultiples = 1440 / baseMinutes
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for m in 1...maxMultiples {
            let mins = m * baseMinutes
            events[DeviceActivityEvent.Name("usageThreshold_\(mins)")] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories:  selection.categoryTokens,
                webDomains:  selection.webDomainTokens,
                threshold: DateComponents(minute: mins),
                includesPastActivity: false
            )
            let warnMins = mins - 5
            if warnMins > 0 {
                events[DeviceActivityEvent.Name("warningThreshold_\(warnMins)")] = DeviceActivityEvent(
                    applications: selection.applicationTokens,
                    categories:  selection.categoryTokens,
                    webDomains:  selection.webDomainTokens,
                    threshold: DateComponents(minute: warnMins),
                    includesPastActivity: false
                )
            }
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd:   DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        let center = DeviceActivityCenter()
        center.stopMonitoring([DeviceActivityName("dailyMonitor")])
        do {
            try center.startMonitoring(DeviceActivityName("dailyMonitor"), during: schedule, events: events)
            print("🔄 Monitoring restarted after unblock (\(baseMinutes) min threshold)")
        } catch {
            print("❌ Failed to restart monitoring: \(error.localizedDescription)")
        }
    }
    #endif
}
