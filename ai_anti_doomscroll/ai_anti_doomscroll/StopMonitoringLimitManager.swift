//
//  StopMonitoringLimitManager.swift
//  ai_anti_doomscroll
//
//  Tracks daily "stop monitoring" usage.
//  Stored in iCloud Key-Value Store so it survives reinstalls.
//  Falls back to UserDefaults if iCloud is unavailable.
//

import Foundation

struct StopMonitoringLimitManager {
    static let shared = StopMonitoringLimitManager()

    private let dailyLimit = 4
    private let countKey   = "stopMonitoringUsedCount"
    private let dateKey    = "stopMonitoringLastResetDate"

    // MARK: - Public API

    var limitCount: Int { dailyLimit }

    var usedCount: Int {
        resetIfNewDay()
        return readInt(countKey)
    }

    var remainingCount: Int {
        max(0, dailyLimit - usedCount)
    }

    var canStop: Bool {
        remainingCount > 0
    }

    func recordStop() {
        resetIfNewDay()
        let current = readInt(countKey)
        write(current + 1, forKey: countKey)
        print("🛑 StopMonitoringLimitManager: recorded stop. Used: \(current + 1)/\(dailyLimit)")
    }

    func grantExtraStop() {
        resetIfNewDay()
        let current = readInt(countKey)
        if current > 0 {
            write(current - 1, forKey: countKey)
            print("✅ StopMonitoringLimitManager: extra stop granted. Used: \(current - 1)/\(dailyLimit)")
        }
        NotificationCenter.default.post(name: .stopLimitGranted, object: nil)
    }

    // MARK: - Day reset

    private func resetIfNewDay() {
        let storedTimestamp = readDouble(dateKey)
        let storedDate = storedTimestamp > 0 ? Date(timeIntervalSince1970: storedTimestamp) : Date.distantPast

        if !Calendar.current.isDateInToday(storedDate) {
            write(0, forKey: countKey)
            write(Date().timeIntervalSince1970, forKey: dateKey)
            print("🔄 StopMonitoringLimitManager: new day — counter reset")
        }
    }

    // MARK: - Storage (iCloud KV with UserDefaults fallback)

    private var iCloud: NSUbiquitousKeyValueStore { .default }
    private var local: UserDefaults { .standard }

    private func readInt(_ key: String) -> Int {
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
