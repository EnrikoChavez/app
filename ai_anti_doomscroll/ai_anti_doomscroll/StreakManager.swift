// StreakManager.swift
// Tracks consecutive "clean" days where no stop-monitoring count was used.

import Foundation

final class StreakManager {
    static let shared = StreakManager()
    private init() {}

    private let defaults = UserDefaults.standard
    private let streakKey      = "monitoringStreakCount"
    private let lastCheckKey   = "monitoringStreakLastCheck"   // "yyyy-MM-dd"
    private let lastStopKey    = "monitoringStreakLastStopDate" // "yyyy-MM-dd"

    // MARK: - Public

    var currentStreak: Int { defaults.integer(forKey: streakKey) }

    /// Call whenever a stop-monitoring count is consumed.
    func markStopUsed() {
        defaults.set(today(), forKey: lastStopKey)
    }

    /// Call on each app-open / section appear. Returns updated streak.
    @discardableResult
    func checkAndUpdate() -> Int {
        let todayStr  = today()
        let lastCheck = defaults.string(forKey: lastCheckKey) ?? ""

        // Already evaluated today — nothing to do.
        if lastCheck == todayStr { return currentStreak }
        defer { defaults.set(todayStr, forKey: lastCheckKey) }

        // First ever launch — just start tracking from today.
        guard let lastCheckDate = date(from: lastCheck) else { return currentStreak }

        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: Date()),
              cal.isDate(lastCheckDate, inSameDayAs: yesterday) else {
            // Gap of 2+ days — streak broken.
            defaults.set(0, forKey: streakKey)
            return 0
        }

        // Last check was yesterday: was it a clean day?
        let lastStopDate = defaults.string(forKey: lastStopKey) ?? ""
        if lastStopDate == lastCheck {
            // A stop was used yesterday — reset.
            defaults.set(0, forKey: streakKey)
            return 0
        } else {
            // Clean day — increment.
            let next = currentStreak + 1
            defaults.set(next, forKey: streakKey)
            return next
        }
    }

    // MARK: - Helpers

    private func today() -> String { formatted(Date()) }

    private func formatted(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: d)
    }

    private func date(from s: String) -> Date? {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: s)
    }
}
