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
    
    var haptic = false
    var showFilters = false
    var showSettings = false
    var scale: CGFloat = 50
    var opacity: Double = 1
    var progress: Double = 0
    var progressMessage = "Scanning your library..."
    
    let height = UIScreen.main.bounds.height * (Helpers.idiom == .pad ? 0.06 : 0.1)
    var selectedSeed: String?
    
    init() {
        configureAudioSession()
        avPlayer.actionAtItemEnd = .none
        
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
                    play()
                }
            }
        }
    }
    
    @MainActor
    func swipeAction(liked: Bool?, recSongs: [SongModel], playlist: Playlist? = nil) async throws {
        guard let liked else {
            if let recSong = recSongs.randomElement() {
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
            await assignPlayerSong(song: recSong)
        }
        
        if liked, let song = await LibraryService.fetchCatalogSong(song: currentSong), let playlist {
            await LibraryService.addSongsToPlaylist(songs: [song], playlist: playlist)
        }
        
        return
    }
    
    func authorizeAndFetch(libraryService: LibraryService, spotifyService: SpotifyService) async throws {
        let songModelManager = libraryService.songModelManager

        try await songModelManager.fetchItems()
        if songModelManager.savedSongs.isEmpty || libraryService.songModelManager.recSongs.count <= 10 {
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
            
            withAnimation(.easeInOut) {
                progressMessage = "Wrapping up..."
                progress = 0.8
            }
            print(libraryService.songModelManager.recSongs.count)
            if let song = libraryService.songModelManager.recSongs.randomElement() {
                withAnimation(.easeInOut) {
                    progressMessage = "Loading complete!"
                    progress = 1
                }
                await assignPlayerSong(song: song)
                libraryService.saveInitialLoad()
            }
        } else {
            if let song = libraryService.songModelManager.recSongs.randomElement() {
                await assignPlayerSong(song: song)
            }
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
            if let song = await LibraryService.fetchCatalogSong(title: "", artist: "kanye west") {
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
    
    func play() {
        avPlayer.play()
        isAvPlaying = true
    }
    
    func pauseAvPlayer() {
        avPlayer.pause()
        isAvPlaying = false
    }
    
    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }
}
