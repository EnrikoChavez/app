//
//  SubscriptionManager.swift
//  ai_anti_doomscroll
//

import Foundation
import StoreKit
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var isPremium = false
    @Published var isLoading = false
    @Published var currentSubscription: Product?
    
    private var updateListenerTask: Task<Void, Error>?
    
    // ==========================================
    // 📝 SETUP INSTRUCTIONS:
    // ==========================================
    // 1. Go to App Store Connect and create your subscriptions
    // 2. Option A: Use Subscription Group ID (recommended)
    //    - Set subscriptionGroupID to your group ID (e.g., "21482459")
    //    - Leave productIDs as fallback
    // 3. Option B: Use specific Product IDs
    //    - Set subscriptionGroupID = "YOUR_GROUP_ID" (keep placeholder)
    //    - Update productIDs with your actual IDs from App Store Connect
    // 4. For testing: Create a StoreKit Configuration File in Xcode
    //    - File > New > File > StoreKit Configuration File
    //    - Add your products there
    //    - Scheme > Run > Options > StoreKit Configuration = your file
    // ==========================================
    
    let subscriptionGroupID = "20864321" // Replace with your Subscription Group ID from App Store Connect
    let productIDs = [
        "ai_anti_doomscroll.basic"
    ]
    
    init() {
        // Skip StoreKit initialization in previews to avoid crashes
        // Previews don't have access to StoreKit configuration
        #if DEBUG
        // Check multiple ways to detect preview environment
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" ||
                       ProcessInfo.processInfo.environment["__XCODE_BUILT_PRODUCTS_DIR__"] != nil
        if isPreview {
            // In preview mode, don't start async tasks
            return
        }
        #endif
        
        // Start listening for transaction updates (with error handling)
        updateListenerTask = listenForTransactions()
        
        // Check current subscription status (with error handling)
        Task { @MainActor in
            do {
                await checkSubscriptionStatus()
            } catch {
                // Silently fail in previews or if StoreKit isn't available
                print("⚠️ Subscription status check failed (this is normal in previews): \(error.localizedDescription)")
            }
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func checkSubscriptionStatus() async {
        isLoading = true
        defer { isLoading = false }
        
        // Check if user has an active subscription
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                // Look up the product using the transaction's productID
                let products = try await Product.products(for: [transaction.productID])
                if let product = products.first {
                    currentSubscription = product
                    isPremium = true
                    print("✅ Active subscription: \(product.displayName)")
                    return
                }
            } catch {
                print("❌ Transaction verification failed: \(error)")
            }
        }
        
        // No active subscription found
        isPremium = false
        currentSubscription = nil
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            do {
                for await result in Transaction.updates {
                    do {
                        let transaction = try self.checkVerified(result)
                        await self.updateSubscriptionStatus(transaction)
                        await transaction.finish()
                    } catch {
                        print("❌ Transaction update failed: \(error)")
                    }
                }
            } catch {
                // Silently handle if Transaction.updates fails (e.g., in previews)
                print("⚠️ Transaction listener failed (this is normal in previews): \(error.localizedDescription)")
            }
        }
    }
    
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func updateSubscriptionStatus(_ transaction: Transaction) async {
        // Look up the product using the transaction's productID
        do {
            let products = try await Product.products(for: [transaction.productID])
            if let product = products.first {
                currentSubscription = product
                isPremium = true
                print("✅ Subscription activated: \(product.displayName)")
            }
        } catch {
            print("❌ Failed to look up product: \(error)")
        }
    }
    
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        try? await AppStore.sync()
        await checkSubscriptionStatus()
    }
}

enum StoreError: Error {
    case failedVerification
}
