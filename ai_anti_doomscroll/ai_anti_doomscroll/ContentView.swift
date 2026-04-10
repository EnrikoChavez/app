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
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var todoRepository = TodoRepository()
    
    @State private var serverResponse: String = "Idle"
    @State private var newTask = ""
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var phone = UserDefaults.standard.string(forKey: "userPhone") ?? ""

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
    @State private var showingHowItWorks = false
    
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
    
    @AppStorage("hasSkippedSignup") private var hasSkippedSignup = false
    @State private var showPaywall = false
    @State private var showSignup = false
    @State private var isEvaluating = false
    @State private var pendingExtraStop = false
    @State private var isStartingCall = false
    @State private var callLimitInfo: CallLimitInfo? = nil
    @State private var isCheckingLimit = false
    @State private var manualUnblockLimitInfo: ManualUnblockLimitInfo? = nil
    @State private var selectedCompanion = "1"
    private let companionNames = [
        "1": "Voice 1",
        "2": "Voice 2",
        "3": "Voice 3",
        "4": "Voice 4",
        "5": "Voice 5",
        "6": "Voice 6"
    ]

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
                AppTheme.backgroundGradient(for: colorScheme).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header at top (fixed)
                    headerSection
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    // Tab Content
                    ZStack {
                        callsChatsTab.opacity(selectedTab == 0 ? 1 : 0)
                        todosTab.opacity(selectedTab == 1 ? 1 : 0)
                        galleryTab.opacity(selectedTab == 2 ? 1 : 0)
                    }
                    .environment(\.systemColorScheme, colorScheme)
                    .environment(\.colorScheme, .light)
                    }
                    .overlay(alignment: .bottom) {
                        // Custom Tab Bar at bottom
                        customTabBar
                            .background(AppTheme.cardBg(for: colorScheme))
                            .shadow(color: Color.black.opacity(0.10), radius: 8, y: -3)
                            .environment(\.colorScheme, .light)
                    }
                }
            .navigationBarHidden(true)
            .onAppear(perform: onAppAppear)
            .onChange(of: subscriptionManager.isPremium) { isPremium in
                if isPremium { showPaywall = false }
            }
            .onChange(of: subscriptionManager.isLoading) { isLoading in
                if !isLoading && isLoggedIn && !subscriptionManager.isPremium { showPaywall = true }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView(subscriptionManager: subscriptionManager, onSkip: {
                    showPaywall = false
                })
            }
            .fullScreenCover(isPresented: $showSignup) {
                SignupPromptView()
            }
                .sheet(isPresented: $showingCallView) {
                    VoiceCallView(callManager: callManager, accessToken: nil) {
                        handleCallEnd()
                        showingCallView = false
                    }
                }
                .sheet(isPresented: $showingChatView) {
                    ChatView(chatManager: chatManager, todos: todoRepository.focusTodos) {
                        showingChatView = false
                        // Only evaluate if conversation wasn't cancelled
                        handleChatEnd()
                    }
                }
                .sheet(isPresented: $showingSettingsMenu) {
                    SettingsMenuView(isPresented: $showingSettingsMenu, onLogout: logout)
                }
                .sheet(isPresented: $showingHowItWorks) {
                    HowItWorksView()
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
            tabBarItem(icon: "door.right.hand.open", label: "Free Up Time",  tag: 0)
            tabBarItem(icon: "checklist",            label: "Tasks",    tag: 1)
            tabBarItem(icon: "checkmark.seal",       label: "Gallery",  tag: 2)
        }
        .background(AppTheme.cardBg(for: colorScheme))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator).opacity(0.4)),
            alignment: .top
        )
    }

    @ViewBuilder
    private func tabBarItem(icon: String, label: String, tag: Int) -> some View {
        let isSelected = selectedTab == tag
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedTab = tag
        }) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? AppTheme.tabActive : AppTheme.tabInactive)
        }
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
            
            HStack(spacing: 12) {
                Image(systemName: colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 14))
                    .foregroundColor(colorScheme == .dark ? Color(white: 0.80) : .gray)

                Button("How to\nuse app") {
                    showingHowItWorks = true
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(colorScheme == .dark ? Color(white: 0.80) : .gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(colorScheme == .dark ? Color(white: 0.80) : Color.gray, lineWidth: 1.5))
                .cornerRadius(7)

                Button(action: {
                    showingSettingsMenu = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(colorScheme == .dark ? Color(white: 0.75) : .primary)
                }
            }
        }
        .padding(.top, 20)
    }
    
    var statusHeroCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(isBlocked ? Color.red.opacity(colorScheme == .dark ? 0.25 : 0.1) : Color.green.opacity(colorScheme == .dark ? 0.25 : 0.1))
                        .frame(width: 100, height: 60)
                    
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
                        Text("AI companion is still available to chat while apps are not blocked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            // Companion picker + Call Limit Info
            HStack(spacing: 8) {
                Menu {
                    ForEach(["1", "2", "3", "4", "5", "6"], id: \.self) { key in
                        Button(action: { selectedCompanion = key }) {
                            if key == selectedCompanion {
                                Label(companionNames[key] ?? key, systemImage: "checkmark")
                            } else {
                                Text(companionNames[key] ?? key)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(companionNames[selectedCompanion] ?? "Voice")
                            .font(.caption).bold()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(colorScheme == .dark ? Color(white: 0.94) : AppTheme.cardBg(for: colorScheme))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                }

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
                    .background((limitInfo.canCall ? Color.blue : Color.orange).opacity(colorScheme == .dark ? 0.25 : 0.1))
                    .cornerRadius(8)
                }
            }
            
            if isBlocked {
                ZStack {
                    VStack(spacing: 12) {
                        Button(action: { startVoiceCall(companion: selectedCompanion) }) {
                            HStack {
                                if isStartingCall || isCheckingLimit {
                                    ProgressView().tint(.white).padding(.trailing, 8)
                                } else {
                                    Image(systemName: "mic.fill")
                                }
                                Text(isStartingCall ? "Connecting..." : isCheckingLimit ? "Checking..." : "Call \(companionNames[selectedCompanion] ?? "Companion")")
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
                    if !subscriptionManager.isLoading && (!isLoggedIn || !subscriptionManager.isPremium) {
                        SubscriptionGateOverlay(cornerRadius: 15, isLoggedIn: isLoggedIn) { handleGateTap() }
                    }
                }
            } else {
                ZStack {
                    HStack(spacing: 12) {
                        Button(action: { startVoiceCall(companion: selectedCompanion) }) {
                            HStack {
                                Image(systemName: "testtube.2")
                                Text("Practice Call")
                            }
                            .font(.caption2).bold()
                            .foregroundColor((callLimitInfo?.canCall ?? true) ? .blue : .gray)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background((callLimitInfo?.canCall ?? true) ? Color.blue.opacity(colorScheme == .dark ? 0.25 : 0.1) : Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.1))
                            .cornerRadius(10)
                        }
                        .disabled(!(callLimitInfo?.canCall ?? true))

                        Button(action: startTextChat) {
                            HStack {
                                Image(systemName: "message")
                                Text("Practice Chat")
                            }
                            .font(.caption2).bold()
                            .foregroundColor(.green)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.green.opacity(colorScheme == .dark ? 0.25 : 0.1))
                            .cornerRadius(10)
                        }

                        Button(action: {
                            if let limitInfo = manualUnblockLimitInfo, !limitInfo.canUnblock {
                                activeAlert = .error(message: "You've used all \(limitInfo.limitCount) manual unblocks for today. Please use AI voice call or text chat to unblock.")
                            } else {
                                unblockApps()
                            }
                        }) {
                            HStack(spacing: 4) {
                                if let limitInfo = manualUnblockLimitInfo {
                                    Text("Decrease Daily Block Counter (\(limitInfo.remainingCount)/\(limitInfo.limitCount))")
                                        .font(.caption2).bold()
                                        .foregroundColor(limitInfo.canUnblock ? .secondary : .red)
                                } else {
                                    Text("Decrease Daily Block Counter")
                                        .font(.caption2).bold()
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(colorScheme == .dark ? Color(white: 0.93) : Color(.systemGray5))
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
                        }
                        .disabled(manualUnblockLimitInfo?.canUnblock == false)
                    }
                    if !subscriptionManager.isLoading && (!isLoggedIn || !subscriptionManager.isPremium) {
                        SubscriptionGateOverlay(cornerRadius: 10, isLoggedIn: isLoggedIn) { handleGateTap() }
                    }
                }
            }

            // Manual Unblock Fallback (blocked state only)
            if isBlocked {
                Button(action: {
                    if let limitInfo = manualUnblockLimitInfo, !limitInfo.canUnblock {
                        activeAlert = .error(message: "You've used all \(limitInfo.limitCount) manual unblocks for today. Please use AI voice call or text chat to unblock.")
                    } else {
                        unblockApps()
                    }
                }) {
                    HStack(spacing: 4) {
                        if let limitInfo = manualUnblockLimitInfo {
                            Text("Manual Daily Unblocks (\(limitInfo.remainingCount)/\(limitInfo.limitCount))")
                                .font(.caption2).bold()
                                .foregroundColor(limitInfo.canUnblock ? .secondary : .red)
                        } else {
                            Text("Manual Unblock (Emergency)")
                                .font(.caption2).bold()
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
                .disabled(manualUnblockLimitInfo?.canUnblock == false)
            }
        }
        .padding(24)
        .background(AppTheme.cardBg(for: colorScheme))
        .cornerRadius(24)
        .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }
    
    // Tab 1: Calls & Chats
    var callsChatsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                statusHeroCard
                    .padding(.horizontal)
                    .padding(.top, 20)

                ScreenTimeSection(
                    authStatus: $authStatus,
                    showPicker: $showPicker,
                    minutesText: $minutesText,
                    starting: $starting,
                    store: store,
                    updateAuthStatus: updateAuthStatus,
                    onBlockStateChanged: { checkBlockStatus() },
                    isPremium: subscriptionManager.isLoading || subscriptionManager.isPremium,
                    isLoggedIn: subscriptionManager.isLoading || isLoggedIn,
                    onSubscribeTap: handleGateTap,
                    onCallForExtraStop: {
                        pendingExtraStop = true
                        startVoiceCall(companion: selectedCompanion)
                    },
                    onChatForExtraStop: {
                        pendingExtraStop = true
                        startTextChat()
                    }
                )
                .padding(.horizontal)

            }
            .padding(.bottom, 100)
        }
        .background(Color.clear.ignoresSafeArea())
    }

    @ViewBuilder
    private func instructionRow(step: String, icon: String, color: Color, title: String, detail: String, action: (() -> Void)? = nil) -> some View {
        let content = HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline).bold()
                    if action != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption).bold()
                            .foregroundColor(color)
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(AppTheme.rowBackground)
        .cornerRadius(12)

        if let action = action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
    
    // Tab 2: Todos
    var todosTab: some View {
        ScrollView {
            TodoSection(
                overallTodos: todoRepository.overallTodos,
                focusTodos: todoRepository.focusTodos,
                newTask: $newTask,
                addTodo: addTodo,
                deleteTodo: deleteTodo,
                moveToFocus: moveToFocus,
                moveToOverall: moveToOverall,
                completeTodo: completeTodo
            )
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        .background(Color.clear.ignoresSafeArea())
    }

    // Tab 4: Gallery (completed tasks)
    var galleryTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                TaskCompletionGraphView(completedTodos: todoRepository.completedTodos)
                    .padding(.horizontal)
                    .padding(.top, 20)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gallery")
                                .font(.title3).bold()
                            Text("Tasks you've completed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(todoRepository.completedTodos.count)")
                            .font(.caption).bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }

                    if todoRepository.completedTodos.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No completed tasks yet.\nMark tasks as done to see them here.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        let calendar = Calendar.current
                        let grouped = Dictionary(grouping: todoRepository.completedTodos) { todo in
                            calendar.startOfDay(for: todo.completedAt ?? todo.createdAt)
                        }
                        let sortedGroups = grouped.map { (day: $0.key, todos: $0.value) }
                            .sorted { $0.day > $1.day }

                        VStack(spacing: 16) {
                            ForEach(sortedGroups, id: \.day) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(galleryDayLabel(group.day))
                                        .font(.caption).bold()
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 2)

                                    VStack(spacing: 8) {
                                        ForEach(group.todos) { todo in
                                            HStack(alignment: .top, spacing: 12) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green.opacity(0.6))
                                                    .font(.caption)
                                                    .padding(.top, 3)

                                                Text(todo.task)
                                                    .font(.body)
                                                    .foregroundColor(.secondary)
                                                    .fixedSize(horizontal: false, vertical: true)

                                                Spacer()

                                                Button(action: { removeFromGallery(id: todo.id) }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.gray.opacity(0.4))
                                                }
                                            }
                                            .padding(14)
                                            .background(AppTheme.rowBackground)
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.cardBg(for: colorScheme))
                .cornerRadius(20)
                .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
        .background(Color.clear.ignoresSafeArea())
    }

    // Tab 3: Set Timer (Weekly Schedule)
    var monitoringTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                WeeklyScheduleSection(
                    isPremium: subscriptionManager.isLoading || subscriptionManager.isPremium,
                    isLoggedIn: subscriptionManager.isLoading || isLoggedIn,
                    onSubscribeTap: handleGateTap
                )
                .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
        .background(Color.clear.ignoresSafeArea())
    }
    
    // MARK: - Logic
    
    func handleGateTap() {
        if isLoggedIn {
            showPaywall = true
        } else {
            showSignup = true
        }
    }

    func onAppAppear() {
        Shared.defaults.set(APIConfig.baseURL, forKey: Shared.baseURLKey)
        Shared.defaults.set(phone, forKey: Shared.phoneKey)
        
        // Initialize repository with model context
        todoRepository.setModelContext(modelContext)

        // Consume task entered during onboarding — add it straight to Today's Focus
        if let pendingTask = UserDefaults.standard.string(forKey: "onboardingPendingFocusTask"),
           !pendingTask.isEmpty {
            let appleId = UserDefaults.standard.string(forKey: "appleId")
            todoRepository.addTodoToFocus(pendingTask, phone: phone, appleId: appleId)
            UserDefaults.standard.removeObject(forKey: "onboardingPendingFocusTask")
        }
        
        if isLoggedIn && !subscriptionManager.isPremium && !subscriptionManager.isLoading {
            showPaywall = true
        }

        #if canImport(FamilyControls)
        Task { await updateAuthStatus() }
        #endif
        
        checkBlockStatus()

        // Pre-activate audio session so the first call works reliably
        callManager.activateAudioSession()

        // Show cached call limit instantly, then refresh from server
        loadCachedCallLimit()
        checkCallLimit()
        checkManualUnblockLimit()
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.checkBlockStatus()
        }
    }
    
    func addTodo() {
        guard !newTask.isEmpty else { return }
        let appleId = UserDefaults.standard.string(forKey: "appleId") ?? nil
        todoRepository.addTodo(newTask, phone: phone, appleId: appleId)
        newTask = ""
        Analytics.todoAdded()
    }
    
    func deleteTodo(id: Int) {
        if let todo = todoRepository.todos.first(where: { $0.id == id }) {
            todoRepository.deleteTodo(todo)
            Analytics.todoDeleted()
        }
    }

    func moveToFocus(id: Int) {
        if let todo = todoRepository.todos.first(where: { $0.id == id }) {
            todoRepository.moveToFocus(todo)
            Analytics.todoSetAsFocus()
        }
    }

    func moveToOverall(id: Int) {
        if let todo = todoRepository.todos.first(where: { $0.id == id }) {
            todoRepository.moveToOverall(todo)
            Analytics.todoRemovedFromFocus()
        }
    }

    func completeTodo(id: Int) {
        if let todo = todoRepository.todos.first(where: { $0.id == id }) {
            todoRepository.completeTodo(todo)
            Analytics.todoCompleted()
        }
    }

    func galleryDayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }

    func removeFromGallery(id: Int) {
        if let todo = todoRepository.todos.first(where: { $0.id == id }) {
            todoRepository.removeFromGallery(todo)
        }
    }
    
    func logout() {
        Analytics.loggedOut()
        Analytics.reset()
        KeychainHelper.deleteToken()
        UserDefaults.standard.removeObject(forKey: "userPhone")
        UserDefaults.standard.removeObject(forKey: "userId")
        Shared.defaults.removeObject(forKey: Shared.phoneKey)
        isLoggedIn = false
    }
    
    func updateAuthStatus() async {
        let status = AuthorizationCenter.shared.authorizationStatus
        await MainActor.run { authStatus = "\(status)" }
    }
    
    func checkBlockStatus() {
        #if canImport(ManagedSettings)
        if #available(iOS 16.0, *) {
            // If the UserDefaults flag says blocked but the shield is not actually active,
            // the flag is stale (e.g. iOS reset the ManagedSettingsStore). Clear it.
            let shieldIsActuallyActive = blockManager.shieldIsActive
            if blockManager.isBlocked && !shieldIsActuallyActive {
                print("🧹 checkBlockStatus: stale isBlocked flag detected — clearing")
                if let defaults = UserDefaults(suiteName: Shared.appGroupId) {
                    defaults.set(false, forKey: Shared.isBlockedKey)
                    defaults.removeObject(forKey: Shared.blockedAtKey)
                }
                isBlocked = false
                blockedAt = nil
                return
            }
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
    
    // Core unblock — always updates the shield and UI, no limit checks
    private func performUnblock() {
        let wasTimedBlock = UserDefaults(suiteName: Shared.appGroupId)?.bool(forKey: Shared.isTimedBlockActiveKey) ?? false

        #if canImport(ManagedSettings)
        if #available(iOS 16.0, *) { blockManager.unblockApps() }
        #endif
        isBlocked = false
        blockedAt = nil
        if let defaults = UserDefaults(suiteName: Shared.appGroupId) {
            defaults.set(false, forKey: Shared.isBlockedKey)
            defaults.removeObject(forKey: Shared.blockedAtKey)
            defaults.set(false, forKey: Shared.isTimedBlockActiveKey)
            defaults.removeObject(forKey: Shared.timedBlockEndTimeKey)
        }

        // Restart monitoring with a fresh schedule so thresholds reset from zero.
        // Skip for timed block mode — no DeviceActivity events were registered.
        #if canImport(FamilyControls)
        if !wasTimedBlock {
            store.restartMonitoring()
        }
        #endif
    }

    func unblockApps() {
        Analytics.manualUnblockAttempted()
        guard UnblockLimitManager.shared.canUnblock else {
            Analytics.manualUnblockLimitReached()
            activeAlert = .error(message: "You've reached your daily limit of \(UnblockLimitManager.shared.limitCount) manual unblocks. Please use AI voice call or text chat to unblock.")
            return
        }
        UnblockLimitManager.shared.recordUnblock()
        refreshUnblockLimit()
        performUnblock()
        Analytics.manualUnblockSucceeded()
    }

    func checkManualUnblockLimit() {
        refreshUnblockLimit()
    }

    private func refreshUnblockLimit() {
        let mgr = UnblockLimitManager.shared
        manualUnblockLimitInfo = ManualUnblockLimitInfo(
            canUnblock: mgr.canUnblock,
            remainingCount: mgr.remainingCount,
            usedCount: mgr.usedCount,
            limitCount: mgr.limitCount
        )
        print("📊 Manual unblock limit: \(mgr.remainingCount)/\(mgr.limitCount) remaining")
    }

    private static let callLimitCacheKey = "callLimitCache"

    func loadCachedCallLimit() {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.callLimitCacheKey),
              let dateStr = dict["date"] as? String,
              dateStr == Self.todayString(),
              let canCall = dict["canCall"] as? Bool,
              let remaining = dict["remainingSeconds"] as? Double,
              let used = dict["usedSeconds"] as? Double,
              let limit = dict["limitSeconds"] as? Double else { return }
        callLimitInfo = CallLimitInfo(canCall: canCall, remainingSeconds: remaining, usedSeconds: used, limitSeconds: limit)
    }

    func saveCallLimitCache(_ info: CallLimitInfo) {
        UserDefaults.standard.set([
            "date": Self.todayString(),
            "canCall": info.canCall,
            "remainingSeconds": info.remainingSeconds,
            "usedSeconds": info.usedSeconds,
            "limitSeconds": info.limitSeconds
        ], forKey: Self.callLimitCacheKey)
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    func checkCallLimit() {
        isCheckingLimit = true
        networkManager.checkCallLimit { result in
            DispatchQueue.main.async {
                self.isCheckingLimit = false
                switch result {
                case .success(let info):
                    self.callLimitInfo = info
                    self.saveCallLimitCache(info)
                case .failure(let error):
                    print("⚠️ Failed to check call limit: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func startVoiceCall(companion: String = "1") {
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
                    
                    self.isStartingCall = true
                    self.networkManager.createHumeSession(todos: self.todoRepository.focusTodos, minutes: Int(self.minutesText) ?? 15, companion: companion) { result in
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
                                    Analytics.voiceCallStarted()
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
        let callDuration = callManager.callDuration
        let wasExtraStop = pendingExtraStop
        pendingExtraStop = false
        print("📱 iOS: Call ended. Duration calculated: \(callDuration)s, extraStop=\(wasExtraStop)")

        callManager.stopCall()

        // Tell the server the call ended; duration is measured server-side.
        networkManager.endHumeSession { result in
            switch result {
            case .success:
                print("✅ iOS: Call session ended on server")
                DispatchQueue.main.async {
                    self.checkCallLimit()
                }
            case .failure(let error):
                print("❌ iOS: Failed to end call session: \(error.localizedDescription)")
            }
        }

        if !finalTranscript.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.evaluateCall(transcript: finalTranscript, grantExtraStop: wasExtraStop)
            }
        }
    }
    
    func startTextChat() {
        chatManager.startChat(todos: todoRepository.focusTodos)
        showingChatView = true
        Analytics.chatStarted()
    }
    
    func handleChatEnd() {
        // Skip evaluation if conversation was cancelled
        if chatManager.wasCancelled {
            print("📱 Chat was cancelled, skipping evaluation")
            pendingExtraStop = false
            return
        }

        let wasExtraStop = pendingExtraStop
        pendingExtraStop = false

        // Get transcript from chat manager (conversation already ended in ChatView)
        chatManager.endConversation { [self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transcript):
                    print("📱 Chat transcript received: \(transcript.prefix(100))...")
                    if !transcript.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            self.evaluateCall(transcript: transcript, isChat: true, grantExtraStop: wasExtraStop)
                        }
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
    
    func evaluateCall(transcript: String, isChat: Bool = false, grantExtraStop: Bool = false) {
        isEvaluating = true
        networkManager.evaluateTranscript(transcript: transcript) { result in
            DispatchQueue.main.async {
                self.isEvaluating = false
                switch result {
                case .success(let data):
                    let unblock = data["unblock"] as? Bool ?? false
                    let message = data["message"] as? String ?? ""
                    if isChat {
                        Analytics.chatEnded(unblocked: unblock)
                    } else {
                        Analytics.voiceCallEnded(durationSeconds: self.callManager.callDuration, unblocked: unblock)
                    }
                    if grantExtraStop {
                        if unblock { StopMonitoringLimitManager.shared.grantExtraStop() }
                    } else {
                        if unblock { self.performUnblock() }
                    }
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

