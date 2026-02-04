//
//  TodoModel.swift
//  ai_anti_doomscroll
//
//  SwiftData model for local-only todo storage
//

import Foundation
import SwiftData

@Model
final class LocalTodo {
    @Attribute(.unique) var id: Int
    var task: String
    var phone: String
    var appleId: String?
    var createdAt: Date
    var isDeleted: Bool // True if deleted (soft delete)
    
    init(id: Int = Int.random(in: 1000000...9999999), task: String, phone: String, appleId: String? = nil) {
        self.id = id
        self.task = task
        self.phone = phone
        self.appleId = appleId
        self.createdAt = Date()
        self.isDeleted = false
    }
    
    // Convert to Todo struct for UI
    func toNetworkTodo() -> Todo {
        Todo(id: id, task: task, phone: phone, appleId: appleId)
    }
}

// Todo struct for UI display
struct Todo: Identifiable, Codable {
    let id: Int
    var task: String
    var phone: String?
    var appleId: String?
}
