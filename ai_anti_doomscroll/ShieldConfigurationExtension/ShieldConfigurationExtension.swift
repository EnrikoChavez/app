//
//  ShieldConfigurationExtension.swift
//  ShieldConfigurationExtension
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Customize the look of the shield for a specific application
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "brain.head.profile"),
            title: ShieldConfiguration.Label(text: "Time to Pause", color: .label),
            subtitle: ShieldConfiguration.Label(text: "Open Anti-Doomscroll to talk to your AI agent and unlock this app.", color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close App", color: .label)
        )
    }
}
