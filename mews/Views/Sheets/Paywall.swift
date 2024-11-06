//
//  ProShop.swift
//  mews
//
//  Created by Desmond Fitch on 10/22/24.
//

import SwiftUI
import StoreKit
import RevenueCat

struct Paywall: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @Environment(\.colorScheme) var colorScheme
    @Environment(CustomFilterService.self) var customFilterService
    @Environment(PlayerViewModel.self) var playerViewModel
    @Environment(SubscriptionService.self) var subscriptionService
    @State private var product: StoreProduct?
    @State private var currentOffering: Offering?
    
    private var package: Package? {
        currentOffering?.availablePackages.first
    }
    private var customerInfo: CustomerInfo? {
        subscriptionService.customerInfo
    }
    private var isSubscribed: Bool {
        subscriptionService.isSubscriptionActive
    }
    
    var body: some View {
        VStack {
            header
            .frame(height: 200)
            .background(Color.appleMusic.opacity(0.9).gradient)
            .padding(.bottom, 32)
            VStack {
                if Helpers.idiom == .pad {
                    Spacer()
                }
                featuresElement
                    .padding(.horizontal)
                Spacer()
                VStack(spacing: 16) {
                    termsButton
                    buyButton
                    restoreButton
                }
                .padding(.bottom)
            }
            .padding(.horizontal)
            Spacer()
        }
        .background {
            Color.oreo.ignoresSafeArea()
        }
        .onAppear {
            Purchases.shared.getOfferings { offerings, error in
                if let offer = offerings?.current, error == nil {
                    currentOffering = offer
                }
            }
        }
    }
    
    private var header: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .bold()
                    .padding()
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                    }
            }
            .tint(.snow)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing)
            Text("PRO")
                .fontWeight(.black)
                .font(.system(size: 88))
                .foregroundStyle(.white)
                .kerning(2)
        }
    }
    private var featuresElement: some View {
        VStack(spacing: 32) {
            Text("Try DiscoMuse Pro for free")
                .font(.title2.bold())
                .foregroundStyle(.snow)
            VStack(alignment: .leading, spacing: 24) {
                ForEach(0..<features.count, id: \.self) { i in
                    HStack(spacing: 8) {
                        Image(systemName: featureSymbols[i])
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                            .background(.appleMusic.opacity(0.8), in: .rect(cornerRadius: 16))
                            .foregroundStyle(.white)
                        VStack(alignment: .leading) {
                            Text(features[i].title)
                                .bold()
                                .foregroundStyle(.snow)
                            Text(features[i].description)
                                .foregroundStyle(.snow.opacity(0.9))
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
    private var buyButton: some View {
        ZStack {
            if let package {
                Button {
                    Purchases.shared.purchase(package: package) { (transaction, customerInfo, error, userCancelled) in
                        if customerInfo?.entitlements.all["proMonthly"]?.isActive == true {
                            assignProFeatures()
                        }
                        
                    }
                } label: {
                    VStack(spacing: 2) {
                        if !subscriptionService.isSubscriptionActive {
                            if let customerInfo, customerInfo.activeSubscriptions.isEmpty {
                                Text("Try it free")
                                Text("3 days free, then $2.99/month")
                                    .font(.caption)
                            } else {
                                Text("Subscribe")
                                Text("Plan auto-renews for $2.99/month until canceled.")
                                    .font(.caption)
                            }
                        } else {
                            Text("Subscribed")
                        }
                    }
                }
                .bold()
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .foregroundStyle(.white.opacity(isSubscribed ? 0.5 : 1))
                .frame(maxWidth: .infinity)
                .frame(height: isSubscribed ? 44 : nil)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSubscribed ? .appleMusic.opacity(0.4) : .appleMusic.opacity(0.8))
                }
                .disabled(isSubscribed)
            }
        }
    }
    private var restoreButton: some View {
        Button {
            Purchases.shared.restorePurchases { (customerInfo, error) in
                subscriptionService.isSubscriptionActive = customerInfo?.entitlements.all["proMonthly"]?.isActive == true
            }
        } label: {
            Text("Restore Subscription")
                .font(.headline)
                .foregroundStyle(.appleMusic.opacity(0.9))
        }
    }
    
    private var termsButton: some View {
        HStack(spacing: 0) {
            Button(action: {
                openURL(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }) {
                Text("Terms of Service")
                    .foregroundStyle(.appleMusic.opacity(0.8))
            }
            .tint(.snow)
            
            Text(" and ")
            
            Button(action: {
                openURL(URL(string: "https://github.com/breakphast/DiscoMuse/blob/main/PrivacyPolicy.md")!)
            }) {
                Text("Privacy Policy")
                    .foregroundStyle(.appleMusic.opacity(0.8))
            }
            .tint(.snow)
        }
        .font(.caption)
    }
    
    let features: [(title: String, description: String)] = [
        (title: "Full DiscoMuse Experience", description: "Gain access to all premium features"),
        (title: "Unlimited Song Browsing", description: "Like or dislike as many songs as you want"),
        (title: "Custom Actions", description: "Add liked songs directly to specific playlists"),
        (title: "Customized Recommendations", description: "Filter your music discovery by genre or artist")
    ]
    
    let featureSymbols = ["lock.open", "infinity", "plus.square.on.square", "music.note.list"]
    
    private func assignProFeatures() {
        Task {
            subscriptionService.isSubscriptionActive = true
            playerViewModel.showLimitToast = false
            Helpers.deleteFromUserDefaults(forKey: "limitedSongID")
            let customFilterModel = CustomFilterModel()
            try await customFilterService.persistCustomFilter(customFilterModel)
            try await customFilterService.fetchCustomFilter()
            dismiss()
            playerViewModel.triggerFilters()
            playerViewModel.songsBrowsed = 0
        }
    }
}

#Preview {
    Paywall()
        .environment(PlayerViewModel())
        .environment(CustomFilterService(songModelManager: SongModelManager(), spotifyTokenManager: SpotifyTokenManager()))
        .environment(SubscriptionService())
}
