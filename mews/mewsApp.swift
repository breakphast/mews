//
//  mewsApp.swift
//  mews
//
//  Created by Desmond Fitch on 10/4/24.
//

import SwiftUI

@main
struct mewsApp: App {
    @State private var authService = AuthService()
    @State private var libraryService = LibraryService()
    @State private var spotifyService = SpotifyService()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authService.status != .authorized {
                    Text("Unauthorized")
                } else {
                    ContentView()
                }
            }
            .task {
                Task {
                    try await authorizeAndFetch()
                }
            }
        }
        .environment(authService)
        .environment(libraryService)
        .environment(spotifyService)
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
                }
            }
        } catch {
            print("Failed to fetch songs from library")
        }
    }
}
