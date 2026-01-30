import SwiftUI

struct LogoutButton: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var showConfirm = false

    var body: some View {
        Button {
            showConfirm = true
        } label: {
            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
        }
        .tint(.red)
        .confirmationDialog("Log out?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) { performLogout() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func performLogout() {
        // 🔐 clear session artifacts
        KeychainHelper.deleteToken()
        UserDefaults.standard.removeObject(forKey: "userPhone")

        // 🫱🏽‍🫲🏾 clear shared app-group values used by the extension
        Shared.defaults.removeObject(forKey: Shared.phoneKey)
        Shared.defaults.removeObject(forKey: Shared.minutesKey)
        Shared.defaults.removeObject(forKey: Shared.selectionKey)
        // keep baseURL if you want; otherwise also remove it:
        // Shared.defaults.removeObject(forKey: Shared.baseURLKey)

        // 🚪 exit
        isLoggedIn = false
    }
}
