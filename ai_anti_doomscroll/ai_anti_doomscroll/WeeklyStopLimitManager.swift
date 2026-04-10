//
//  WeeklyStopLimitManager.swift
//  ai_anti_doomscroll
//
//  Tracks daily "stop weekly schedule" usage — max 1 per day.
//  Stored in iCloud KV store; falls back to UserDefaults.
//

import Foundation

struct WeeklyStopLimitManager {
    static let shared = WeeklyStopLimitManager()

    private let dailyLimit = 1
    private let countKey   = "weeklyStopUsedCount"
    private let dateKey    = "weeklyStopLastResetDate"

    var limitCount: Int { dailyLimit }

    var usedCount: Int {
        resetIfNewDay()
        return readInt(countKey)
    }

    var remainingCount: Int { max(0, dailyLimit - usedCount) }

    var canStop: Bool { remainingCount > 0 }

    func recordStop() {
        resetIfNewDay()
        write(readInt(countKey) + 1, forKey: countKey)
    }

    private func resetIfNewDay() {
        let ts = readDouble(dateKey)
        let stored = ts > 0 ? Date(timeIntervalSince1970: ts) : Date.distantPast
        if !Calendar.current.isDateInToday(stored) {
            write(0, forKey: countKey)
            write(Date().timeIntervalSince1970, forKey: dateKey)
        }
    }

    private var iCloud: NSUbiquitousKeyValueStore { .default }
    private var local: UserDefaults { .standard }

    private func readInt(_ key: String) -> Int {
        let v = Int(iCloud.longLong(forKey: key))
        return v > 0 ? v : local.integer(forKey: key)
    }
    private func readDouble(_ key: String) -> Double {
        let v = iCloud.double(forKey: key)
        return v > 0 ? v : local.double(forKey: key)
    }
    private func write(_ value: Int, forKey key: String) {
        iCloud.set(Int64(value), forKey: key); iCloud.synchronize()
        local.set(value, forKey: key)
    }
    private func write(_ value: Double, forKey key: String) {
        iCloud.set(value, forKey: key); iCloud.synchronize()
        local.set(value, forKey: key)
    }
}
