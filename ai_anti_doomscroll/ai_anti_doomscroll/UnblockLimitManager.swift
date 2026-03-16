//
//  UnblockLimitManager.swift
//  ai_anti_doomscroll
//
//  Tracks daily manual unblock usage locally.
//  Stores data in iCloud Key-Value Store so it survives reinstalls.
//  Falls back to UserDefaults if iCloud is unavailable.
//

import Foundation

struct UnblockLimitManager {
    static let shared = UnblockLimitManager()

    private let dailyLimit = 2
    private let countKey   = "unblockUsedCount"
    private let dateKey    = "unblockLastResetDate"

    // MARK: - Public API

    var limitCount: Int { dailyLimit }

    var usedCount: Int {
        resetIfNewDay()
        return readInt(countKey)
    }

    var remainingCount: Int {
        max(0, dailyLimit - usedCount)
    }

    var canUnblock: Bool {
        remainingCount > 0
    }

    /// Call this when the user performs a manual unblock.
    func recordUnblock() {
        resetIfNewDay()
        let current = readInt(countKey)
        write(current + 1, forKey: countKey)
        print("🔓 UnblockLimitManager: recorded unblock. Used: \(current + 1)/\(dailyLimit)")
    }

    // MARK: - Day reset

    private func resetIfNewDay() {
        let storedTimestamp = readDouble(dateKey)
        let storedDate = storedTimestamp > 0 ? Date(timeIntervalSince1970: storedTimestamp) : Date.distantPast

        if !Calendar.current.isDateInToday(storedDate) {
            write(0, forKey: countKey)
            write(Date().timeIntervalSince1970, forKey: dateKey)
            print("🔄 UnblockLimitManager: new day — counter reset")
        }
    }

    // MARK: - Storage (iCloud KV with UserDefaults fallback)

    private var iCloud: NSUbiquitousKeyValueStore { .default }
    private var local: UserDefaults { .standard }

    private func readInt(_ key: String) -> Int {
        // iCloud returns 0 for missing keys, same as UserDefaults
        let iCloudValue = Int(iCloud.longLong(forKey: key))
        if iCloudValue > 0 { return iCloudValue }
        return local.integer(forKey: key)
    }

    private func readDouble(_ key: String) -> Double {
        let iCloudValue = iCloud.double(forKey: key)
        if iCloudValue > 0 { return iCloudValue }
        return local.double(forKey: key)
    }

    private func write(_ value: Int, forKey key: String) {
        iCloud.set(Int64(value), forKey: key)
        iCloud.synchronize()
        local.set(value, forKey: key)
    }

    private func write(_ value: Double, forKey key: String) {
        iCloud.set(value, forKey: key)
        iCloud.synchronize()
        local.set(value, forKey: key)
    }
}
