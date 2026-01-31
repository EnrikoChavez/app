//
//  ai_anti_doomscrollApp.swift
//  ai_anti_doomscroll
//
//  Created by Enriko Chavez on 8/16/25.
//

import SwiftUI
import SwiftData

@main
struct ai_anti_doomscrollApp: App {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    
    // SwiftData container for local storage
    let container: ModelContainer
    
    init() {
        // 1. Set up SwiftData container
        let schema = Schema([LocalTodo.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        container = try! ModelContainer(for: schema, configurations: [config])
        
        // 2. Handle login state from Keychain
        if let token = KeychainHelper.getToken(), !token.isEmpty {
            isLoggedIn = true
        } else {
            isLoggedIn = false
        }

        // 3. Set up a default base URL if nothing is saved yet
        if Shared.defaults.string(forKey: Shared.baseURLKey) == nil {
            Shared.defaults.set(
                "http://MacBook-Pro-80.local:8000",   // fallback dev URL
                forKey: Shared.baseURLKey
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                ContentView()
                    .modelContainer(container)
            } else {
                LoginView()
                    .modelContainer(container)
            }
        }
    }
}
