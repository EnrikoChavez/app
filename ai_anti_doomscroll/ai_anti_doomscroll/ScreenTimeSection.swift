//
//  ScreenTimeSection.swift
//  ai_anti_doomscroll
//

import SwiftUI
import FamilyControls
import DeviceActivity

#if canImport(ManagedSettings)
import ManagedSettings
#endif

struct ScreenTimeSection: View {
    @Binding var authStatus: String
    @Binding var showPicker: Bool
    @Binding var minutesText: String
    @Binding var starting: Bool
    @State private var statusMessage = ""
    @State private var isStatusError = false
    @State private var stopping = false
    @State private var authorized = false
    @State private var isMonitoringActive = false
    @State private var activeMinutes = 0
    @State private var activeMode = ""
    @State private var stopRemaining = StopMonitoringLimitManager.shared.remainingCount
    @ObservedObject var store: SelectionStore
    var updateAuthStatus: () async -> Void

    private var isAuthorized: Bool { authorized }

    private var isSelectionEmpty: Bool {
        #if canImport(FamilyControls)
        store.selection.applicationTokens.isEmpty
        && store.selection.categoryTokens.isEmpty
        && store.selection.webDomainTokens.isEmpty
        #else
        true
        #endif
    }

    private var selectionLabel: String {
        if isSelectionEmpty { return "Select Apps" }
        #if canImport(FamilyControls)
        let apps = store.selection.applicationTokens.count
        let cats = store.selection.categoryTokens.count
        switch (apps, cats) {
        case (_, 0): return "\(apps) App\(apps == 1 ? "" : "s")"
        case (0, _): return "\(cats) Categor\(cats == 1 ? "y" : "ies")"
        default:     return "\(cats) Categor\(cats == 1 ? "y" : "ies"), \(apps) App\(apps == 1 ? "" : "s")"
        }
        #else
        return "Selected"
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack{
                        Image(systemName: "hourglass")
                        .font(.title2)
                        .foregroundColor(.primary)
                        Text("Timer Dashboard")
                        .font(.headline)
                    }
                    Text("Configure how long to doomscroll for before blocking the app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            #if canImport(FamilyControls)
            if !isAuthorized {
                // ── Access Not Granted ──────────────────────────────
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 40))
                        .foregroundColor(.blue.opacity(0.7))

                    VStack(spacing: 6) {
                        Text("Screen Time Access Required")
                            .font(.headline)
                        Text("Grant access once to start monitoring apps and setting time limits. You won't be asked again.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await requestAuth() }
                    } label: {
                        Text("Grant Access")
                            .font(.body).bold()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 8)
            } else {
                VStack(spacing: 16) {
                    // ── Monitoring Status Card ────────────────────────
                    HStack(spacing: 12) {
                        Image(systemName: isMonitoringActive ? "dot.radiowaves.left.and.right" : "slash.circle")
                            .font(.title3)
                            .foregroundColor(isMonitoringActive ? .green : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(isMonitoringActive ? "Monitoring Active" : "No timer is set")
                                .font(.subheadline).bold()
                                .foregroundColor(isMonitoringActive ? .green : .secondary)
                            if isMonitoringActive {
                                Text("\(activeMinutes) min · \(activeMode)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(isMonitoringActive ? Color.green.opacity(0.07) : Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isMonitoringActive ? Color.green.opacity(0.25) : Color.clear, lineWidth: 1)
                    )

                    // Config Grid
                    HStack(spacing: 12) {
                        // App Selection
                        VStack(spacing: 4) {
                            Text("Apps to Block")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(action: { showPicker = true }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "apps.iphone")
                                        .font(.title3)
                                    Text(selectionLabel)
                                        .font(.caption).bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                            }
                            .familyActivityPicker(isPresented: $showPicker, selection: $store.selection)
                        }

                        // Time Limit
                        VStack(spacing: 4) {
                            Text("Time limit before block")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Menu {
                                ForEach(Array(stride(from: 3, through: 120, by: 1)), id: \.self) { mins in
                                    Button("\(mins) min") { minutesText = "\(mins)" }
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "timer")
                                        .font(.title3)
                                    HStack(spacing: 4) {
                                        Text(minutesText.isEmpty ? "15" : minutesText)
                                            .font(.body).bold()
                                        Text("min")
                                            .font(.body).bold()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption2)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.pink.opacity(0.1))
                                .foregroundColor(.pink)
                                .cornerRadius(12)
                            }
                        }
                    }

                    // Control Buttons
                    VStack(spacing: 10) {
                            // Start without warning
                            Button {
                                Task { await startMonitoring(withWarning: false) }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(isMonitoringActive ? "Restart" : "Start").bold()
                                    Text("no block warning — just an abrupt realization of doomscrolling").font(.caption2)
                                    .padding(.horizontal, 12)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isSelectionEmpty ? Color.gray.opacity(0.2) : Color.green.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(color: (isSelectionEmpty ? Color.gray : Color.green).opacity(0.35), radius: 6, x: 0, y: 3)
                            }
                            .disabled(starting || stopping || isSelectionEmpty)

                            Button {
                                Task { await startMonitoring(withWarning: true) }
                            } label: {
                                VStack(spacing: 2) {
                                    if starting { ProgressView().padding(.bottom, 2) }
                                    Text(isMonitoringActive ? "Restart" : "Start").bold()
                                    Text("5 minute block warning — a soft wake up call").font(.caption2)
                                    .padding(.horizontal, 12)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isSelectionEmpty ? Color.gray.opacity(0.2) : Color.green.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(color: (isSelectionEmpty ? Color.gray : Color.green).opacity(0.35), radius: 6, x: 0, y: 3)
                            }
                            .disabled(starting || stopping || isSelectionEmpty)

                            // Start with awareness only
                            Button {
                                Task { await startMonitoring(withWarning: false, withAwareness: true) }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(isMonitoringActive ? "Restart (Most Focus Friendly)" : "Start (Most Focus Friendly)").bold()
                                    Text("no block warning with awareness — mutes notifications from app until you first enter and warns before entering").font(.caption2)
                                    .padding(.horizontal, 12)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isSelectionEmpty ? Color.gray.opacity(0.2) : Color.indigo)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(color: (isSelectionEmpty ? Color.gray : Color.indigo).opacity(0.35), radius: 6, x: 0, y: 3)
                            }
                            .disabled(starting || stopping || isSelectionEmpty)

                            // Start with awareness + 5-min warning
                            Button {
                                Task { await startMonitoring(withWarning: true, withAwareness: true) }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(isMonitoringActive ? "Restart (Most Doomscrolling Reminders)" : "Start (Most Doomscrolling Reminders)").bold()
                                    Text("5 minute block warning with awareness — mutes notifications before entering and warns before entering and blocking").font(.caption2)
                                    .padding(.horizontal, 12)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isSelectionEmpty ? Color.gray.opacity(0.2) : Color.pink.opacity(0.68))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(color: (isSelectionEmpty ? Color.gray : Color.green).opacity(0.35), radius: 6, x: 0, y: 3)
                            }
                            .disabled(starting || stopping || isSelectionEmpty)

                        let canStop = StopMonitoringLimitManager.shared.canStop
                        Button {
                            Task { await stopMonitoring() }
                        } label: {
                            HStack(spacing: 6) {
                                Text("Stop Monitoring")
                                    .font(.caption)
                                if canStop {
                                    Text("(\(stopRemaining) left today)")
                                        .font(.caption2)
                                } else {
                                    Text("(stop limit reached for today)")
                                        .font(.caption2)
                                }
                            }
                            .foregroundColor(canStop ? .secondary : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        }
                        .disabled(starting || stopping || !canStop)
                    }

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption2)
                            .foregroundColor(isStatusError ? .red : .green)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    }

                    // Selected apps & categories list
                    if !isSelectionEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tracked Apps & Categories")
                                .font(.caption).bold()
                                .foregroundColor(.secondary)

                            let appTokens = Array(store.selection.applicationTokens)
                            let catCount = store.selection.categoryTokens.count

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 12)], spacing: 12) {
                                ForEach(appTokens, id: \.self) { token in
                                    Label(token)
                                        .labelStyle(.iconOnly)
                                        .scaleEffect(1.6)
                                        .frame(width: 44, height: 44)
                                }

                                if catCount > 0 {
                                    VStack(spacing: 2) {
                                        Image(systemName: "square.grid.2x2.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                        Text("+\(catCount) categor\(catCount == 1 ? "y" : "ies")")
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 60, height: 44)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        .id("\(store.selection.applicationTokens.count)-\(store.selection.categoryTokens.count)-\(store.selection.webDomainTokens.count)")
                    }
                }
            }
            #else
            Text("Screen Time features are only available on physical iOS devices.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
            #endif
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Time is cumulative across all selected apps. For example, a 15 min limit blocks at 8 total minutes in instagram + 7 total minutes in youtube.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .onAppear {
            #if canImport(FamilyControls)
            authorized = AuthorizationCenter.shared.authorizationStatus == .approved
            #endif
            isMonitoringActive = Shared.defaults.bool(forKey: Shared.isMonitoringActiveKey)
            activeMinutes = Shared.defaults.integer(forKey: Shared.monitoringMinutesKey)
            activeMode = Shared.defaults.string(forKey: Shared.monitoringModeKey) ?? ""
            stopRemaining = StopMonitoringLimitManager.shared.remainingCount
        }
    }
    
    #if canImport(FamilyControls)
    private func requestAuth() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            // requestAuthorization only returns successfully when user approved
            await MainActor.run { authorized = true }
            await updateAuthStatus()
        } catch {
            await MainActor.run {
                authorized = AuthorizationCenter.shared.authorizationStatus == .approved
                authStatus = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func startMonitoring(withWarning: Bool = true, withAwareness: Bool = false) async {
        starting = true
        await MainActor.run {
            statusMessage = ""
            isStatusError = false
        }
        defer { starting = false }

        let baseMinutes = Int(minutesText) ?? 15
        Shared.defaults.set(baseMinutes, forKey: Shared.minutesKey)
        Shared.defaults.set(withWarning, forKey: Shared.warningsEnabledKey)

        // Create one threshold per multiple of baseMinutes up to the max minutes in a day.
        // e.g. 15 min base → block at 15, 30, 45 ... 1440; warning at 10, 25, 40 ... (5 min early)
        let maxMultiples = 1440 / baseMinutes
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for m in 1...maxMultiples {
            let mins = m * baseMinutes
            // Block event
            events[DeviceActivityEvent.Name("usageThreshold_\(mins)")] = DeviceActivityEvent(
                applications: store.selection.applicationTokens,
                categories:  store.selection.categoryTokens,
                webDomains:  store.selection.webDomainTokens,
                threshold: DateComponents(minute: mins),
                includesPastActivity: false
            )
            // Warning event: only when warnings enabled and threshold > 5 min
            if withWarning {
                let warnMins = mins - 5
                if warnMins > 0 {
                    events[DeviceActivityEvent.Name("warningThreshold_\(warnMins)")] = DeviceActivityEvent(
                        applications: store.selection.applicationTokens,
                        categories:  store.selection.categoryTokens,
                        webDomains:  store.selection.webDomainTokens,
                        threshold: DateComponents(minute: warnMins),
                        includesPastActivity: false
                    )
                }
            }
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd:   DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        let center = DeviceActivityCenter()
        do {
            center.stopMonitoring([DeviceActivityName("dailyMonitor")])
            try center.startMonitoring(DeviceActivityName("dailyMonitor"), during: schedule, events: events)

            Shared.defaults.set(true, forKey: Shared.isMonitoringActiveKey)
            Shared.defaults.set(baseMinutes, forKey: Shared.monitoringMinutesKey)

            let modeLabel: String = {
                switch (withWarning, withAwareness) {
                case (false, false): return "no warning"
                case (true,  false): return "5 min warning"
                case (false, true):  return "awareness"
                case (true,  true):  return "awareness + warning"
                }
            }()
            Shared.defaults.set(modeLabel, forKey: Shared.monitoringModeKey)

            // Immediately apply the awareness shield so the next app open shows the consent screen
            if withAwareness {
                Shared.defaults.set(true, forKey: Shared.isAwarenessShieldKey)
                #if canImport(ManagedSettings)
                let shieldStore = ManagedSettingsStore()
                if !store.selection.applicationTokens.isEmpty {
                    shieldStore.shield.applications = store.selection.applicationTokens
                }
                if !store.selection.categoryTokens.isEmpty {
                    shieldStore.shield.applicationCategories = .specific(store.selection.categoryTokens)
                }
                if !store.selection.webDomainTokens.isEmpty {
                    shieldStore.shield.webDomains = store.selection.webDomainTokens
                }
                #endif
            } else {
                Shared.defaults.set(false, forKey: Shared.isAwarenessShieldKey)
            }

            #if canImport(FamilyControls)
            Analytics.monitoringStarted(
                minutes: baseMinutes,
                withWarning: withWarning,
                appCount: store.selection.applicationTokens.count,
                categoryCount: store.selection.categoryTokens.count
            )
            #endif

            await MainActor.run {
                isMonitoringActive = true
                activeMinutes = baseMinutes
                activeMode = modeLabel
                statusMessage = ""
                isStatusError = false
            }
        } catch {
            await MainActor.run {
                statusMessage = "❌ Failed: \(error.localizedDescription)"
                isStatusError = true
            }
        }
    }

    private func stopMonitoring() async {
        guard StopMonitoringLimitManager.shared.canStop else { return }

        await MainActor.run {
            stopping = true
            statusMessage = ""
        }
        defer { Task { @MainActor in stopping = false } }

        StopMonitoringLimitManager.shared.recordStop()
        await MainActor.run { stopRemaining = StopMonitoringLimitManager.shared.remainingCount }

        Analytics.monitoringStopped()
        let center = DeviceActivityCenter()
        center.stopMonitoring([DeviceActivityName("dailyMonitor")])
        
        #if canImport(ManagedSettings)
        if #available(iOS 16.0, *) {
            let blockStore = ManagedSettingsStore()
            blockStore.shield.applications = nil
        }
        #endif
        
        Shared.defaults.set(false, forKey: Shared.isMonitoringActiveKey)
        Shared.defaults.set(0, forKey: Shared.monitoringMinutesKey)
        Shared.defaults.set(false, forKey: Shared.isAwarenessShieldKey)

        await MainActor.run {
            isMonitoringActive = false
            activeMinutes = 0
            activeMode = ""
            statusMessage = ""
            isStatusError = false
        }
    }
    #endif
}
