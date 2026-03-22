//
//  ShieldConfigurationExtension.swift
//  ShieldConfigurationExtension
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private var isWarning: Bool {
        UserDefaults(suiteName: "group.OrgIdentifier.ai-anti-doomscroll")?
            .bool(forKey: "isWarningShield") ?? false
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
        isWarning ? warningConfig() : blockConfig()
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
