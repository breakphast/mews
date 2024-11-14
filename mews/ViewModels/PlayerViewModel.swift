//
//  PlayerViewModel.swift
//  mews
//
//  Created by Desmond Fitch on 10/7/24.
//

import SwiftUI
import MusicKit
import Observation
import AVFoundation
import SwiftData

@MainActor
@Observable
final class PlayerViewModel {
    let avPlayer = AVPlayer()
    var isAvPlaying = false
    var currentSong: SongModel?
    var image: UIImage?
    var swipeDirection: Edge = .leading
    var switchingSongs = false
    var initialLoad = false
    var showFilters = false
    var showSettings = false
    var showPaywall = false
    var showAddedToast = false
    var showLimitToast = false
    var scale: CGFloat = 50
    var opacity: Double = 1
    var progress: Double = 0
    var progressMessage = "Scanning your library..."
    
    let height = UIScreen.main.bounds.height * (Helpers.idiom == .pad ? 0.06 : 0.1)
    var selectedSeed: String?
    var buttonDisabled = false
    var appleUserID: String?
    var songsBrowsed = 0
    var browseLimitReached: Bool {
        songsBrowsed >= Helpers.songLimit
    }
    var limitedSongID: String?
    var showSpotlight = true
    var currentSpot: Int = 0
    
    init() {
        loadInitialLoad()
        configureAudioSession()
        avPlayer.actionAtItemEnd = .none
        if let limitSongID: String = Helpers.getFromUserDefaults(forKey: "limitedSongID") {
            self.limitedSongID  = limitSongID
        }
        if let _: String = Helpers.getFromUserDefaults(forKey: "firstTime") {
            self.showSpotlight = false
        }
        
        // Set up loop
        if avPlayer.actionAtItemEnd == .none {
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.avPlayer.seek(to: .zero)
                self?.avPlayer.play()
            }
        }
    }
    
    @MainActor
    func assignPlayerSong(song: SongModel) async {
        let songURL = URL(string: song.previewURL)
        if let songURL = songURL {
            let playerItem = AVPlayerItem(url: songURL)
            if let url = URL(string: song.artwork) {
                let artwork = await Helpers.fetchArtwork(from: url)
                withAnimation(.bouncy) {
                    avPlayer.replaceCurrentItem(with: playerItem)
                    image = artwork
                    currentSong = song
                    self.play()
                }
            }
        }
    }
    
    @MainActor
    func swipeAction(liked: Bool?, recSongs: [SongModel], playlist: Playlist? = nil, limit: Bool) async throws {
        guard !browseLimitReached else { return }
        
        guard let liked else {
            if let recSong = recSongs.randomElement() {
                guard let appleUserID else { return }
                
                if limit {
                    await APIService.updateSongsBrowsed(for: appleUserID)
                    songsBrowsed = await APIService.fetchSongsBrowsed(for: appleUserID) ?? 0
                }
                await assignPlayerSong(song: recSong)
            }
            return
        }
        
        swipeDirection = .leading
        guard let currentSong else { return }
        var songs = recSongs
        if let index = songs.firstIndex(where: { $0.id == currentSong.id }) {
            songs.remove(at: index)
        }
        
        if let recSong = songs.randomElement() {
            guard let appleUserID else { return }
            
            await assignPlayerSong(song: recSong)
            
            if limit {
                await APIService.updateSongsBrowsed(for: appleUserID)
                songsBrowsed = await APIService.fetchSongsBrowsed(for: appleUserID) ?? 0
            }
        }
        
        if liked, let song = await LibraryService.fetchCatalogSong(song: currentSong) {
            if let playlist {
                await LibraryService.addSongToPlaylist(song: song, playlist: playlist)
            } else {
                await LibraryService.addSongToLibrary(song: song)
            }
        }
        
        return
    }
    
    func authorizeAndFetch(libraryService: LibraryService, spotifyService: SpotifyService) async throws {
        let songModelManager = libraryService.songModelManager
        
        var fetchSuccess = false
        var attempts = 0
        let maxAttempts = 5  // Set an appropriate retry limit
        
        while !fetchSuccess && attempts < maxAttempts {
            attempts += 1
            print("Attempt \(attempts) to fetch songs...")

            // Initial fetch of items
            try await songModelManager.fetchItems()
            
            // Check if items already exist
            if songModelManager.savedSongs.isEmpty || songModelManager.recSongs.count <= 10 {
                withAnimation(.easeInOut) {
                    progressMessage = "Fetching library songs..."
                    progress = 0.2
                }
                try await fetchAndPersistLibrarySongs(libraryService: libraryService)
                
                withAnimation(.easeInOut) {
                    progressMessage = "Getting recommendations..."
                    progress = 0.5
                }
                try await fetchAndPersistSpotifySongs(spotifyService: spotifyService, libraryService: libraryService)

                // Re-fetch items after attempting to persist songs
                try await songModelManager.fetchItems()
            }
            
            // Check if recSongs has been populated to proceed
            if !songModelManager.recSongs.isEmpty {
                fetchSuccess = true
                withAnimation(.easeInOut) {
                    progressMessage = "Wrapping up..."
                    progress = 0.8
                }
                
                if let song = (limitedSongID != nil
                               ? songModelManager.recSongs.first { $0.id == limitedSongID }
                               : songModelManager.recSongs.randomElement()) {
                    withAnimation(.easeInOut) {
                        progressMessage = "Loading complete!"
                        progress = 1
                    }
                    await assignPlayerSong(song: song)
                    saveInitialLoad()
                    return
                }
            } else {
                // Optional message or delay for next attempt if desired
                progressMessage = "Retrying..."
                progress = 0
            }
        }
        
        if !fetchSuccess {
            // Final handling if unable to fetch after max attempts
            progressMessage = "Unable to fetch songs. Please retry."
            return
        }
    }
    private func fetchAndPersistLibrarySongs(libraryService: LibraryService) async throws {
        let songModelManager = libraryService.songModelManager

        var librarySongs = [Song]()
        if let userRecommendations = await LibraryService.getHeavyRotation() {
            withAnimation(.bouncy) { progress = 0.25 }
            for song in userRecommendations {
                if let catalogSong = await LibraryService.fetchCatalogSong(title: song.name, artist: song.artistName) {
                    if !songModelManager.savedLibrarySongs.contains(where: { $0.id == catalogSong.id.rawValue }) {
                        librarySongs.append(catalogSong)
                    }
                }
            }
        } else {
            if let song = await LibraryService.fetchCatalogSong(title: "Passionfruit", artist: "Drake") {
                librarySongs.append(song)
            }
        }
        // save library songs
        try await libraryService.persistLibrarySongs(songs: librarySongs)
        try await songModelManager.fetchItems()
    }
    
    private func fetchAndPersistSpotifySongs(spotifyService: SpotifyService, libraryService: LibraryService) async throws {
        let songModelManager = libraryService.songModelManager
        
        if let recommendedSongs = await spotifyService.getRecommendations(
            using: songModelManager.savedLibrarySongs,
            recSongs: songModelManager.recSongs,
            deletedSongs: songModelManager.savedDeletedSongs?.map { $0.url } ?? []
        ) {
            try await spotifyService.persistRecommendations(songs: recommendedSongs)
            try await songModelManager.fetchItems()
        }
    }
    
    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }
    
    func saveInitialLoad() {
        UserDefaults.standard.set(true, forKey: "initialLoad")
        loadInitialLoad()
    }
    
    func loadInitialLoad() {
        if UserDefaults.standard.bool(forKey: "initialLoad") {
            initialLoad = true
        }
    }
}
