//
//  SubscriptionService.swift
//  mews
//
//  Created by Desmond Fitch on 10/31/24.
//

import SwiftUI
import RevenueCat

@Observable
class SubscriptionService {
    var isSubscriptionActive = false
    var customerInfo: CustomerInfo?
    
    init() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "appl_kxoPLQHprumfZHmWyTkbDmVwoWd")
        
        Purchases.shared.getCustomerInfo { (customerInfo, error) in
            self.customerInfo = customerInfo
            if customerInfo?.entitlements.all["proMonthly"]?.isActive == true {
                self.isSubscriptionActive = true
                print("Subscription is active")
            }
        }
    }
}
