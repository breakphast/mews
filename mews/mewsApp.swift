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
    @State private var libraryService = LibraryService()
    @State private var spotifyService = SpotifyService()
    @State private var playerViewModel = PlayerViewModel()
    @State private var songModelManager = SongModelManager()
    @State private var accessTokenManager = AccessTokenManager()
    
    @Environment(\.modelContext) var modelContext
    @Query var songModels: [SongModel]
    
    var unusedRecSongs: [SongModel] {
        guard songModelManager.savedLibrarySongs.count > 0 else {
            return []
        }
        return Array(songModelManager.unusedLibrarySongs.prefix(1))
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                PlayerView()
            }
            .environment(authService)
            .environment(libraryService)
            .environment(spotifyService)
            .environment(playerViewModel)
            .environment(songModelManager)
            .environment(accessTokenManager)
            .task {
                Task {
                    try await authorizeAndFetch()
                }
            }
        }
        .modelContainer(for: [SongModel.self])
    }
    
    private func authorizeAndFetch() async throws {
        guard authService.status == .authorized else {
            try? await authService.authorizeAction()
            return
        }
        
        do {
            if songModelManager.savedSongs.isEmpty {
                try await libraryService.fetchSongs()
            }
            
            await accessTokenManager.getAccessToken()
            
            if let token = accessTokenManager.token,
               let recommendedSongs = await spotifyService.getRecommendations(using: songModelManager.unusedRecSongs, token: token) {
                try await libraryService.persistSongModels(songs: recommendedSongs, isCatalog: false)
            }
            
            if let song = songModelManager.savedSongs.randomElement() {
                let songURL = URL(string: song.previewURL)
                libraryService.avSongURL = songURL
                if let songURL = songURL {
                    let playerItem = AVPlayerItem(url: songURL)
                    playerViewModel.configureAudioSession()
                    await playerViewModel.assignCurrentSong(item: playerItem, song: song)
                }
            }
        } catch {
            print("Failed to fetch songs from library")
        }
    }
}
