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
    
    @Environment(\.modelContext) var modelContext
    @Query var songModels: [SongModel]
    
    var body: some Scene {
        WindowGroup {
            Group {
                PlayerView(playerViewModel: playerViewModel)
            }
            .environment(authService)
            .environment(playerViewModel)
            .environment(spotifyTokenManager)
            .environment(LibraryService(songModelManager: songModelManager))
            .environment(SpotifyService(tokenManager: spotifyTokenManager))
//            .environment(ControlsService(playerViewModel, recSongs: []))
        }
        .modelContainer(for: [SongModel.self])
    }
}

func deleteUserDefaults(forKey key: String) {
    UserDefaults.standard.removeObject(forKey: key)
}
