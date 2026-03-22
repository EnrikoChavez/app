//
//  ShieldConfigurationExtension.swift
//  ShieldConfigurationExtension
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let defaults = UserDefaults(suiteName: "group.OrgIdentifier.ai-anti-doomscroll")

    private var isAwareness: Bool {
        defaults?.bool(forKey: "isAwarenessShield") ?? false
    }

    private var isWarning: Bool {
        defaults?.bool(forKey: "isWarningShield") ?? false
    }

    private func awarenessConfig() -> ShieldConfiguration {
        let minutes = defaults?.integer(forKey: "fc.minutes") ?? 0
        let timeText = minutes > 0 ? "\(minutes) minutes" : "your set time limit"
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            title: ShieldConfiguration.Label(
                text: "Opening Doomscroll App",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Your time on this app is being tracked and will block after some time. Are you sure you want to continue?",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Yes, continue",
                color: .label
            ),
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Don't continue",
                color: .secondaryLabel
            )
        )
    }

    private func warningConfig() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            icon: UIImage(systemName: "timer"),
            title: ShieldConfiguration.Label(
                text: "5 Minutes Left",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "warning that app will block.",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Got it",
                color: .label
            )
        )
    }

    private func blockConfig() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "brain.head.profile"),
            title: ShieldConfiguration.Label(text: "Time to Pause", color: .label),
            subtitle: ShieldConfiguration.Label(
                text: "Open Anti-Doomscroll to talk to your AI companion and unlock this app.",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close App", color: .label)
        )
    }

    private func currentConfig() -> ShieldConfiguration {
        if isAwareness { return awarenessConfig() }
        if isWarning { return warningConfig() }
        return blockConfig()
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        currentConfig()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        currentConfig()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        currentConfig()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        currentConfig()
    }
}
