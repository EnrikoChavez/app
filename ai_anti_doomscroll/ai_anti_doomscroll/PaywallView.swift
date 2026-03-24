//
//  PaywallView.swift
//  ai_anti_doomscroll
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var subscriptionManager: SubscriptionManager
    var onSkip: (() -> Void)? = nil
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showTerms = false
    @State private var showPrivacy = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                    .onAppear { Analytics.paywallShown() }
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Unlock Anti Doomscrolling")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        
                        Text("Get AI Chat based focus sessions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                    
                    // Subscription Store View
                    // Use product IDs if group ID is not set, otherwise use group ID
                    if subscriptionManager.subscriptionGroupID != "YOUR_GROUP_ID" {
                        SubscriptionStoreView(groupID: subscriptionManager.subscriptionGroupID)
                            .subscriptionStoreControlStyle(.prominentPicker)
                            .subscriptionStoreButtonLabel(.multiline)
                            .storeButton(.visible, for: .restorePurchases)
                        .storeButton(.hidden, for: .cancellation)
                            .onInAppPurchaseCompletion { product, result in
                                handlePurchaseResult(product: product, result: result)
                            }
                    } else {
                        SubscriptionStoreView(productIDs: subscriptionManager.productIDs)
                            .subscriptionStoreControlStyle(.prominentPicker)
                            .subscriptionStoreButtonLabel(.multiline)
                            .storeButton(.visible, for: .restorePurchases)
                            .storeButton(.hidden, for: .cancellation)
                            .onInAppPurchaseCompletion { product, result in
                                handlePurchaseResult(product: product, result: result)
                            }
                    }
                    // Required by App Store: links to Privacy Policy and Terms of Use
                HStack(spacing: 24) {
                    Link("Privacy Policy", destination: URL(string: "https://www.notion.so/AI-Anti-Doomscroll-Privacy-Policy-325a5fecb17980f4ba34dd163b656826")!)
                    Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }
                .foregroundColor(.secondary)
                .font(.footnote)
                }
    
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onSkip {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: onSkip) {
                            Image(systemName: "xmark")
                                .font(.body)
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                }
            }
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func handlePurchaseResult(product: Product, result: Result<Product.PurchaseResult, Error>) {
        switch result {
        case .success(let purchaseResult):
            switch purchaseResult {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    Task {
                        await subscriptionManager.checkSubscriptionStatus()
                        if subscriptionManager.isPremium {
                            dismiss()
                        }
                    }
                    Task {
                        await transaction.finish()
                    }
                case .unverified(_, let error):
                    errorMessage = "Purchase could not be verified: \(error.localizedDescription)"
                    showError = true
                }
            case .userCancelled:
                // User cancelled - no error needed
                break
            case .pending:
                errorMessage = "Purchase is pending approval"
                showError = true
            @unknown default:
                errorMessage = "Unknown purchase result"
                showError = true
            }
        case .failure(let error):
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            showError = true
        }
    }
}

// Note: Preview disabled due to StoreKit limitations in Xcode Previews
// SubscriptionStoreView requires StoreKit configuration that isn't available in previews
// To test the paywall, run the app on a simulator or device
/*
#Preview {
    PaywallView(subscriptionManager: SubscriptionManager())
}
*/
