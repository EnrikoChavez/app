//
//  ai_anti_doomscrollApp.swift
//  ai_anti_doomscroll
//
//  Created by Enriko Chavez on 8/16/25.
//

import SwiftUI
@main
struct ai_anti_doomscrollApp: App {
    @AppStorage("isLoggedIn") private var isLoggedIn = false

    init() {
        // 1. Handle login state from Keychain
        if let token = KeychainHelper.getToken(), !token.isEmpty {
            isLoggedIn = true
        } else {
            isLoggedIn = false
        }

        // 2. Set up a default base URL if nothing is saved yet
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
            } else {
                LoginView()
            }
        }
    }
}
