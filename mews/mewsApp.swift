//
//  mewsApp.swift
//  mews
//
//  Created by Desmond Fitch on 10/4/24.
//

import SwiftUI
import SwiftData
import MusicKit

@main
struct mewsApp: App {
    @State private var authService = AuthService()
    @State private var libraryService = LibraryService()
    @State private var spotifyService = SpotifyService()
    @State private var playerViewModel = PlayerViewModel()
    
    var body: some Scene {
        WindowGroup {
            Group {
                PlayerView()
            }
            .environment(authService)
            .environment(libraryService)
            .environment(spotifyService)
            .environment(playerViewModel)
            .task {
                Task {
                    try await authorizeAndFetch()
                }
            }
        }
    }
    
    private func authorizeAndFetch() async throws {
        guard authService.status == .authorized else {
            try? await authService.authorizeAction()
                return
        }
        await spotifyService.getAccessToken()
        do {
            if libraryService.songs.isEmpty {
                try await libraryService.fetchSongs()
                if let randomLibrarySong = libraryService.songs.randomElement() {
                    spotifyService.artist = randomLibrarySong.artistName
                    spotifyService.title = randomLibrarySong.title
                    
                    await spotifyService.fetchTrackID()
                    await spotifyService.fetchArtistID()
                    await spotifyService.fetchRecommendations()
                    
                    if let recommendations = spotifyService.recommendedSongs, !recommendations.isEmpty, let song = recommendations.first {
                        playerViewModel.player.queue = ApplicationMusicPlayer.Queue(for: recommendations, startingAt: song)
                        do {
                            try await playerViewModel.player.prepareToPlay()
                        }
                    }
                }
            }
        } catch {
            print("Failed to fetch songs from library")
        }
    }
}
