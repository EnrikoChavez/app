//
//  TodoModel.swift
//  ai_anti_doomscroll
//
//  SwiftData model for local todo storage with sync support
//

import Foundation
import SwiftData

@Model
final class LocalTodo {
    @Attribute(.unique) var id: Int
    var task: String
    var phone: String
    var appleId: String?
    var syncedAt: Date?
    var createdAt: Date
    var isPendingSync: Bool // True if created/updated locally but not synced yet
    var isDeleted: Bool // True if deleted locally but not synced yet
    
    init(id: Int = Int.random(in: 1000000...9999999), task: String, phone: String, appleId: String? = nil) {
        self.id = id
        self.task = task
        self.phone = phone
        self.appleId = appleId
        self.createdAt = Date()
        self.isPendingSync = true
        self.isDeleted = false
    }
    
    // Convert to network format
    func toNetworkTodo() -> Todo {
        Todo(id: id, task: task)
    }
}

// Network Todo model (for API communication)
struct Todo: Identifiable, Codable {
    let id: Int
    var task: String
    var phone: String?
    var appleId: String?
    var syncedAt: String? // ISO8601 date string from server
}
