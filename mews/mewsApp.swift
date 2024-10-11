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
    @State private var spotifyTokenManager = SpotifyTokenManager()
    
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
            .environment(spotifyTokenManager)
            .task {
                Task {
                    try await authorizeAndFetch()
                }
            }
        }
        .modelContainer(for: [SongModel.self])
    }
    
    private func authorizeAndFetch() async throws {
        if authService.status != .authorized {
            await authService.authorizeAction()
        }
        
        do {
            if songModelManager.savedSongs.isEmpty || songModelManager.savedLibrarySongs.count <= 10 {
                if let catalogSongs = try await libraryService.fetchSongs() {
                    try await spotifyService.persistSongModels(songs: Array(catalogSongs), isCatalog: true)
                    try await songModelManager.fetchItems()
                }
            }
            
            songModelManager.accessToken = spotifyTokenManager.token
            
            if let song = songModelManager.unusedRecSongs.randomElement() {
                let songURL = URL(string: song.previewURL)
                if let songURL = songURL {
                    let playerItem = AVPlayerItem(url: songURL)
                    await playerViewModel.assignCurrentSong(item: playerItem, song: song)
                }
            }
            
            if let token = spotifyTokenManager.token, songModelManager.unusedRecSongs.count <= 10,
               let recommendedSongs = await spotifyService.getRecommendations(using: songModelManager.unusedLibrarySongs, recSongs: songModelManager.savedRecSongs, token: token) {
                try await spotifyService.persistSongModels(songs: recommendedSongs, isCatalog: false)
                try await songModelManager.fetchItems()
            }
        } catch {
            print("Failed to fetch songs from library")
        }
    }
}

func deleteUserDefaults(forKey key: String) {
    UserDefaults.standard.removeObject(forKey: key)
}
