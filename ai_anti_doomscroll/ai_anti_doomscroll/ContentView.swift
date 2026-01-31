import SwiftUI
import UIKit

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(DeviceActivity)
import DeviceActivity
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

struct Todo: Identifiable, Codable {
    let id: Int
    var task: String
}

struct ContentView: View {
    @State private var serverResponse: String = "Idle"
    @State private var todos: [Todo] = []
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
                    ScrollView {
                        VStack(spacing: 28) {
                            // 1. Modern Header
                            headerSection
                            
                            // 2. Status Hero Card
                            statusHeroCard
                            
                            // 3. Today's Tasks
                            TodoSection(
                                todos: $todos,
                                newTask: $newTask,
                                phone: phone,
                                addTodo: addTodo,
                                deleteTodo: deleteTodo
                            )
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(20)
                            
                            // 4. Configuration Section
                            ScreenTimeSection(
                                authStatus: $authStatus,
                                showPicker: $showPicker,
                                minutesText: $minutesText,
                                starting: $starting,
                                store: store,
                                updateAuthStatus: updateAuthStatus
                            )
                            
                            // Logout
                            Button(action: logout) {
                                Text("Logout")
                                    .font(.subheadline).bold()
                                    .foregroundColor(.red)
                                    .padding()
                            }
                            .padding(.bottom, 30)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear(perform: onAppAppear)
            .sheet(isPresented: $showingCallView) {
                VoiceCallView(callManager: callManager, accessToken: nil) {
                    let finalTranscript = callManager.transcript
                    showingCallView = false
                    if !finalTranscript.isEmpty {
                        evaluateCall(transcript: finalTranscript)
                    }
                }
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
    
    var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Anti-Doomscroll")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                }
                Text("Stay focused, stay free.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
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
            
            if isBlocked {
                // Call Button (only visible when premium)
                if subscriptionManager.isPremium {
                    Button(action: startVoiceCall) {
                        HStack {
                            if isStartingCall {
                                ProgressView().tint(.white).padding(.trailing, 8)
                            } else {
                                Image(systemName: "mic.fill")
                            }
                            Text(isStartingCall ? "Connecting..." : "Talk to AI to Unblock")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .disabled(isStartingCall)
                }
            } else {
                // Test Call Button (only visible when premium)
                if subscriptionManager.isPremium {
                    Button(action: startVoiceCall) {
                        HStack {
                            Image(systemName: "testtube.2")
                            Text("Practice AI Call")
                        }
                        .font(.footnote).bold()
                        .foregroundColor(.blue)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }
            
            // Manual Unblock Fallback
            Button(action: unblockApps) {
                Text(isBlocked ? "Manual Unblock (Emergency)" : "Reset Blocks")
                    .font(.caption2).bold()
                    .foregroundColor(.secondary)
                    .underline()
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
    }
    
    // MARK: - Logic
    
    func onAppAppear() {
        Shared.defaults.set(APIConfig.baseURL, forKey: Shared.baseURLKey)
        Shared.defaults.set(phone, forKey: Shared.phoneKey)
        #if canImport(FamilyControls)
        Task { await updateAuthStatus() }
        #endif
        fetchTodos()
        checkBlockStatus()
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.checkBlockStatus()
        }
    }
    
    func fetchTodos() {
        networkManager.fetchTodos { items in
            DispatchQueue.main.async {
                self.todos = items
                if let defaults = UserDefaults(suiteName: Shared.appGroupId),
                   let data = try? JSONEncoder().encode(items) {
                    defaults.set(data, forKey: Shared.todosKey)
                }
            }
        }
    }
    
    func addTodo() {
        guard !newTask.isEmpty else { return }
        networkManager.addTodo(newTask) { _ in self.fetchTodos() }
        newTask = ""
    }
    
    func deleteTodo(id: Int) {
        networkManager.deleteTodo(id: id) { _ in self.fetchTodos() }
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

    func startVoiceCall() {
        isStartingCall = true
        networkManager.createHumeSession(todos: todos, minutes: Int(minutesText) ?? 15) { result in
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
                        self.callManager.startCall(websocketURL: wsURL, initialVariables: variables)
                        self.showingCallView = true
                    } else {
                        self.activeAlert = .error(message: "Server did not return a call URL.")
                    }
                case .failure(let error):
                    self.activeAlert = .error(message: "Connection failed: \(error.localizedDescription)")
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

