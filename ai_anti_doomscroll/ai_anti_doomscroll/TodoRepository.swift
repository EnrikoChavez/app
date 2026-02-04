//
//  TodoRepository.swift
//  ai_anti_doomscroll
//
//  Local-only todo storage using SwiftData
//

import Foundation
import SwiftData
import Combine

@MainActor
class TodoRepository: ObservableObject {
    @Published var todos: [Todo] = []
    
    var modelContext: ModelContext?
    
    // Initialize without context - will be set in onAppear
    init() {
        // Context will be set later
    }
    
    func setModelContext(_ context: ModelContext) {
        guard modelContext == nil else { return } // Only set once
        self.modelContext = context
        loadLocalTodos()
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
        
        // Create local todo
        let localTodo = LocalTodo(task: task, phone: phone, appleId: appleId)
        context.insert(localTodo)
        
        do {
            try context.save()
            
            // Update published todos
            let newTodo = Todo(id: localTodo.id, task: localTodo.task, phone: localTodo.phone, appleId: localTodo.appleId)
            todos.insert(newTodo, at: 0)
            
            print("✅ Todo added locally: \(task)")
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
                try context.save()
                
                // Update published todos
                if let index = todos.firstIndex(where: { $0.id == todo.id }) {
                    todos[index].task = newTask
                }
                
                print("✅ Todo updated locally: \(newTask)")
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
                // Mark as deleted locally (soft delete)
                localTodo.isDeleted = true
                try context.save()
                
                // Remove from published todos
                todos.removeAll { $0.id == todo.id }
                
                print("✅ Todo deleted locally: \(todo.task)")
            }
        } catch {
            print("❌ Failed to delete todo: \(error)")
        }
    }
}
