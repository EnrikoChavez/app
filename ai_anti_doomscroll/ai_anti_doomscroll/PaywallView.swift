//
//  PaywallView.swift
//  ai_anti_doomscroll
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var subscriptionManager: SubscriptionManager
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Unlock Premium")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        
                        Text("Get unlimited AI coaching sessions and advanced features")
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
                            .storeButton(.visible, for: .restorePurchases, .policies)
                            .onInAppPurchaseCompletion { product, result in
                                handlePurchaseResult(product: product, result: result)
                            }
                    } else {
                        SubscriptionStoreView(productIDs: subscriptionManager.productIDs)
                            .subscriptionStoreControlStyle(.prominentPicker)
                            .subscriptionStoreButtonLabel(.multiline)
                            .storeButton(.visible, for: .restorePurchases, .policies)
                            .onInAppPurchaseCompletion { product, result in
                                handlePurchaseResult(product: product, result: result)
                            }
                    }
                    
                    // Close button
                    Button(action: { dismiss() }) {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
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
