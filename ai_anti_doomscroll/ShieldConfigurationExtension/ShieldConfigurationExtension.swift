//
//  ShieldConfigurationExtension.swift
//  ShieldConfigurationExtension
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    
    private func shieldConfig() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "brain.head.profile"),
            title: ShieldConfiguration.Label(text: "Time to Pause", color: .label),
            subtitle: ShieldConfiguration.Label(text: "Open Anti-Doomscroll to talk to your AI companion and unlock this app.", color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close App", color: .label)
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        shieldConfig()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        shieldConfig()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        shieldConfig()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        shieldConfig()
    }
}
