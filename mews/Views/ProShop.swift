//
//  ProShop.swift
//  mews
//
//  Created by Desmond Fitch on 10/22/24.
//

import SwiftUI
import StoreKit

struct ProShop: View {
    var body: some View {
        SubscriptionStoreView(groupID: "090876BB") {
            VStack {
                ZStack {
                    Color.appleMusic.opacity(0.8).ignoresSafeArea()
                    Text("PRO")
                        .fontWeight(.black)
                        .font(.system(size: 88))
                        .foregroundStyle(.white)
                        .kerning(2)
                }
                .frame(height: 200)
                Spacer()
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
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
        }
        .subscriptionStorePickerItemBackground(.ultraThinMaterial)
        .subscriptionStoreButtonLabel(.action)
        .storeButton(.visible, for: .policies)
        .tint(.appleMusic.opacity(0.8))
    }
    
    let features: [(title: String, description: String)] = [
        (title: "Full DiscoMuse Experience", description: "Gain access to all premium features"),
        (title: "Unlimited Song Browsing", description: "Like or dislike as many songs as you want"),
        (title: "Custom Actions", description: "Add liked songs directly to specific playlists"),
        (title: "Customized Recommendations", description: "Filter your music discovery by genre or artist")
    ]
    
    let featureSymbols = ["lock.open", "infinity", "plus.square.on.square", "music.note.list"]
}

#Preview {
    ProShop()
}
