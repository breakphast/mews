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
    
    func assignCurrentSong(item: AVPlayerItem, song: SongModel) async {
        avPlayer.replaceCurrentItem(with: item)
        currentSong = song
        if let url = URL(string: song.artwork) {
            image = await fetchArtwork(from: url)
        }
    }
    
    func swipeAction(liked: Bool, songs: [SongModel]) throws {
        let context = ModelContext(try ModelContainer(for: SongModel.self))
        
        Task {
            if let currentSong {
                currentSong.liked = liked
                do {
                    try context.save()
                }
            }
            
            if let recSong = songs.randomElement() {
                let songURL = URL(string: recSong.previewURL)
                if let songURL = songURL {
                    let playerItem = AVPlayerItem(url: songURL)
                    await assignCurrentSong(item: playerItem, song: recSong)
                    play()
                }
            }
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
    
    func fetchArtwork(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("Failed to load artwork: \(error.localizedDescription)")
            return nil
        }
    }
}
