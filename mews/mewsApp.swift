//
//  mewsApp.swift
//  mews
//
//  Created by Desmond Fitch on 10/4/24.
//

import SwiftUI
import SwiftData
import MusicKit
import AVFoundation

@main
struct mewsApp: App {
    @State private var authService = AuthService()
    @State private var playerViewModel = PlayerViewModel()
    @State private var spotifyTokenManager = SpotifyTokenManager()
    @State private var songModelManager = SongModelManager()
    @State private var subscriptionService = SubscriptionService()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authService.appleUserID == nil {
                    SignInView()
                } else {
                    PlayerView(playerViewModel: playerViewModel)
                }
            }
            .environment(authService)
            .environment(playerViewModel)
            .environment(spotifyTokenManager)
            .environment(LibraryService(songModelManager: songModelManager))
            .environment(SpotifyService(tokenManager: spotifyTokenManager))
            .environment(CustomFilterService(songModelManager: songModelManager, spotifyTokenManager: spotifyTokenManager))
            .environment(subscriptionService)
        }
        .modelContainer(for: [SongModel.self, CustomFilterModel.self])
    }
}

func deleteUserDefaults(forKey key: String) {
    UserDefaults.standard.removeObject(forKey: key)
}
