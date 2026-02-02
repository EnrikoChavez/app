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
    @ObservedObject var store: SelectionStore
    var updateAuthStatus: () async -> Void
    @FocusState private var isMinutesFocused: Bool
    
    private var isSelectionEmpty: Bool {
        #if canImport(FamilyControls)
        store.selection.applicationTokens.isEmpty
        && store.selection.categoryTokens.isEmpty
        && store.selection.webDomainTokens.isEmpty
        #else
        true
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monitoring Dashboard")
                        .font(.headline)
                    Text("Configure your limits")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Status indicator - subtle request access button
                if !authStatus.contains("approved") {
                    Button {
                        #if canImport(FamilyControls)
                        Task { await requestAuth() }
                        #endif
                    } label: {
                        Text("Request Access")
                            .font(.caption2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundColor(.secondary)
                            .cornerRadius(6)
                    }
                }
            }

            #if canImport(FamilyControls)
            VStack(spacing: 16) {
                // Config Grid
                HStack(spacing: 12) {
                    // App Selection
                    Button(action: { showPicker = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "apps.iphone")
                                .font(.title3)
                            Text(isSelectionEmpty ? "Select Apps" : "\(store.selection.applicationTokens.count) Apps")
                                .font(.caption).bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                    .familyActivityPicker(isPresented: $showPicker, selection: $store.selection)

                    // Time Limit - directly editable with larger text
                    VStack(spacing: 8) {
                        Image(systemName: "timer")
                            .font(.title3)
                        HStack(spacing: 6) {
                            TextField("15", text: $minutesText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 30)
                                .focused($isMinutesFocused)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.body).bold()
                            Text("min")
                                .font(.body).bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.pink.opacity(0.1))
                    .foregroundColor(.pink)
                    .cornerRadius(12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isMinutesFocused = true
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isMinutesFocused = false
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }

                // Control Buttons
                HStack(spacing: 12) {
                    Button {
                        Task { await startMonitoring() }
                    } label: {
                        HStack {
                            if starting { ProgressView().padding(.trailing, 4) }
                            Text("Start Session")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSelectionEmpty ? Color.gray.opacity(0.2) : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(starting || stopping || isSelectionEmpty)

                    Button {
                        Task { await stopMonitoring() }
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.headline)
                            .frame(width: 54, height: 50)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                    }
                    .disabled(starting || stopping)
                }
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundColor(isStatusError ? .red : .green)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
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
    }
    
    #if canImport(FamilyControls)
    private func requestAuth() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await updateAuthStatus()
        } catch {
            await MainActor.run { authStatus = "Error: \(error.localizedDescription)" }
        }
    }

    private func startMonitoring() async {
        starting = true
        await MainActor.run {
            statusMessage = ""
            isStatusError = false
        }
        defer { starting = false }

        let baseMinutes = Int(minutesText) ?? 15
        Shared.defaults.set(baseMinutes, forKey: Shared.minutesKey)

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        let multiples = [1, 2, 3, 4]
        for m in multiples {
            let mins = m * baseMinutes
            let name = DeviceActivityEvent.Name("usageThreshold_\(mins)")
            let event = DeviceActivityEvent(
                applications: store.selection.applicationTokens,
                categories:  store.selection.categoryTokens,
                webDomains:  store.selection.webDomainTokens,
                threshold: DateComponents(minute: mins)
            )
            events[name] = event
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
            
            await MainActor.run {
                statusMessage = "✅ Monitoring active (\(baseMinutes) min limit)"
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
        await MainActor.run {
            stopping = true
            statusMessage = ""
        }
        defer { Task { @MainActor in stopping = false } }
        
        let center = DeviceActivityCenter()
        center.stopMonitoring([DeviceActivityName("dailyMonitor")])
        
        #if canImport(ManagedSettings)
        if #available(iOS 16.0, *) {
            let blockStore = ManagedSettingsStore()
            blockStore.shield.applications = nil
        }
        #endif
        
        await MainActor.run {
            statusMessage = "✅ Monitoring stopped"
            isStatusError = false
        }
    }
    #endif
}
