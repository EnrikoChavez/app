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

    // Active todos not in focus and not completed
    var overallTodos: [Todo] {
        todos.filter { !$0.isTodaysFocus && !$0.isCompleted }
    }

    // Active focus todos not completed
    var focusTodos: [Todo] {
        todos.filter { $0.isTodaysFocus && !$0.isCompleted }
    }

    // Completed todos (shown in Gallery)
    var completedTodos: [Todo] {
        todos.filter { $0.isCompleted }
    }

    init() {}

    func setModelContext(_ context: ModelContext) {
        guard modelContext == nil else { return }
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
            syncTasksToShield()
            print("📱 Loaded \(todos.count) todos from local storage")
        } catch {
            print("❌ Failed to load local todos: \(error)")
        }
    }

    /// Writes current focus and all-task lists to the shared App Group UserDefaults
    /// so the ShieldConfigurationExtension can display them on the awareness shield.
    private func syncTasksToShield() {
        let focusTexts = focusTodos.map(\.task)
        let allTexts   = todos.filter { !$0.isCompleted }.map(\.task)
        if let focusData = try? JSONEncoder().encode(focusTexts) {
            Shared.defaults.set(focusData, forKey: Shared.shieldFocusTasksKey)
        }
        if let allData = try? JSONEncoder().encode(allTexts) {
            Shared.defaults.set(allData, forKey: Shared.shieldAllTasksKey)
        }
    }

    // MARK: - CRUD Operations

    func addTodo(_ task: String, phone: String, appleId: String?) {
        guard let context = modelContext else { return }

        let localTodo = LocalTodo(task: task, phone: phone, appleId: appleId, isTodaysFocus: false, isCompleted: false)
        context.insert(localTodo)

        do {
            try context.save()
            let newTodo = Todo(id: localTodo.id, task: localTodo.task, phone: localTodo.phone, appleId: localTodo.appleId, isTodaysFocus: false, isCompleted: false)
            todos.insert(newTodo, at: 0)
            syncTasksToShield()
            print("✅ Todo added: \(task)")
        } catch {
            print("❌ Failed to save todo: \(error)")
        }
    }

    func updateTodo(_ todo: Todo, newTask: String) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<LocalTodo>(predicate: #Predicate { $0.id == todo.id })

        do {
            if let localTodo = try context.fetch(descriptor).first {
                localTodo.task = newTask
                try context.save()
                if let index = todos.firstIndex(where: { $0.id == todo.id }) {
                    todos[index].task = newTask
                }
            }
        } catch {
            print("❌ Failed to update todo: \(error)")
        }
    }

    func deleteTodo(_ todo: Todo) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<LocalTodo>(predicate: #Predicate { $0.id == todo.id })

        do {
            if let localTodo = try context.fetch(descriptor).first {
                localTodo.isDeleted = true
                try context.save()
                todos.removeAll { $0.id == todo.id }
                syncTasksToShield()
                print("✅ Todo deleted: \(todo.task)")
            }
        } catch {
            print("❌ Failed to delete todo: \(error)")
        }
    }

    // MARK: - Focus Management

    func moveToFocus(_ todo: Todo) {
        setFocus(todo, isFocus: true)
    }

    func moveToOverall(_ todo: Todo) {
        setFocus(todo, isFocus: false)
    }

    private func setFocus(_ todo: Todo, isFocus: Bool) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<LocalTodo>(predicate: #Predicate { $0.id == todo.id })

        do {
            if let localTodo = try context.fetch(descriptor).first {
                localTodo.isTodaysFocus = isFocus
                try context.save()
                if let index = todos.firstIndex(where: { $0.id == todo.id }) {
                    todos[index].isTodaysFocus = isFocus
                }
                syncTasksToShield()
                print("✅ Todo '\(todo.task)' moved to \(isFocus ? "Today's Focus" : "Overall")")
            }
        } catch {
            print("❌ Failed to update focus status: \(error)")
        }
    }

    // MARK: - Completion

    func completeTodo(_ todo: Todo) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<LocalTodo>(predicate: #Predicate { $0.id == todo.id })

        do {
            if let localTodo = try context.fetch(descriptor).first {
                localTodo.isCompleted = true
                localTodo.isTodaysFocus = false
                try context.save()
                if let index = todos.firstIndex(where: { $0.id == todo.id }) {
                    todos[index].isCompleted = true
                    todos[index].isTodaysFocus = false
                }
                syncTasksToShield()
                print("✅ Todo completed: \(todo.task)")
            }
        } catch {
            print("❌ Failed to complete todo: \(error)")
        }
    }

    func removeFromGallery(_ todo: Todo) {
        deleteTodo(todo)
    }
}
