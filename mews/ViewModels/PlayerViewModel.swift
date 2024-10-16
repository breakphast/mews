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
import MediaPlayer

@MainActor
@Observable
final class PlayerViewModel {
    let avPlayer = AVPlayer()
    var isAvPlaying = false
    var currentSong: SongModel?
    var image: UIImage?
    var swipeDirection: Edge = .leading
    var initalLoad = false
    
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
    func assignCurrentSong(item: AVPlayerItem, song: SongModel) async {
        if let url = URL(string: song.artwork) {
            let artwork = await LibraryService().fetchArtwork(from: url)
            avPlayer.replaceCurrentItem(with: item)
            image = nil
            image = artwork
            currentSong = song
            play()
        }
    }
    
    @MainActor
    func swipeAction(liked: Bool, unusedRecSongs: [SongModel]) async throws {
        swipeDirection = liked ? .trailing : .leading
        guard let currentSong else { return }
        currentSong.liked = liked
        var songs = unusedRecSongs
        if !liked {
            try await SongModelManager().deleteSongModel(songModel: currentSong)
            print("Deleted \(currentSong.title) from context")
            songs.remove(at: songs.firstIndex(of: currentSong)!)
        }
        
        if let recSong = songs.randomElement() {
            let songURL = URL(string: recSong.previewURL)
            if let songURL = songURL {
                let playerItem = AVPlayerItem(url: songURL)
                await assignCurrentSong(item: playerItem, song: recSong)
            }
        }
        
        if liked, let song = await SpotifyService().fetchCatalogSong(title: currentSong.title, artist: currentSong.artist, url: currentSong.catalogURL) {
            try await MusicLibrary.shared.add(song)
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
