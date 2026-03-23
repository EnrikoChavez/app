//
//  ShieldConfigurationExtension.swift
//  ShieldConfigurationExtension
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let defaults = UserDefaults(suiteName: "group.OrgIdentifier.ai-anti-doomscroll")

    private var isWeekly: Bool {
        defaults?.bool(forKey: "isWeeklyShield") ?? false
    }

    private var isAwareness: Bool {
        defaults?.bool(forKey: "isAwarenessShield") ?? false
    }

    private var isWarning: Bool {
        defaults?.bool(forKey: "isWarningShield") ?? false
    }

    private func weeklyConfig() -> ShieldConfiguration {
        let subtitle = weeklyScheduleText()
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "calendar.badge.clock"),
            title: ShieldConfiguration.Label(
                text: "Blocked During Schedule",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Close App",
                color: .label
            )
        )
    }

    private func weeklyScheduleText() -> String {
        // Read saved days
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        // weekday 1=Sun, 2=Mon … 7=Sat → index = weekday - 1
        var selectedDayLabels: [String] = []
        if let data = defaults?.data(forKey: "weeklySelectedDays"),
           let days = try? JSONDecoder().decode([Int].self, from: data) {
            let sorted = days.sorted()
            selectedDayLabels = sorted.compactMap { weekday in
                let idx = weekday - 1
                return (0..<7).contains(idx) ? dayNames[idx] : nil
            }
        }

        // Read saved times
        let startH = defaults?.integer(forKey: "weeklyStartHour") ?? 9
        let startM = defaults?.integer(forKey: "weeklyStartMinute") ?? 0
        let endH   = defaults?.integer(forKey: "weeklyEndHour") ?? 17
        let endM   = defaults?.integer(forKey: "weeklyEndMinute") ?? 0

        let startStr = formatTime(hour: startH, minute: startM)
        let endStr   = formatTime(hour: endH,   minute: endM)

        let daysStr = selectedDayLabels.isEmpty ? "scheduled days" : selectedDayLabels.joined(separator: ", ")
        return "This app is blocked on \(daysStr) from \(startStr) to \(endStr)."
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let period = hour < 12 ? "AM" : "PM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let m = String(format: "%02d", minute)
        return "\(h):\(m) \(period)"
    }

    // MARK: - Task helpers

    private func loadStringArray(forKey key: String) -> [String] {
        guard let data = defaults?.data(forKey: key),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return arr
    }

    private func awarenessSubtitle() -> String {
        let base = "Your time on this app is being tracked and will block after some time. Are you sure you want to continue?"

        let focusTasks = loadStringArray(forKey: "shieldFocusTasks")
        let allTasks   = loadStringArray(forKey: "shieldAllTasks")

        if !focusTasks.isEmpty {
            let bullet = focusTasks.map { "• \($0)" }.joined(separator: "\n")
            return "\(base)\n\nToday's Focus:\n\(bullet)"
        }

        if !allTasks.isEmpty {
            return "\(base)\n\nYou have stuff to do, but none are in Today's Focus yet."
        }

        return "\(base)\n\nEven if nothing listed to do — are you sure you have nothing to do right now?"
    }

    private func awarenessConfig() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            title: ShieldConfiguration.Label(
                text: "Opening Doomscroll App",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: awarenessSubtitle(),
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
                text: "warning that app will block soon.",
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
            icon: UIImage(systemName: "leaf"),
            title: ShieldConfiguration.Label(text: "Time to Pause", color: .label),
            subtitle: ShieldConfiguration.Label(
                text: "Open Anti-Doomscroll to talk to your AI companion and unlock this app.",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close App", color: .label)
        )
    }

    private func currentConfig() -> ShieldConfiguration {
        if isWeekly    { return weeklyConfig() }
        if isAwareness { return awarenessConfig() }
        if isWarning   { return warningConfig() }
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
