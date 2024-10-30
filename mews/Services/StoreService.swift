//
//  StoreService.swift
//  mews
//
//  Created by Desmond Fitch on 10/24/24.
//

import SwiftUI
import StoreKit

@Observable
class StoreService {
    var subscriptionState: Product.SubscriptionInfo.RenewalState?
    var currentSubscription: Product?
    var status: Product.SubscriptionInfo.Status?
    
    init() {
        Task { await checkSubscriptionStatus() }
    }
    
    private func checkSubscriptionStatus() async {
        do {
            let products = try await Product.products(for: [StoreContents.productIdentifier])
            guard let subscriptionProduct = products.first else { return }
            let status = try await subscriptionProduct.subscription?.status.first
            
            if let state = status?.state {
                self.subscriptionState = state
            }
        } catch {
            print("Error fetching subscription status: \(error)")
        }
        print("Failed to fetch subscription status.")
        return
    }
    
    func isPurchased() async throws -> Bool {
        guard let result = await Transaction.latest(for: StoreContents.productIdentifier) else {
            return false
        }
        
        let transaction = try checkVerified(result)
        
        return transaction.revocationDate == nil && !transaction.isUpgraded
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}

struct StoreContents {
    static let productIdentifier = "com.discomuse.monthly"
}
