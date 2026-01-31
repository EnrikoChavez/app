//
//  TodoRepository.swift
//  ai_anti_doomscroll
//
//  Repository pattern for offline-first todo sync
//

import Foundation
import SwiftData
import Combine

@MainActor
class TodoRepository: ObservableObject {
    @Published var todos: [Todo] = []
    @Published var isSyncing = false
    @Published var lastSyncError: String?
    
    private let networkManager = NetworkManager()
    var modelContext: ModelContext?
    private var syncTimer: Timer?
    
    // Initialize without context - will be set in onAppear
    init() {
        // Context will be set later
    }
    
    func setModelContext(_ context: ModelContext) {
        guard modelContext == nil else { return } // Only set once
        self.modelContext = context
        loadLocalTodos()
        startPeriodicSync()
    }
    
    // MARK: - Local Storage
    
    private func loadLocalTodos() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<LocalTodo>(
            predicate: #Predicate { !$0.isDeleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let localTodos = try context.fetch(descriptor)
            todos = localTodos.map { $0.toNetworkTodo() }
            print("📱 Loaded \(todos.count) todos from local storage")
        } catch {
            print("❌ Failed to load local todos: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    func addTodo(_ task: String, phone: String, appleId: String?) {
        guard let context = modelContext else { return }
        
        // Create local todo immediately
        let localTodo = LocalTodo(task: task, phone: phone, appleId: appleId)
        context.insert(localTodo)
        
        do {
            try context.save()
            
            // Update published todos
            let newTodo = Todo(id: localTodo.id, task: localTodo.task, phone: localTodo.phone, appleId: localTodo.appleId)
            todos.insert(newTodo, at: 0)
            
            print("✅ Todo added locally: \(task)")
            
            // Sync to cloud in background
            syncToCloud()
        } catch {
            print("❌ Failed to save todo locally: \(error)")
        }
    }
    
    func updateTodo(_ todo: Todo, newTask: String) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<LocalTodo>(
            predicate: #Predicate { $0.id == todo.id }
        )
        
        do {
            if let localTodo = try context.fetch(descriptor).first {
                localTodo.task = newTask
                localTodo.isPendingSync = true
                localTodo.syncedAt = nil
                try context.save()
                
                // Update published todos
                if let index = todos.firstIndex(where: { $0.id == todo.id }) {
                    todos[index].task = newTask
                }
                
                print("✅ Todo updated locally: \(newTask)")
                syncToCloud()
            }
        } catch {
            print("❌ Failed to update todo: \(error)")
        }
    }
    
    func deleteTodo(_ todo: Todo) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<LocalTodo>(
            predicate: #Predicate { $0.id == todo.id }
        )
        
