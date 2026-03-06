//
//  TodoModel.swift
//  ai_anti_doomscroll
//
//  SwiftData model for local-only todo storage
//
//  NOTE: Any new fields added to LocalTodo MUST be Optional (e.g. Bool?, String?)
//  so SwiftData can perform a lightweight migration on existing stores without
//  wiping user data. Use `?? defaultValue` when reading them.
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
    var isDeleted: Bool

    // Optional so SwiftData can migrate existing records (nil == false)
    var isTodaysFocus: Bool?
    var isCompleted: Bool?

    init(id: Int = Int.random(in: 1000000...9999999),
         task: String,
         phone: String,
         appleId: String? = nil,
         isTodaysFocus: Bool = false,
         isCompleted: Bool = false) {
        self.id = id
        self.task = task
        self.phone = phone
        self.appleId = appleId
        self.createdAt = Date()
        self.isDeleted = false
        self.isTodaysFocus = isTodaysFocus
        self.isCompleted = isCompleted
    }

    func toNetworkTodo() -> Todo {
        Todo(id: id,
             task: task,
             phone: phone,
             appleId: appleId,
             isTodaysFocus: isTodaysFocus ?? false,
             isCompleted: isCompleted ?? false)
    }
}

// Todo struct for UI display
struct Todo: Identifiable, Codable {
    let id: Int
    var task: String
    var phone: String?
    var appleId: String?
    var isTodaysFocus: Bool = false
    var isCompleted: Bool = false
}
