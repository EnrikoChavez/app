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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.systemColorScheme) private var systemColorScheme
    @Binding var authStatus: String
    @Binding var showPicker: Bool
    @Binding var minutesText: String
    @Binding var starting: Bool
    @State private var statusMessage = ""
    @State private var isStatusError = false
    @State private var stopping = false
    @AppStorage("screenTimeAuthorized") private var authorized = false
    @AppStorage("timerDashboardTab") private var selectedDashboardTab = 0
    @State private var isMonitoringActive = false
    @State private var activeMinutes = 0
    @State private var activeMode = ""
    @State private var stopRemaining = StopMonitoringLimitManager.shared.remainingCount
    @State private var currentStreak = StreakManager.shared.currentStreak

    // Timed block state
    @State private var isTimedBlockActive = false
    @State private var timedBlockEndTime: Date? = nil
    @State private var timedBlockMinutes = 30
    @State private var timedBlockCountdown = ""
    @State private var timedStarting = false

    private let timedBlockOptions: [(minutes: Int, label: String)] = [
        (5, "5 min"), (10, "10 min"), (15, "15 min"), (20, "20 min"),
        (30, "30 min"), (45, "45 min"),
        (60, "1 hour"), (90, "1.5 hours"), (120, "2 hours"),
        (180, "3 hours"), (240, "4 hours"), (300, "5 hours"),
        (360, "6 hours"), (420, "7 hours"), (480, "8 hours"),
        (540, "9 hours"), (600, "10 hours"), (660, "11 hours"),
        (720, "12 hours"), (780, "13 hours"), (840, "14 hours"),
        (900, "15 hours"), (960, "16 hours"), (1020, "17 hours"),
        (1080, "18 hours")
    ]

    private var timedBlockLabel: String {
        timedBlockOptions.first { $0.minutes == timedBlockMinutes }?.label ?? "\(timedBlockMinutes) min"
    }

    @ObservedObject var store: SelectionStore
    var updateAuthStatus: () async -> Void
    var onBlockStateChanged: () -> Void = {}
    var isPremium: Bool = true
    var isLoggedIn: Bool = true
    var onSubscribeTap: () -> Void = {}
    var onCallForExtraStop: () -> Void = {}
    var onChatForExtraStop: () -> Void = {}

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
                    HStack {
                        Image(systemName: "hourglass")
                            .font(.title2)
                            .foregroundColor(.primary)
                        Text("Timer Dashboard")
                            .font(.headline)
                    }
                    Text("Configure how to block your doomscroll apps")
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

                    // ── Mode Tabs ──────────────────────────────────
                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            ForEach([(0, "Timed Block"), (1, "Usage Limit")], id: \.0) { tag, label in
                                let isSelected = selectedDashboardTab == tag
                                let isDisabled = (tag == 1 && isTimedBlockActive)
                                Button {
                                    guard !isDisabled else { return }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    var t = Transaction()
                                    t.disablesAnimations = true
                                    withTransaction(t) { selectedDashboardTab = tag }
                                } label: {
                                    Text(label)
                                        .font(.subheadline).bold()
                                        .foregroundColor(isDisabled ? .secondary.opacity(0.4) : (isSelected ? .primary : .secondary))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 5)
                                        .background(
                                            isSelected
                                                ? Capsule()
                                                    .fill(Color.white)
                                                    .shadow(color: Color.black.opacity(0.13), radius: 5, x: 0, y: 2)
                                                : nil
                                        )
                                        .overlay(
                                            isSelected
                                                ? Capsule()
                                                    .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
                                                : nil
                                        )
                                }
                                .disabled(isDisabled)
                                .transaction { $0.disablesAnimations = true }
                            }
                        }
                        if isTimedBlockActive && selectedDashboardTab == 1 {
                            Text("Unblock apps to switch modes.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else if isMonitoringActive && selectedDashboardTab == 0 {
                            Text("Starting a timed block will stop monitoring.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Group {
                        if selectedDashboardTab == 0 {
                            timedBlockTab
                        } else {
                            usageLimitTab
                        }
                    }
                    .animation(nil, value: selectedDashboardTab)
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
        .background(AppTheme.cardBg(for: systemColorScheme))
        .cornerRadius(16)
        .onAppear { loadState() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if isTimedBlockActive { checkAndUpdateTimedBlock() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stopLimitGranted)) { _ in
            stopRemaining = StopMonitoringLimitManager.shared.remainingCount
        }

        if selectedDashboardTab == 0 {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundColor(systemColorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
                    Text("Time is cumulative across all selected apps. For example, a 15 min limit blocks at 8 total minutes in Instagram + 7 total minutes in YouTube.")
                        .font(.caption2)
                        .foregroundColor(systemColorScheme == .dark ? Color.white.opacity(0.55) : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Usage Limit Tab

    @ViewBuilder private var usageLimitTab: some View {
        // Streak Card
        HStack(spacing: 12) {
            Text("🔥")
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(currentStreak) day streak")
                    .font(.headline).bold()
                Text(currentStreak == 0
                     ? "Complete a full day without stopping monitoring to start your streak."
                     : "Keep it up — don't stop monitoring today to extend your streak!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(systemColorScheme == .dark ? Color(white: 0.93) : AppTheme.cardBg(for: .light))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.35), lineWidth: 1))

        // Config Grid
        HStack(spacing: 12) {
            // App Selection
            VStack(spacing: 4) {
                Text("Apps to block after limit")
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
                    .background(systemColorScheme == .dark ? Color.blue.opacity(0.25) : Color.blue.opacity(0.1))
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
                    .background(systemColorScheme == .dark ? Color.pink.opacity(0.25) : Color.pink.opacity(0.1))
                    .foregroundColor(.pink)
                    .cornerRadius(12)
                }
            }
        }

        // Control Buttons
        let canStop = StopMonitoringLimitManager.shared.canStop
        HStack(spacing: 10) {
            ZStack {
                Button {
                    Task { await startMonitoring(withWarning: true, withAwareness: true) }
                } label: {
                    VStack(spacing: 2) {
                        Text(isMonitoringActive ? "Restart (Active: \(activeMinutes) min)" : "Start").bold()
                        Text(isMonitoringActive
                             ? "Uses 1 of your \(stopRemaining) daily stop\(stopRemaining == 1 ? "" : "s") remaining"
                             : "5 min warning before blocking + shows today's tasks when initially opening the set of apps"
                        ).font(.caption2)
                            .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isSelectionEmpty ? Color.gray.opacity(0.2) : Color.green.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isMonitoringActive ? Color.red : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                }
                .disabled(starting || stopping || isSelectionEmpty)
                if !isLoggedIn || !isPremium {
                    SubscriptionGateOverlay(cornerRadius: 12, isLoggedIn: isLoggedIn, onTap: onSubscribeTap)
                }
            }

            Button {
                Task { await stopMonitoring() }
            } label: {
                VStack(spacing: 4) {
                    Text("Stop\nMonitoring")
                        .font(.caption).bold()
                        .multilineTextAlignment(.center)
                    Text(canStop ? "\(stopRemaining) left daily" : "limit\nreached")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(canStop ? .secondary : .red)
                .frame(width: 70)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(AppTheme.rowBackground)
                .cornerRadius(12)
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

        // Extra stop via AI — only shown when monitoring is active and limit is reached
        if isMonitoringActive && stopRemaining == 0 {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(.purple)
                    Text("Convince AI for 1 extra stop monitoring")
                        .font(.caption).bold()
                        .foregroundColor(.purple)
                }
                Text("Convince the AI that you've completed your Today's to-dos and it'll grant you one more stop.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    Button(action: { Analytics.extraStopRequested(via: "call"); onCallForExtraStop() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                            Text("Call AI")
                        }
                        .font(.caption).bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.purple)
                        .cornerRadius(10)
                    }
                    Button(action: { Analytics.extraStopRequested(via: "chat"); onChatForExtraStop() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "message.fill")
                            Text("Chat AI")
                        }
                        .font(.caption).bold()
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.12))
                        .cornerRadius(10)
                    }
                }
            }
            .padding(12)
            .background(Color.purple.opacity(0.07))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.2), lineWidth: 1))
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
            .background(AppTheme.rowBackground)
            .cornerRadius(12)
            .id("\(store.selection.applicationTokens.count)-\(store.selection.categoryTokens.count)-\(store.selection.webDomainTokens.count)")
        }
    }

    // MARK: - Timed Block Tab

    @ViewBuilder
    private var timedBlockTab: some View {
        if isTimedBlockActive {
            // ── Active countdown ────────────────────────────────
            VStack(spacing: 12) {
                VStack(spacing: 6) {
                    Text("Apps Blocked")
                        .font(.subheadline).bold()
                        .foregroundColor(.orange)
                    Text(timedBlockCountdown)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(AppTheme.rowBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                )

                Text("If you want to end the block early, call AI call, chat, or manual unblock.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

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
                    .background(AppTheme.rowBackground)
                    .cornerRadius(12)
                }
            }
        } else {
            // ── Setup ───────────────────────────────────────────
            HStack(spacing: 12) {
                // App Selection
                VStack(spacing: 4) {
                    Text("Apps to block")
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 16)
                        .background(systemColorScheme == .dark ? Color.blue.opacity(0.25) : Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                    .familyActivityPicker(isPresented: $showPicker, selection: $store.selection)
                }

                // Duration picker
                VStack(spacing: 4) {
                    Text("Block duration")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Menu {
                        ForEach(timedBlockOptions, id: \.minutes) { option in
                            Button(option.label) { timedBlockMinutes = option.minutes }
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "hourglass")
                                .font(.title3)
                            HStack(spacing: 4) {
                                Text(timedBlockLabel)
                                    .font(.body).bold()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 12)
                        .background(systemColorScheme == .dark ? Color.orange.opacity(0.25) : Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(12)
                    }
                }
            }

            ZStack {
                Button {
                    Task { await startTimedBlock() }
                } label: {
                    HStack(spacing: 6) {
                        if timedStarting {
                            ProgressView().tint(.white)
                        }
                        Text("Block Now for \(timedBlockLabel)").bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isSelectionEmpty ? Color.gray.opacity(0.2) : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: (isSelectionEmpty ? Color.gray : Color.orange).opacity(0.35), radius: 6, x: 0, y: 3)
                }
                .disabled(timedStarting || isSelectionEmpty)

                if !isLoggedIn || !isPremium {
                    SubscriptionGateOverlay(cornerRadius: 12, isLoggedIn: isLoggedIn, onTap: onSubscribeTap)
                }
            }

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
                .background(AppTheme.rowBackground)
                .cornerRadius(12)
                .id("\(store.selection.applicationTokens.count)-\(store.selection.categoryTokens.count)-\(store.selection.webDomainTokens.count)")
        }
    }
}

    // MARK: - onAppear

    private func loadState() {
        #if canImport(FamilyControls)
        if AuthorizationCenter.shared.authorizationStatus == .approved {
            authorized = true
        }
        #endif
        isMonitoringActive = Shared.defaults.bool(forKey: Shared.isMonitoringActiveKey)
        activeMinutes = Shared.defaults.integer(forKey: Shared.monitoringMinutesKey)
        activeMode = Shared.defaults.string(forKey: Shared.monitoringModeKey) ?? ""
        stopRemaining = StopMonitoringLimitManager.shared.remainingCount
        currentStreak = StreakManager.shared.checkAndUpdate()

        // Restore timed block state
        let endTimestamp = Shared.defaults.double(forKey: Shared.timedBlockEndTimeKey)
        if Shared.defaults.bool(forKey: Shared.isTimedBlockActiveKey) && endTimestamp > 0 {
            let endDate = Date(timeIntervalSince1970: endTimestamp)
            if endDate > Date() {
                isTimedBlockActive = true
                timedBlockEndTime = endDate
                selectedDashboardTab = 1
                updateCountdown()
            } else {
                // Expired while app was closed — clean up silently
                Task { await autoExpireTimedBlock() }
            }
        }
    }

    // MARK: - Timed Block Logic

    private func checkAndUpdateTimedBlock() {
        // Detect external unblock (e.g. via AI call from ContentView)
        if !Shared.defaults.bool(forKey: Shared.isTimedBlockActiveKey) {
            Task { await autoExpireTimedBlock() }
            return
        }
        guard let endTime = timedBlockEndTime else { return }
        if Date() >= endTime {
            Task { await autoExpireTimedBlock() }
        } else {
            updateCountdown()
        }
    }

    private func updateCountdown() {
        guard let endTime = timedBlockEndTime else { timedBlockCountdown = ""; return }
        let remaining = max(0, endTime.timeIntervalSinceNow)
        let mins = Int(remaining) / 60
        let secs = Int(remaining) % 60
        timedBlockCountdown = String(format: "%d:%02d", mins, secs)
    }

    private func startTimedBlock() async {
        await MainActor.run { timedStarting = true }
        defer { Task { @MainActor in timedStarting = false } }

        // If usage-limit monitoring is active, stop it and consume a stop count
        if await MainActor.run(body: { isMonitoringActive }) {
            StopMonitoringLimitManager.shared.recordStop()
            StreakManager.shared.markStopUsed()
            let center = DeviceActivityCenter()
            center.stopMonitoring([DeviceActivityName("dailyMonitor")])
            #if canImport(ManagedSettings)
            if #available(iOS 16.0, *) {
                ManagedSettingsStore().shield.applications = nil
            }
            #endif
            Shared.defaults.set(false, forKey: Shared.isMonitoringActiveKey)
            Shared.defaults.set(0, forKey: Shared.monitoringMinutesKey)
            Analytics.monitoringStopped()
            await MainActor.run {
                isMonitoringActive = false
                activeMinutes = 0
                activeMode = ""
                stopRemaining = StopMonitoringLimitManager.shared.remainingCount
            }
        }

        let minutes = timedBlockMinutes
        let endTime = Date().addingTimeInterval(TimeInterval(minutes * 60))

        Shared.defaults.set(true,  forKey: Shared.isTimedBlockActiveKey)
        Shared.defaults.set(endTime.timeIntervalSince1970, forKey: Shared.timedBlockEndTimeKey)
        Shared.defaults.set(true,  forKey: Shared.isBlockedKey)
        Shared.defaults.set(Date().timeIntervalSince1970, forKey: Shared.blockedAtKey)

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

        await MainActor.run {
            isTimedBlockActive = true
            timedBlockEndTime = endTime
            updateCountdown()
            onBlockStateChanged()
        }
        Analytics.timedBlockStarted(
            minutes: minutes,
            appCount: store.selection.applicationTokens.count,
            categoryCount: store.selection.categoryTokens.count
        )
    }

    private func autoExpireTimedBlock() async {
        #if canImport(ManagedSettings)
        let shieldStore = ManagedSettingsStore()
        shieldStore.shield.applications = nil
        shieldStore.shield.applicationCategories = nil
        shieldStore.shield.webDomains = nil
        #endif

        Shared.defaults.set(false, forKey: Shared.isTimedBlockActiveKey)
        Shared.defaults.removeObject(forKey: Shared.timedBlockEndTimeKey)
        Shared.defaults.set(false, forKey: Shared.isBlockedKey)
        Shared.defaults.removeObject(forKey: Shared.blockedAtKey)

        await MainActor.run {
            isTimedBlockActive = false
            timedBlockEndTime = nil
            timedBlockCountdown = ""
        }
        Analytics.timedBlockEnded(wasManual: false)
    }

    // MARK: - Usage Limit Logic

    #if canImport(FamilyControls)
    private func requestAuth() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
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

        // Restarting counts against the stop limit — block entirely if limit reached
        if isMonitoringActive {
            guard StopMonitoringLimitManager.shared.canStop else {
                await MainActor.run {
                    statusMessage = "Daily restart limit reached. Try again tomorrow."
                    isStatusError = true
                }
                Analytics.stopMonitoringLimitReached()
                return
            }
            StopMonitoringLimitManager.shared.recordStop()
            await MainActor.run { stopRemaining = StopMonitoringLimitManager.shared.remainingCount }
        }

        let baseMinutes = Int(minutesText) ?? 15
        Shared.defaults.set(baseMinutes, forKey: Shared.minutesKey)
        Shared.defaults.set(withWarning, forKey: Shared.warningsEnabledKey)

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        events[DeviceActivityEvent.Name("usageThreshold_\(baseMinutes)")] = DeviceActivityEvent(
            applications: store.selection.applicationTokens,
            categories:  store.selection.categoryTokens,
            webDomains:  store.selection.webDomainTokens,
            threshold: DateComponents(minute: baseMinutes),
            includesPastActivity: false
        )
        if withWarning {
            let warnMins = baseMinutes - 5
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
        StreakManager.shared.markStopUsed()
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