        do {
            if let localTodo = try context.fetch(descriptor).first {
                // Mark as deleted locally
                localTodo.isDeleted = true
                localTodo.isPendingSync = true
                localTodo.syncedAt = nil
                try context.save()
                
                // Remove from published todos
                todos.removeAll { $0.id == todo.id }
                
                print("✅ Todo deleted locally: \(todo.task)")
                syncToCloud()
            }
        } catch {
            print("❌ Failed to delete todo: \(error)")
        }
    }
    
    // MARK: - Cloud Sync
    
    func syncToCloud() {
        guard !isSyncing else { return }
        isSyncing = true
        lastSyncError = nil
        
        Task {
            await performSync()
            await MainActor.run {
                isSyncing = false
            }
        }
    }
    
    private func performSync() async {
        guard let context = modelContext else { return }
        
        // 1. Get pending todos (created/updated locally)
        let pendingDescriptor = FetchDescriptor<LocalTodo>(
            predicate: #Predicate { $0.isPendingSync && !$0.isDeleted }
        )
        
        // 2. Get deleted todos
        let deletedDescriptor = FetchDescriptor<LocalTodo>(
            predicate: #Predicate { $0.isDeleted && $0.isPendingSync }
        )
        
        do {
            let pendingTodos = try context.fetch(pendingDescriptor)
            let deletedTodos = try context.fetch(deletedDescriptor)
            
            // 3. Sync pending todos (create/update)
            for localTodo in pendingTodos {
                if localTodo.syncedAt == nil {
                    // New todo - create on server
                    await createTodoOnServer(localTodo)
                } else {
                    // Updated todo - update on server
                    await updateTodoOnServer(localTodo)
                }
            }
            
            // 4. Sync deleted todos
            for localTodo in deletedTodos {
                await deleteTodoOnServer(localTodo)
            }
            
            // 5. Pull latest from server
            await pullFromServer()
            
        } catch {
            print("❌ Sync error: \(error)")
            await MainActor.run {
                lastSyncError = error.localizedDescription
            }
        }
    }
    
    private func createTodoOnServer(_ localTodo: LocalTodo) async {
        let phone = UserDefaults.standard.string(forKey: "userPhone") ?? "123"
        let appleId = localTodo.appleId
        
        await withCheckedContinuation { continuation in
            networkManager.addTodo(localTodo.task, phone: phone, appleId: appleId) { [weak self] result in
                Task { @MainActor in
                    guard let self = self, let context = self.modelContext else {
                        continuation.resume()
                        return
                    }
                    
                    switch result {
                    case .success(let serverTodo):
                        // Update local todo with server ID and mark as synced
                        localTodo.id = serverTodo.id
                        localTodo.isPendingSync = false
                        localTodo.syncedAt = Date()
                        
                        // Update appleId if server returned one
                        if let serverAppleId = serverTodo.appleId {
                            localTodo.appleId = serverAppleId
                        }
                        
                        do {
                            try context.save()
                            print("✅ Synced new todo to server: \(localTodo.task) (ID: \(serverTodo.id))")
                        } catch {
                            print("❌ Failed to update local todo after sync: \(error)")
                        }
                        
                    case .failure(let error):
                        print("⚠️ Failed to sync todo to server: \(error.localizedDescription)")
                        // Keep isPendingSync = true, will retry later
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    private func updateTodoOnServer(_ localTodo: LocalTodo) async {
        let phone = UserDefaults.standard.string(forKey: "userPhone") ?? "123"
        let appleId = localTodo.appleId
        
        await withCheckedContinuation { continuation in
            networkManager.updateTodo(localTodo.id, task: localTodo.task, phone: phone, appleId: appleId) { [weak self] result in
                Task { @MainActor in
                    guard let self = self, let context = self.modelContext else {
                        continuation.resume()
                        return
                    }
                    
                    switch result {
                    case .success:
                        localTodo.isPendingSync = false
                        localTodo.syncedAt = Date()
                        
                        do {
                            try context.save()
                            print("✅ Synced todo update to server: \(localTodo.task)")
                        } catch {
                            print("❌ Failed to update local todo after sync: \(error)")
                        }
                        
                    case .failure(let error):
                        print("⚠️ Failed to sync todo update: \(error.localizedDescription)")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    private func deleteTodoOnServer(_ localTodo: LocalTodo) async {
        networkManager.deleteTodo(id: localTodo.id) { [weak self] result in
            Task { @MainActor in
                guard let self = self, let context = self.modelContext else { return }
                
                switch result {
                case .success:
                    // Permanently delete from local storage
                    context.delete(localTodo)
                    
                    do {
                        try context.save()
                        print("✅ Synced todo deletion to server")
                    } catch {
                        print("❌ Failed to delete local todo after sync: \(error)")
                    }
                    
                case .failure(let error):
                    print("⚠️ Failed to sync todo deletion: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func pullFromServer() async {
        let phone = UserDefaults.standard.string(forKey: "userPhone") ?? "123"
        
        await withCheckedContinuation { continuation in
            networkManager.fetchTodos(phone: phone) { [weak self] result in
                Task { @MainActor in
                    guard let self = self, let context = self.modelContext else {
                        continuation.resume()
                        return
                    }
                    
                    switch result {
                    case .success(let serverTodos):
                        // Merge server todos with local ones
                        for serverTodo in serverTodos {
                            let descriptor = FetchDescriptor<LocalTodo>(
                                predicate: #Predicate { $0.id == serverTodo.id }
                            )
                            
                            do {
                                if let existing = try context.fetch(descriptor).first {
                                    // Update existing if server is newer
                                    if let serverSyncedStr = serverTodo.syncedAt,
                                       let serverSynced = ISO8601DateFormatter().date(from: serverSyncedStr) {
                                        if existing.syncedAt == nil || serverSynced > existing.syncedAt! {
                                            existing.task = serverTodo.task
                                            existing.appleId = serverTodo.appleId
                                            existing.syncedAt = serverSynced
                                            existing.isPendingSync = false
                                        }
                                    }
                                } else {
                                    // New todo from server - add locally
                                    let localTodo = LocalTodo(
                                        id: serverTodo.id,
                                        task: serverTodo.task,
                                        phone: serverTodo.phone ?? phone,
                                        appleId: serverTodo.appleId
                                    )
                                    localTodo.isPendingSync = false
                                    if let syncedStr = serverTodo.syncedAt,
                                       let synced = ISO8601DateFormatter().date(from: syncedStr) {
                                        localTodo.syncedAt = synced
                                    }
                                    context.insert(localTodo)
                                }
                            } catch {
                                print("❌ Failed to merge server todo: \(error)")
                            }
                        }
                        
                        try? context.save()
                        self.loadLocalTodos()
                        print("✅ Pulled \(serverTodos.count) todos from server")
                        
                    case .failure(let error):
                        print("⚠️ Failed to pull from server: \(error.localizedDescription)")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Periodic Sync
    
    private func startPeriodicSync() {
        // Sync every 30 seconds when app is active
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.syncToCloud()
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}
