import SwiftUI
import UIKit
import MessageUI

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(DeviceActivity)
import DeviceActivity
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

// Todo model moved to TodoModel.swift

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var todoRepository = TodoRepository()
    
    @State private var serverResponse: String = "Idle"
    @State private var newTask = ""
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var phone = UserDefaults.standard.string(forKey: "userPhone") ?? "123"

    @StateObject private var store = SelectionStore()
    @State private var showPicker = false
    @State private var minutesText = "15"
    @State private var authStatus = "Unknown"
    @State private var starting = false
    @State private var isBlocked = false
    @State private var blockedAt: Date? = nil
    
    // Hume AI Call State
    @StateObject private var callManager = HumeCallManager()
    @State private var showingCallView = false
    @State private var websocketURL: String? = nil
    @State private var apiKey: String? = nil
    
    // Chat State
    @StateObject private var chatManager = ChatManager()
    @State private var showingChatView = false
    
    // Settings Menu
    @State private var showingSettingsMenu = false
    
    // Tab Selection
    @State private var selectedTab = 0
    
    // Subscription Management
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    // Unified Alert state
    @State private var activeAlert: AlertType?
    enum AlertType: Identifiable {
        case evaluation(message: String)
        case error(message: String)
        
        var id: Int {
            switch self {
            case .evaluation: return 1
            case .error: return 2
            }
        }
    }
    
    @State private var isEvaluating = false
    @State private var isStartingCall = false
    @State private var callLimitInfo: CallLimitInfo? = nil
    @State private var isCheckingLimit = false
    @State private var manualUnblockLimitInfo: ManualUnblockLimitInfo? = nil
    @State private var isCheckingUnblockLimit = false

    let networkManager = NetworkManager()
    
    #if canImport(ManagedSettings)
    @available(iOS 16.0, *)
    private var blockManager: BlockManager {
        BlockManager.shared
    }
    #endif
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                // Show paywall if not premium, otherwise show main content
                if !subscriptionManager.isPremium && !subscriptionManager.isLoading {
                    PaywallView(subscriptionManager: subscriptionManager)
                } else {
                    VStack(spacing: 0) {
                        // Header at top (fixed)
                        headerSection
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .padding(.bottom, 12)
                        
                        // Tab Content
                        TabView(selection: $selectedTab) {
                            // Tab 1: Calls & Chats
                            callsChatsTab
                                .tag(0)
                            
                            // Tab 2: Todos
                            todosTab
                                .tag(1)
                            
                            // Tab 3: Monitoring
                            monitoringTab
                                .tag(2)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }
                    .overlay(alignment: .bottom) {
                        // Custom Tab Bar at bottom
                        customTabBar
                            .background(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, y: -2)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear(perform: onAppAppear)
                .sheet(isPresented: $showingCallView) {
                    VoiceCallView(callManager: callManager, accessToken: nil) {
                        handleCallEnd()
                        showingCallView = false
                    }
                }
                .sheet(isPresented: $showingChatView) {
                    ChatView(chatManager: chatManager, todos: todoRepository.todos) {
                        showingChatView = false
                        // Only evaluate if conversation wasn't cancelled
                        handleChatEnd()
                    }
                }
                .sheet(isPresented: $showingSettingsMenu) {
                    SettingsMenuView(isPresented: $showingSettingsMenu, onLogout: logout)
                }
            .alert(item: $activeAlert) { type in
                switch type {
                case .evaluation(let message):
                    return Alert(title: Text("AI Evaluation"), message: Text(message), dismissButton: .default(Text("OK")))
                case .error(let message):
                    return Alert(title: Text("Error"), message: Text(message), dismissButton: .default(Text("OK")))
                }
            }
        }
    }
    
    // MARK: - Components
    
    var customTabBar: some View {
        HStack(spacing: 0) {
            // AI Tab
            Button(action: { selectedTab = 0 }) {
                VStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20))
                    Text("Unblock")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(selectedTab == 0 ? .blue : .gray)
            }
            
            // Tasks Tab
            Button(action: { selectedTab = 1 }) {
                VStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.system(size: 20))
                    Text("Tasks")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(selectedTab == 1 ? .blue : .gray)
            }
            
            // Monitor Tab
            Button(action: { selectedTab = 2 }) {
                VStack(spacing: 4) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 20))
                    Text("Monitor")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(selectedTab == 2 ? .blue : .gray)
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }
    
    var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Anti-Doomscroll")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                }
                Text("Stay focused when having tasks.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            // Settings button
            Button(action: {
                showingSettingsMenu = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        .padding(.top, 20)
    }
    
    var statusHeroCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(isBlocked ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: isBlocked ? "lock.fill" : "shield.checkered")
                        .font(.title)
                        .foregroundColor(isBlocked ? .red : .green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isBlocked ? "Apps are Blocked" : "Apps are Open")
                        .font(.headline)
                    if isBlocked, let blockedAt = blockedAt {
                        Text("Locked since \(blockedAt, style: .time)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Monitoring your progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            // Call Limit Info
            if let limitInfo = callLimitInfo {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(limitInfo.canCall ? .blue : .orange)
                    Text("\(Int(limitInfo.remainingSeconds))s remaining today for calling")
                        .font(.caption)
                        .foregroundColor(limitInfo.canCall ? .blue : .orange)
                    if !limitInfo.canCall {
                        Text("(Limit reached)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background((limitInfo.canCall ? Color.blue : Color.orange).opacity(0.1))
                .cornerRadius(8)
            }
            
            if isBlocked {
                // AI Interaction Buttons (only visible when premium)
                if subscriptionManager.isPremium {
                    VStack(spacing: 12) {
                        // Voice Call Button
                        Button(action: startVoiceCall) {
                            HStack {
                                if isStartingCall || isCheckingLimit {
                                    ProgressView().tint(.white).padding(.trailing, 8)
                                } else {
                                    Image(systemName: "mic.fill")
                                }
                                Text(isStartingCall ? "Connecting..." : isCheckingLimit ? "Checking..." : "Talk to AI to Unblock")
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background((callLimitInfo?.canCall ?? true) ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .shadow(color: ((callLimitInfo?.canCall ?? true) ? Color.blue : Color.gray).opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(isStartingCall || isCheckingLimit || !(callLimitInfo?.canCall ?? true))
                        
                        // Text Chat Button
                        Button(action: startTextChat) {
                            HStack {
                                Image(systemName: "message.fill")
                                Text("Text AI to Unblock (Harder to Convince)")
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                    }
                }
            } else {
                // Test Buttons (only visible when premium)
                if subscriptionManager.isPremium {
                    HStack(spacing: 12) {
                        // Test Voice Call Button
                        Button(action: startVoiceCall) {
                            HStack {
                                Image(systemName: "testtube.2")
                                Text("Practice Call")
                            }
                            .font(.footnote).bold()
                            .foregroundColor((callLimitInfo?.canCall ?? true) ? .blue : .gray)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background((callLimitInfo?.canCall ?? true) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .disabled(!(callLimitInfo?.canCall ?? true))
                        
                        // Test Text Chat Button
                        Button(action: startTextChat) {
                            HStack {
                                Image(systemName: "message")
                                Text("Practice Chat")
                            }
                            .font(.footnote).bold()
                            .foregroundColor(.green)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                }
            }
            
            // Manual Unblock Fallback
            Button(action: {
                if let limitInfo = manualUnblockLimitInfo, !limitInfo.canUnblock {
                    activeAlert = .error(message: "You've used all \(limitInfo.limitCount) manual unblocks for today. Please use AI voice call or text chat to unblock.")
                } else {
                    unblockApps()
                }
            }) {
                HStack(spacing: 4) {
                    if isCheckingUnblockLimit {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    if let limitInfo = manualUnblockLimitInfo {
                        Text(isBlocked ? "Manual Unblocks (\(limitInfo.remainingCount)/\(limitInfo.limitCount))" : "Decrease Unblock Counter (\(limitInfo.remainingCount)/\(limitInfo.limitCount))")
                            .font(.caption2).bold()
                            .foregroundColor(limitInfo.canUnblock ? .secondary : .red)
                    } else {
                        Text(isBlocked ? "Manual Unblock (Emergency)" : "Reset Blocks")
                            .font(.caption2).bold()
                            .foregroundColor(.secondary)
                    }
                }
                .underline()
            }
            .disabled(isCheckingUnblockLimit || (manualUnblockLimitInfo?.canUnblock == false && isBlocked))
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
    }
    
    // Tab 1: Calls & Chats
    var callsChatsTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                statusHeroCard
                    .padding(.horizontal)
                    .padding(.top, 20)
            }
            .padding(.bottom, 100) // Extra padding for bottom tab bar
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
    
    // Tab 2: Todos
    var todosTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                TodoSection(
                    todos: Binding(
                        get: { todoRepository.todos },
                        set: { _ in }
                    ),
                    newTask: $newTask,
                    phone: phone,
                    addTodo: addTodo,
                    deleteTodo: deleteTodo
                )
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .padding(.horizontal)
                .padding(.top, 20)
            }
            .padding(.bottom, 100) // Extra padding for bottom tab bar
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
    
    // Tab 3: Monitoring Dashboard
    var monitoringTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                ScreenTimeSection(
                    authStatus: $authStatus,
                    showPicker: $showPicker,
                    minutesText: $minutesText,
                    starting: $starting,
                    store: store,
                    updateAuthStatus: updateAuthStatus
                )
                .padding(.horizontal)
                .padding(.top, 20)
            }
            .padding(.bottom, 100) // Extra padding for bottom tab bar
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
    
    // MARK: - Logic
    
    func onAppAppear() {
        Shared.defaults.set(APIConfig.baseURL, forKey: Shared.baseURLKey)
        Shared.defaults.set(phone, forKey: Shared.phoneKey)
        
        // Initialize repository with model context
        todoRepository.setModelContext(modelContext)
        
        #if canImport(FamilyControls)
        Task { await updateAuthStatus() }
        #endif
        
        // Sync todos from cloud (repository loads local first)
        todoRepository.syncToCloud()
        checkBlockStatus()
        
        // Check call limit on load
        checkCallLimit()
        checkManualUnblockLimit()
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.checkBlockStatus()
            self.todoRepository.syncToCloud()
        }
    }
    
    func addTodo() {
        guard !newTask.isEmpty else { return }
        // Get Apple ID (from StoreKit or UserDefaults)
        let appleId = UserDefaults.standard.string(forKey: "appleId") ?? nil
        todoRepository.addTodo(newTask, phone: phone, appleId: appleId)
        newTask = ""
    }
    
    func deleteTodo(id: Int) {
        if let todo = todoRepository.todos.first(where: { $0.id == id }) {
            todoRepository.deleteTodo(todo)
        }
    }
    
    func logout() { isLoggedIn = false }
    
    func updateAuthStatus() async {
        let status = AuthorizationCenter.shared.authorizationStatus
        await MainActor.run { authStatus = "\(status)" }
    }
    
    func checkBlockStatus() {
        #if canImport(ManagedSettings)
        if #available(iOS 16.0, *) {
            isBlocked = blockManager.isBlocked
            blockedAt = blockManager.blockedAt
        }
        #endif
        if let defaults = UserDefaults(suiteName: Shared.appGroupId) {
            if !isBlocked { isBlocked = defaults.bool(forKey: Shared.isBlockedKey) }
            if blockedAt == nil {
                let timestamp = defaults.double(forKey: Shared.blockedAtKey)
                if timestamp > 0 { blockedAt = Date(timeIntervalSince1970: timestamp) }
            }
        }
    }
    
    func unblockApps() {
        // Check limit before unblocking
        guard let limitInfo = manualUnblockLimitInfo, limitInfo.canUnblock else {
            activeAlert = .error(message: "You've reached your daily limit of 3 manual unblocks. Please use AI voice call or text chat to unblock.")
            return
        }
        
        // Record the manual unblock
        networkManager.recordManualUnblock { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Refresh limit info after recording
                    checkManualUnblockLimit()
                case .failure(let error):
                    print("❌ Failed to record manual unblock: \(error.localizedDescription)")
                }
            }
        }
        
        #if canImport(ManagedSettings)
        if #available(iOS 16.0, *) { blockManager.unblockApps() }
        #endif
        isBlocked = false
        blockedAt = nil
        if let defaults = UserDefaults(suiteName: Shared.appGroupId) {
            defaults.set(false, forKey: Shared.isBlockedKey)
            defaults.removeObject(forKey: Shared.blockedAtKey)
        }
    }
    
    func checkManualUnblockLimit() {
        isCheckingUnblockLimit = true
        networkManager.checkManualUnblockLimit { result in
            DispatchQueue.main.async {
                isCheckingUnblockLimit = false
                switch result {
                case .success(let limitInfo):
                    self.manualUnblockLimitInfo = limitInfo
                    print("📊 Manual unblock limit: \(limitInfo.remainingCount)/\(limitInfo.limitCount) remaining")
                case .failure(let error):
                    print("❌ Failed to check manual unblock limit: \(error.localizedDescription)")
                    // On error, allow unblock (fail open)
                    self.manualUnblockLimitInfo = ManualUnblockLimitInfo(canUnblock: true, remainingCount: 3, usedCount: 0, limitCount: 3)
                }
            }
        }
    }

    func checkCallLimit() {
        isCheckingLimit = true
        networkManager.checkCallLimit { result in
            DispatchQueue.main.async {
                self.isCheckingLimit = false
                switch result {
                case .success(let info):
                    self.callLimitInfo = info
                case .failure(let error):
                    print("⚠️ Failed to check call limit: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func startVoiceCall() {
        // First check the call limit
        isCheckingLimit = true
        networkManager.checkCallLimit { [self] result in
            DispatchQueue.main.async {
                self.isCheckingLimit = false
                switch result {
                case .success(let info):
                    self.callLimitInfo = info
                    if !info.canCall {
                        self.activeAlert = .error(message: "Daily call limit reached. You've used \(Int(info.usedSeconds))s of \(Int(info.limitSeconds))s today. Try again tomorrow!")
                        return
                    }
                    
                    // Limit check passed, proceed with call
                    self.isStartingCall = true
                    self.networkManager.createHumeSession(todos: self.todoRepository.todos, minutes: Int(self.minutesText) ?? 15) { result in
                        DispatchQueue.main.async {
                            self.isStartingCall = false
                            switch result {
                            case .success(let data):
                                if let wsURL = data["websocket_url"] {
                                    var variables: [String: String]?
                                    if let varsString = data["initial_variables"],
                                       let varsData = varsString.data(using: .utf8),
                                       let varsDict = try? JSONSerialization.jsonObject(with: varsData) as? [String: String] {
                                        variables = varsDict
                                    }
                                    // Pass the remaining time as max duration for the call
                                    let maxDuration = info.remainingSeconds
                                    // Set callback for automatic call termination
                                    self.callManager.onCallEnded = {
                                        DispatchQueue.main.async {
                                            self.handleCallEnd()
                                            self.showingCallView = false
                                        }
                                    }
                                    self.callManager.startCall(websocketURL: wsURL, initialVariables: variables, maxDurationSeconds: maxDuration)
                                    self.showingCallView = true
                                } else {
                                    self.activeAlert = .error(message: "Server did not return a call URL.")
                                }
                            case .failure(let error):
                                // Check if it's a 429 (rate limit) error
                                if let nsError = error as NSError?, nsError.code == 429 {
                                    self.activeAlert = .error(message: "Daily call limit reached. Try again tomorrow!")
                                } else {
                                    self.activeAlert = .error(message: "Connection failed: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                case .failure(let error):
                    self.activeAlert = .error(message: "Failed to check call limit: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func handleCallEnd() {
        let finalTranscript = callManager.transcript
        // Get call duration BEFORE stopCall() resets it (if not already stopped)
        let callDuration = callManager.callDuration
        print("📱 iOS: Call ended. Duration calculated: \(callDuration)s")
        
        // Stop the call (this resets callStartTime) - safe to call multiple times
        callManager.stopCall()
        
        // Record call duration
        print("📱 iOS: Sending call duration to backend: \(callDuration)s")
        networkManager.recordCallDuration(durationSeconds: callDuration) { result in
            switch result {
            case .success:
                print("✅ iOS: Call duration recorded successfully: \(callDuration)s")
                // Refresh limit info
                DispatchQueue.main.async {
                    self.checkCallLimit()
                }
            case .failure(let error):
                print("❌ iOS: Failed to record call duration: \(error.localizedDescription)")
            }
        }
        
        if !finalTranscript.isEmpty {
            evaluateCall(transcript: finalTranscript)
        }
    }
    
    func startTextChat() {
        chatManager.startChat(todos: todoRepository.todos)
        showingChatView = true
    }
    
    func handleChatEnd() {
        // Skip evaluation if conversation was cancelled
        if chatManager.wasCancelled {
            print("📱 Chat was cancelled, skipping evaluation")
            return
        }
        
        // Get transcript from chat manager (conversation already ended in ChatView)
        chatManager.endConversation { [self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transcript):
                    print("📱 Chat transcript received: \(transcript.prefix(100))...")
                    if !transcript.isEmpty {
                        evaluateCall(transcript: transcript)
                    } else {
                        // If transcript is empty, user might have cancelled
                        print("⚠️ Chat transcript is empty")
                    }
                case .failure(let error):
                    print("❌ Failed to get chat transcript: \(error.localizedDescription)")
                    // If conversation was cancelled, don't show error
                    if (error as NSError).code != 404 {
                        self.activeAlert = .error(message: "Failed to get chat transcript: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func evaluateCall(transcript: String) {
        isEvaluating = true
        networkManager.evaluateTranscript(transcript: transcript) { result in
            DispatchQueue.main.async {
                self.isEvaluating = false
                switch result {
                case .success(let data):
                    let unblock = data["unblock"] as? Bool ?? false
                    let message = data["message"] as? String ?? ""
                    if unblock { self.unblockApps() }
                    self.activeAlert = .evaluation(message: message)
                case .failure(let error):
                    self.activeAlert = .error(message: "Evaluation failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

// Note: Preview disabled due to complex system API dependencies
// (FamilyControls, DeviceActivity, ManagedSettings, StoreKit)
// To test the app, run it on a simulator or device

#Preview {
    ContentView()
}

