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
    
    let height = UIScreen.main.bounds.height * (Helpers.idiom == .pad ? 0.06 : 0.1)
    
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
    func assignPlayerSong(item: AVPlayerItem, song: SongModel) async {
        if let url = URL(string: song.artwork) {
            let artwork = await Helpers.fetchArtwork(from: url)
            withAnimation(.bouncy) {
                avPlayer.replaceCurrentItem(with: item)
                image = artwork
                currentSong = song
                play()
            }
        }
    }
    
    @MainActor
    func swipeAction(liked: Bool?, recSongs: [SongModel], playlist: Playlist? = nil) async throws {
        guard let liked else {
            if let recSong = recSongs.randomElement() {
                let songURL = URL(string: recSong.previewURL)
                if let songURL = songURL {
                    let playerItem = AVPlayerItem(url: songURL)
                    await assignPlayerSong(item: playerItem, song: recSong)
                }
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
            let songURL = URL(string: recSong.previewURL)
            if let songURL = songURL {
                let playerItem = AVPlayerItem(url: songURL)
                await assignPlayerSong(item: playerItem, song: recSong)
            }
        }
        
        if liked, let song = await LibraryService.fetchCatalogSong(song: currentSong), let playlist {
            await LibraryService.addSongsToPlaylist(songs: [song], playlist: playlist)
        }
        
        return
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
