//
//  ShieldActionExtension.swift
//  ShieldActionExtension
//

import ManagedSettings
import Foundation

class ShieldActionExtension: ShieldActionDelegate {

    private let appGroupId = "group.OrgIdentifier.ai-anti-doomscroll"
    private let isWarningShieldKey = "isWarningShield"

    private var isWarning: Bool {
        UserDefaults(suiteName: appGroupId)?.bool(forKey: isWarningShieldKey) ?? false
    }

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        if isWarning && action == .primaryButtonPressed {
            dismissWarningShield()
            completionHandler(.none) // Shield removed from store; .none keeps user in the app
        } else {
            switch action {
            case .primaryButtonPressed:
                completionHandler(.close)
            case .secondaryButtonPressed:
                completionHandler(.none)
            @unknown default:
                completionHandler(.none)
            }
        }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        if isWarning && action == .primaryButtonPressed {
            dismissWarningShield()
            completionHandler(.none)
        } else {
            switch action {
            case .primaryButtonPressed:
                completionHandler(.close)
            case .secondaryButtonPressed:
                completionHandler(.none)
            @unknown default:
                completionHandler(.none)
            }
        }
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        if isWarning && action == .primaryButtonPressed {
            dismissWarningShield()
            completionHandler(.none)
        } else {
            switch action {
            case .primaryButtonPressed:
                completionHandler(.close)
            case .secondaryButtonPressed:
                completionHandler(.none)
            @unknown default:
                completionHandler(.none)
            }
        }
    }

    private func dismissWarningShield() {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        // Clear the warning flag so the shield config reverts to the full block if shown again
        defaults.set(false, forKey: isWarningShieldKey)
        // Remove the shield entirely so the user can continue using the app
        let store = ManagedSettingsStore()
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
}
