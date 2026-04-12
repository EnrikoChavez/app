//
//  SettingsMenuView.swift
//  ai_anti_doomscroll
//

import SwiftUI
import UIKit
import MessageUI

struct SettingsMenuView: View {
    @Binding var isPresented: Bool
    var onLogout: () -> Void
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasSkippedSignup") private var hasSkippedSignup = false
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showSignup = false
    @State private var showHowItWorks = false
    @State private var showWeeklySchedule = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showDeleteConfirmation = false
    @State private var showMailComposer = false
    @State private var isDeleting = false
    @State private var showDeleteError = false
    @State private var deleteError: String?
    
    let networkManager = NetworkManager()
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Toggle(isOn: Binding(
                        get: { isDarkMode },
                        set: { isDarkMode = $0; Analytics.darkModeToggled(isDark: $0) }
                    )) {
                        HStack {
                            Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                            Text(isDarkMode ? "Dark Mode" : "Light Mode")
                        }
                    }
                }

                Section {
                    Button(action: { showHowItWorks = true }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("How to Use App")
                        }
                    }

                    Button(action: {
                        UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
                        UserDefaults.standard.set(false, forKey: "hasSkippedSignup")
                        UserDefaults.standard.removeObject(forKey: "onboardingPendingFocusTask")
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Rewatch Onboarding")
                        }
                    }

                    Button(action: { showWeeklySchedule = true }) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Weekly Block Schedule")
                                Text("⚠️ Cannot be stopped by AI — strict lock-in")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }

                Section {
                    Button(action: {
                        showTerms = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Terms of Service")
                        }
                    }
                    
                    Button(action: {
                        showPrivacy = true
                    }) {
                        HStack {
                            Image(systemName: "hand.raised")
                            Text("Privacy Policy")
                        }
                    }
                    
                    Button(action: {
                        if MFMailComposeViewController.canSendMail() {
                            showMailComposer = true
                        } else {
                            // Fallback: copy email to clipboard
                            UIPasteboard.general.string = "enriko.kurtz@gmail.com"
                        }
                    }) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Contact Us")
                        }
                    }
                }
                
                if isLoggedIn {
                    Section {
                        Button(action: {
                            onLogout()
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                Text("Logout")
                            }
                        }
                    }

                    Section {
                        Button(role: .destructive, action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Account")
                            }
                        }
                        .disabled(isDeleting)
                    }
                } else {
                    Section {
                        Button(action: {
                            isPresented = false
                            hasSkippedSignup = false
                        }) {
                            HStack {
                                Image(systemName: "person.circle")
                                Text("Sign In / Create Account")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showHowItWorks) {
                HowItWorksView()
            }
            .sheet(isPresented: $showWeeklySchedule) {
                WeeklyScheduleSheetView(isPremium: true, isLoggedIn: true, onSubscribeTap: {})
            }
            .sheet(isPresented: $showTerms) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposeView(recipient: "enriko.kurtz@gmail.com")
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.")
            }
            .alert("Error", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteError ?? "Failed to delete account. Please try again.")
            }
        }
    }
    
    private func deleteAccount() {
        isDeleting = true
        networkManager.deleteAccount { result in
            DispatchQueue.main.async {
                isDeleting = false
                switch result {
                case .success:
                    Analytics.accountDeleted()
                    Analytics.reset()
                    KeychainHelper.deleteToken()
                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                    UserDefaults.standard.removeObject(forKey: "userPhone")
                    UserDefaults.standard.removeObject(forKey: "userId")
                    UserDefaults.standard.removeObject(forKey: "appleId")
                    isPresented = false
                case .failure(let error):
                    print("❌ Failed to delete account: \(error.localizedDescription)")
                    deleteError = error.localizedDescription
                    showDeleteError = true
                }
            }
        }
    }
}

struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Terms of Service")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Last Updated: \(Date().formatted(date: .long, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        SectionView(title: "1. Acceptance of Terms", content: """
                        By downloading, installing, or using the Anti-Doomscroll app, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the app.
                        """)
                        
                        SectionView(title: "2. Description of Service", content: """
                        Anti-Doomscroll is a productivity app designed to help users manage their screen time and stay focused on their tasks. The app uses AI technology to help users unblock restricted apps after completing their tasks.
                        """)
                        
                        SectionView(title: "3. User Responsibilities", content: """
                        You are responsible for maintaining the confidentiality of your account and for all activities that occur under your account. You agree to use the app only for lawful purposes and in accordance with these Terms.
                        """)
                        
                        SectionView(title: "4. Subscription and Payments", content: """
                        Some features of the app require a paid subscription. Subscriptions are managed through Apple's App Store and are subject to Apple's terms and conditions. You can cancel your subscription at any time through your Apple account settings.
                        """)
                        
                        SectionView(title: "5. Limitation of Liability", content: """
                        The app is provided "as is" without warranties of any kind. We are not liable for any damages arising from your use of the app.
                        """)
                        
                        SectionView(title: "6. Changes to Terms", content: """
                        We reserve the right to modify these terms at any time. Continued use of the app after changes constitutes acceptance of the new terms.
                        """)
                    }
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Last Updated: \(Date().formatted(date: .long, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        SectionView(title: "1. Information We Collect", content: """
                        We collect minimal information necessary for app functionality:
                        - An opaque numeric user ID (generated at login — no name, phone number, or email is stored)
                        - Voice call transcripts (temporarily processed for AI evaluation, then discarded)
                        - Text chat messages (temporarily processed for AI evaluation, then discarded)
                        
                        During login, your phone number is used transiently only to verify your identity via OTP. It is not stored after a session token is issued. Apple Sign In similarly results only in an opaque user ID being retained — no email or name is kept.
                        
                        We do NOT collect or store:
                        - Your phone number (beyond the transient OTP verification step)
                        - Your task lists (todos) - these are stored exclusively on your device
                        - Personal notes or sensitive information
                        - Screen time monitoring data - stored locally only
                        """)
                        
                        SectionView(title: "2. Local Storage", content: """
                        The following data is stored exclusively on your device and never sent to our servers:
                        - Your task lists (todos) - stored using iOS SwiftData, accessible only on your device
                        - Screen time monitoring settings and app selections
                        - App blocking preferences
                        
                        This local data persists as long as the app is installed on your device and is included in your device backups. It is only deleted if you uninstall the app or manually clear app data.
                        """)
                        
                        SectionView(title: "3. How We Use Your Information", content: """
                        We use your information solely to:
                        - Authenticate your account via an opaque numeric user ID
                        - Process AI voice calls and text chats for app unblocking
                        - Evaluate conversations to determine if apps should be unblocked
                        - Track usage limits (call duration) for daily limits
                        
                        We do NOT use your information for:
                        - Advertising or marketing
                        - Selling to third parties
                        - Building user profiles
                        - Any purpose other than providing the app's core functionality
                        """)
                        
                        SectionView(title: "4. Data Storage", content: """
                        We store minimal data on our servers:
                        - An opaque numeric user ID (no phone number or identifying information)
                        - Premium subscription status
                        - Daily usage limits (call duration)
                        
                        All sensitive data (todos, task lists, screen time settings) is stored exclusively on your device using iOS SwiftData. We do not have access to this information.
                        
                        Voice call and text chat transcripts are processed temporarily for AI evaluation and are not permanently stored. We use industry-standard security measures to protect any data we do store.
                        """)
                        
                        SectionView(title: "5. Third-Party Services", content: """
                        We use the following third-party services:
                        - Hume AI (for voice interactions) - processes audio during calls only
                        - Google Gemini (for text chat and evaluation) - processes messages temporarily for AI responses
                        - Apple StoreKit (for subscription management) - handles payment processing
                        
                        These services have their own privacy policies governing data use. We only send data necessary for the service to function (e.g., audio for voice calls, messages for chat).
                        """)
                        
                        SectionView(title: "6. Your Rights", content: """
                        You have the right to:
                        - Access your account data (subscription status, usage limits)
                        - Request deletion of your account and all server-stored data
                        - Delete local data by uninstalling the app
                        - Export your local data (todos are stored in iOS SwiftData, accessible through device backups)
                        
                        To delete your account, use the "Delete Account" option in Settings. This will remove all data stored on our servers. Local data (todos, settings) will remain on your device until you uninstall the app.
                        """)
                        
                        SectionView(title: "7. Children's Privacy", content: """
                        Our app is not intended for children under 13. We do not knowingly collect information from children.
                        """)
                        
                        SectionView(title: "8. Contact Us", content: """
                        If you have questions about this Privacy Policy, please contact us at: enriko.kurtz@gmail.com
                        """)
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SectionView: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([recipient])
        composer.setSubject("Anti-Doomscroll App Support")
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

struct WeeklyScheduleSheetView: View {
    @Environment(\.dismiss) var dismiss
    var isPremium: Bool
    var isLoggedIn: Bool
    var onSubscribeTap: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    WeeklyScheduleSection(
                        isPremium: isPremium,
                        isLoggedIn: isLoggedIn,
                        onSubscribeTap: onSubscribeTap
                    )
                }
                .padding()
            }
            .navigationTitle("Weekly Block Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct HowItWorksView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    howItWorksRow(icon: "checklist", color: .blue,
                        title: "Add your tasks",
                        detail: "Add everything you need to do in the Tasks tab. Mark a few as Today's Focus — the AI will ask about those when you want to unblock.")

                    howItWorksRow(icon: "hourglass", color: .pink,
                        title: "Set a block",
                        detail: "Usage Limit blocks apps after a set number of minutes of use. Timed Block locks apps immediately for a fixed duration. Both options are in the Unblock tab.")

                    howItWorksRow(icon: "apps.iphone", color: .indigo,
                        title: "Pick what to block",
                        detail: "Select the apps you want to block. Your selection applies to both blocking modes.")

                    howItWorksRow(icon: "phone", color: .purple,
                        title: "Call or chat the AI to unblock",
                        detail: "Tap Call or Text AI and tell it what you've been working on. If you manage to be, your apps unlock.")

                    howItWorksRow(icon: "hand.tap", color: .gray,
                        title: "Manual unblock",
                        detail: "Tap \"Decrease Counter\" to unblock without the AI. You get 20 per day.")
                }
                .padding(20)
            }
            .navigationTitle("How to Use App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func howItWorksRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline).bold()
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(colorScheme == .dark ? Color(white: 0.93) : Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    SettingsMenuView(isPresented: .constant(true), onLogout: {})
}
