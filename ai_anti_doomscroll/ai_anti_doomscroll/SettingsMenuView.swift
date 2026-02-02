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
                    // Log out and clear all user data
                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                    UserDefaults.standard.removeObject(forKey: "userPhone")
                    UserDefaults.standard.removeObject(forKey: "appleId")
                    // Close settings menu - app will show login screen
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
        NavigationView {
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
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
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
                        We collect the following information:
                        - Phone number (for account identification)
                        - Apple ID (optional, for account linking)
                        - Task lists and usage data
                        - Screen time monitoring data (stored locally on your device)
                        - Voice call transcripts (processed for evaluation purposes)
                        """)
                        
                        SectionView(title: "2. How We Use Your Information", content: """
                        We use your information to:
                        - Provide and improve our services
                        - Process your requests to unblock apps
                        - Analyze app usage patterns
                        - Communicate with you about your account
                        """)
                        
                        SectionView(title: "3. Data Storage", content: """
                        Your data is stored securely on our servers. Screen time data is primarily stored locally on your device. We use industry-standard security measures to protect your information.
                        """)
                        
                        SectionView(title: "4. Third-Party Services", content: """
                        We use the following third-party services:
                        - Hume AI (for voice interactions)
                        - Google Gemini (for text chat and evaluation)
                        - Apple StoreKit (for subscription management)
                        
                        These services have their own privacy policies governing data use.
                        """)
                        
                        SectionView(title: "5. Your Rights", content: """
                        You have the right to:
                        - Access your personal data
                        - Request deletion of your account and data
                        - Opt out of certain data collection
                        - Export your data
                        """)
                        
                        SectionView(title: "6. Children's Privacy", content: """
                        Our app is not intended for children under 13. We do not knowingly collect information from children.
                        """)
                        
                        SectionView(title: "7. Contact Us", content: """
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

#Preview {
    SettingsMenuView(isPresented: .constant(true), onLogout: {})
}
