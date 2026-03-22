//
//  ShieldActionExtension.swift
//  ShieldActionExtension
//

import ManagedSettings
import Foundation

class ShieldActionExtension: ShieldActionDelegate {

    private let appGroupId = "group.OrgIdentifier.ai-anti-doomscroll"
    private let isWarningShieldKey = "isWarningShield"
    private let isAwarenessShieldKey = "isAwarenessShield"

    private var isAwareness: Bool {
        UserDefaults(suiteName: appGroupId)?.bool(forKey: isAwarenessShieldKey) ?? false
    }

    private var isWarning: Bool {
        UserDefaults(suiteName: appGroupId)?.bool(forKey: isWarningShieldKey) ?? false
    }

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(handleAction(action))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(handleAction(action))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(handleAction(action))
    }

    private func handleAction(_ action: ShieldAction) -> ShieldActionResponse {
        if isAwareness {
            switch action {
            case .primaryButtonPressed:
                // "Yes, continue" — dismiss shield, user stays in app
                dismissAwarenessShield()
                return .none
            case .secondaryButtonPressed:
                // "Don't continue" — close the app
                dismissAwarenessShield()
                return .close
            @unknown default:
                return .none
            }
        }

        if isWarning && action == .primaryButtonPressed {
            // "Got it" — dismiss warning, user stays in app
            dismissWarningShield()
            return .none
        }

        // Default block shield
        switch action {
        case .primaryButtonPressed:
            return .close
        case .secondaryButtonPressed:
            return .none
        @unknown default:
            return .none
        }
    }

    private func dismissAwarenessShield() {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.set(false, forKey: isAwarenessShieldKey)
        let store = ManagedSettingsStore()
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    private func dismissWarningShield() {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.set(false, forKey: isWarningShieldKey)
        let store = ManagedSettingsStore()
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
}
