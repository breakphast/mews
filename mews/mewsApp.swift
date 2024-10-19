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
            .environment(ControlsService(playerViewModel, recSongs: songModelManager.unusedRecSongs))
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
        await libraryService.getSavedLibraryArtists()
        try await libraryService.fetchLibraryPlaylists()
        if songModelManager.savedSongs.isEmpty || songModelManager.unusedRecSongs.count <= 10 {
            if let recommendations = await libraryService.getHeavyRotation() {
                var librarySongs = [Song]()
                // find library rotation songs in catalog and return
                for recommendation in recommendations {
                    if let catalogSong = await spotifyService.fetchCatalogSong(title: recommendation.name, artist: recommendation.artistName) {
                        print("Found song in Apple Catalog: \(catalogSong.artistName) - \(catalogSong.title)")
                        if !songModelManager.savedLibrarySongs.contains(where: { $0.id == catalogSong.id.rawValue }) {
                            librarySongs.append(catalogSong)
                        }
                    }
                }
                // save library songs
                try await spotifyService.persistLibrarySongs(songs: librarySongs)
                try await songModelManager.fetchItems()
                
                // use catalog songs to get spotify recs and persist non catalog
                if let token = spotifyTokenManager.token,
                   let recommendedSongs = await spotifyService.getRecommendations(
                    using: songModelManager.savedLibrarySongs,
                    recSongs: songModelManager.savedRecSongs,
                    dislikedSongs: songModelManager.savedDeletedSongs?.map { $0.url } ?? [],
                    token: token
                   ) {
                    try await spotifyService.persistRecommendations(songs: recommendedSongs)
                    try await songModelManager.fetchItems()
                }
                
                if let song = songModelManager.unusedRecSongs.randomElement() {
                    let songURL = URL(string: song.previewURL)
                    if let songURL = songURL {
                        let playerItem = AVPlayerItem(url: songURL)
                        await playerViewModel.assignPlayerSong(item: playerItem, song: song)
                    }
                }
            }
        }
    }
}

func deleteUserDefaults(forKey key: String) {
    UserDefaults.standard.removeObject(forKey: key)
}
