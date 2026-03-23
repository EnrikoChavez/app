//
//  WeeklyScheduleSection.swift
//  ai_anti_doomscroll
//
//  Weekly time-block schedule: pick days + a time window and block selected apps
//  for the entire window every week, indefinitely.
//  Uses its own separate app selection (independent from the usage-limit monitor).
//

import SwiftUI
import DeviceActivity
import FamilyControls

#if canImport(ManagedSettings)
import ManagedSettings
#endif

// Sunday first, then Mon–Sat  (weekday: 1=Sun, 2=Mon … 7=Sat)
private let allDays: [(Int, String)] = [
    (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")
]

struct WeeklyScheduleSection: View {
    @StateObject private var store = SelectionStore(storageKey: Shared.weeklySelectionKey)

    @State private var selectedDays: Set<Int> = []
    @State private var startTime: Date = defaultTime(hour: 9)
    @State private var endTime: Date   = defaultTime(hour: 17)
    @State private var isActive = false
    @State private var starting = false
    @State private var showPicker = false
    @State private var statusMessage = ""
    @State private var isStatusError = false
    @State private var stopRemaining = WeeklyStopLimitManager.shared.remainingCount

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── Header ──────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("(Hidden Bonus Feature)")
                        .font(.caption)
                    Text("Weekly Block Schedule")
                        .font(.headline)
                    Text("Block apps on specific days and times every week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            #if canImport(FamilyControls)
            VStack(spacing: 16) {

                // ── Status card ─────────────────────────────────────
                HStack(spacing: 12) {
                    Image(systemName: isActive ? "calendar.badge.clock" : "calendar")
                        .font(.title3)
                        .foregroundColor(isActive ? .blue : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isActive ? "Weekly Schedule Active" : "No weekly schedule set")
                            .font(.subheadline).bold()
                            .foregroundColor(isActive ? .blue : .secondary)
                        if isActive {
                            Text(activeSummary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(14)
                .background(isActive ? Color.blue.opacity(0.07) : Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.blue.opacity(0.25) : Color.clear, lineWidth: 1)
                )

                // ── App selection ───────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apps to Block")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Button(action: { showPicker = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "apps.iphone")
                                .font(.title3)
                            Text(selectionLabel)
                                .font(.caption).bold()
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(Color.blue.opacity(0.08))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                    .familyActivityPicker(isPresented: $showPicker, selection: $store.selection)
                }

                // ── Day picker ──────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Days")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(allDays, id: \.0) { weekday, label in
                            let selected = selectedDays.contains(weekday)
                            Button {
                                if selected { selectedDays.remove(weekday) }
                                else        { selectedDays.insert(weekday) }
                                saveDays()
                            } label: {
                                Text(label)
                                    .font(.subheadline).bold()
                                    .foregroundColor(selected ? .white : .secondary)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .aspectRatio(1, contentMode: .fit)
                                    .background(selected ? Color.blue : Color(.systemGray5))
                                    .clipShape(Circle())
                            }
                        }
                    }
                }

                // ── Time range ──────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time Window")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("From")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .onChange(of: startTime) { _ in saveTimes() }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.07))
                        .cornerRadius(10)

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        VStack(spacing: 4) {
                            Text("To")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .onChange(of: endTime) { _ in saveTimes() }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.07))
                        .cornerRadius(10)
                    }
                }

                // ── Control buttons ─────────────────────────────────
                let canStart = !selectedDays.isEmpty && !isSelectionEmpty

                Button {
                    Task { await startWeeklySchedule() }
                } label: {
                    HStack {
                        if starting { ProgressView().tint(.white) }
                        VStack(spacing: 2) {
                            Text(isActive ? "Restart Schedule" : "Start Schedule").bold()
                            Text(canStart ? timeRangeLabel : "select days & apps first")
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canStart ? Color.blue : Color.gray.opacity(0.4))
                    .cornerRadius(12)
                }
                .disabled(starting || !canStart)

                if isActive {
                    let canStop = WeeklyStopLimitManager.shared.canStop
                    Button {
                        Task { await stopWeeklySchedule() }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Stop Weekly Schedule")
                                .font(.caption)
                            if canStop {
                                Text("(\(stopRemaining) left today)")
                                    .font(.caption2)
                            } else {
                                Text("(limit reached)")
                                    .font(.caption2)
                            }
                        }
                        .foregroundColor(canStop ? .secondary : .red.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    }
                    .disabled(starting || !canStop)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundColor(isStatusError ? .red : .blue)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // ── Tracked apps & categories grid ──────────────────
                if !isSelectionEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Blocked Apps & Categories")
                            .font(.caption).bold()
                            .foregroundColor(.secondary)

                        let appTokens = Array(store.selection.applicationTokens)
                        let catCount  = store.selection.categoryTokens.count

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
            #else
            Text("Weekly schedule is only available on physical iOS devices.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding()
            #endif
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .onAppear { loadSavedState() }
    }

    // MARK: - Derived helpers

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
        if isSelectionEmpty { return "Select Apps to Block" }
        #if canImport(FamilyControls)
        let apps = store.selection.applicationTokens.count
        let cats = store.selection.categoryTokens.count
        switch (apps, cats) {
        case (_, 0): return "\(apps) App\(apps == 1 ? "" : "s") selected"
        case (0, _): return "\(cats) Categor\(cats == 1 ? "y" : "ies") selected"
        default:     return "\(cats) Categor\(cats == 1 ? "y" : "ies"), \(apps) App\(apps == 1 ? "" : "s") selected"
        }
        #else
        return "Selected"
        #endif
    }

    private var timeRangeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return "\(fmt.string(from: startTime)) – \(fmt.string(from: endTime))"
    }

    private var activeSummary: String {
        let dayNames = allDays
            .filter { selectedDays.contains($0.0) }
            .map { $0.1 }
        return "\(dayNames.joined(separator: " ")) · \(timeRangeLabel)"
    }

    // MARK: - Persistence

    private func saveDays() {
        if let data = try? JSONEncoder().encode(Array(selectedDays)) {
            Shared.defaults.set(data, forKey: Shared.weeklySelectedDaysKey)
        }
    }

    private func saveTimes() {
        let cal = Calendar.current
        Shared.defaults.set(cal.component(.hour,   from: startTime), forKey: Shared.weeklyStartHourKey)
        Shared.defaults.set(cal.component(.minute, from: startTime), forKey: Shared.weeklyStartMinuteKey)
        Shared.defaults.set(cal.component(.hour,   from: endTime),   forKey: Shared.weeklyEndHourKey)
        Shared.defaults.set(cal.component(.minute, from: endTime),   forKey: Shared.weeklyEndMinuteKey)
    }

    private func loadSavedState() {
        if let data = Shared.defaults.data(forKey: Shared.weeklySelectedDaysKey),
           let arr = try? JSONDecoder().decode([Int].self, from: data) {
            selectedDays = Set(arr)
        }
        let sh = Shared.defaults.integer(forKey: Shared.weeklyStartHourKey)
        let sm = Shared.defaults.integer(forKey: Shared.weeklyStartMinuteKey)
        let eh = Shared.defaults.integer(forKey: Shared.weeklyEndHourKey)
        let em = Shared.defaults.integer(forKey: Shared.weeklyEndMinuteKey)
        if sh != 0 || sm != 0 { startTime = Self.defaultTime(hour: sh, minute: sm) }
        if eh != 0 || em != 0 { endTime   = Self.defaultTime(hour: eh, minute: em) }
        isActive = Shared.defaults.bool(forKey: Shared.isWeeklyActiveKey)
        stopRemaining = WeeklyStopLimitManager.shared.remainingCount
    }

    // MARK: - Actions

    #if canImport(FamilyControls)
    private func startWeeklySchedule() async {
        starting = true
        await MainActor.run { statusMessage = ""; isStatusError = false }
        defer { Task { @MainActor in starting = false } }

        saveDays()
        saveTimes()

        let cal = Calendar.current
        let startH = cal.component(.hour,   from: startTime)
        let startM = cal.component(.minute, from: startTime)
        let endH   = cal.component(.hour,   from: endTime)
        let endM   = cal.component(.minute, from: endTime)

        let center = DeviceActivityCenter()
        center.stopMonitoring((1...7).map { DeviceActivityName("weeklyBlock_\($0)") })

        var failed = false
        for weekday in selectedDays {
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: startH, minute: startM, weekday: weekday),
                intervalEnd:   DateComponents(hour: endH,   minute: endM,   weekday: weekday),
                repeats: true
            )
            do {
                try center.startMonitoring(
                    DeviceActivityName("weeklyBlock_\(weekday)"),
                    during: schedule,
                    events: [:]
                )
            } catch {
                failed = true
                await MainActor.run {
                    statusMessage = "❌ \(error.localizedDescription)"
                    isStatusError = true
                }
            }
        }

        if !failed {
            Shared.defaults.set(true, forKey: Shared.isWeeklyActiveKey)
            Analytics.weeklyScheduleStarted(
                days: selectedDays.count,
                startHour: cal.component(.hour, from: startTime),
                endHour: cal.component(.hour, from: endTime),
                appCount: store.selection.applicationTokens.count,
                categoryCount: store.selection.categoryTokens.count
            )
            await MainActor.run { isActive = true; statusMessage = "" }
        }
    }

    private func stopWeeklySchedule() async {
        guard WeeklyStopLimitManager.shared.canStop else { return }

        WeeklyStopLimitManager.shared.recordStop()
        await MainActor.run { stopRemaining = WeeklyStopLimitManager.shared.remainingCount }

        let center = DeviceActivityCenter()
        center.stopMonitoring((1...7).map { DeviceActivityName("weeklyBlock_\($0)") })

        #if canImport(ManagedSettings)
        let shieldStore = ManagedSettingsStore()
        shieldStore.shield.applications = nil
        shieldStore.shield.applicationCategories = nil
        shieldStore.shield.webDomains = nil
        #endif

        Shared.defaults.set(false, forKey: Shared.isWeeklyActiveKey)
        Analytics.weeklyScheduleStopped()
        await MainActor.run { isActive = false; statusMessage = "" }
    }
    #endif

    // MARK: - Helpers

    private static func defaultTime(hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}
