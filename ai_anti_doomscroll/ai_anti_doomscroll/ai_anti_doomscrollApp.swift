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
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    // SwiftData container for local storage
    let container: ModelContainer
    
    init() {
        // 1. Set up SwiftData container
        // SwiftData performs lightweight migration automatically when:
        //   - New fields are Optional (Bool?, String?, etc.)
        //   - Existing fields are removed
        // Always add new LocalTodo fields as Optional to preserve user data across updates.
        let schema = Schema([LocalTodo.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // If migration still fails for some unexpected reason, crash loudly in
            // development so it gets fixed — do NOT silently delete user data.
            fatalError("❌ SwiftData failed to load: \(error)\nCheck that any new LocalTodo fields are declared as Optional.")
        }
        
        // 2. Handle login state from Keychain
        if let token = KeychainHelper.getToken(), !token.isEmpty {
            isLoggedIn = true
        } else {
            isLoggedIn = false
        }

        // 3. Set up a default base URL if nothing is saved yet
        if Shared.defaults.string(forKey: Shared.baseURLKey) == nil {
            Shared.defaults.set(
                "http://MacBook-Pro-80.local:8000",
                forKey: Shared.baseURLKey
            )
        }

        // 4. Force logout when JWT token expires
        NotificationCenter.default.addObserver(
            forName: .sessionExpired,
            object: nil,
            queue: .main
        ) { [self] _ in
            isLoggedIn = false
        }
    }

    var body: some Scene {
        WindowGroup {
            if !hasSeenOnboarding {
                OnboardingView()
                    .modelContainer(container)
            } else if isLoggedIn {
                ContentView()
                    .modelContainer(container)
                    .preferredColorScheme(.light)
            } else {
                LoginView()
                    .modelContainer(container)
                    .preferredColorScheme(.light)
            }
        }
    }
}
