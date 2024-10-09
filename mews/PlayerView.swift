//
//  PlayerView.swift
//  mews
//
//  Created by Desmond Fitch on 10/7/24.
//

import SwiftUI
import MusicKit
import SwiftData
import AVFoundation

struct PlayerView: View {
    @Environment(PlayerViewModel.self) var playerViewModel
    @Environment(LibraryService.self) var libraryService
    @Environment(SongModelManager.self) var songModelManager
    @Environment(\.modelContext) var modelContext
    @ObservedObject private var playerState = ApplicationMusicPlayer.shared.state
    @Query var songModels: [SongModel]
    
    private var isPlaying: Bool {
        return playerViewModel.isAvPlaying
    }
    
    private var avSong: SongModel? {
        return playerViewModel.currentSong
    }
    
    private var avSongURL: URL? {
        return libraryService.avSongURL
    }

    var body: some View {
        if albumImage != nil {
            VStack(spacing: 16) {
                albumElement
                    .transition(.push(from: .trailing))
                Text("\(songModelManager.savedSongs.count)")
                VStack(alignment: .leading) {
                    Text(avSong?.title ?? "")
                    Text(avSong?.artist ?? "")
                }
                .font(.title3)
                .fontWeight(.semibold)
                
                Text("\(songModelManager.unusedRecSongs.count)")
                
                Button("Delete") {
                    Task {
                        do {
                            for model in songModels.prefix(upTo: songModels.count) {
                                modelContext.delete(model)
                            }
                            try modelContext.save()
                        }
                    }
                }
                Button("\(isPlaying ? "Pause" : "Play")\(isPlaying ? "⏸" : "▶")") {
                    Task {
                        isPlaying ? playerViewModel.pauseAvPlayer() : playerViewModel.play()
                    }
                }
                .font(.title.bold())
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .padding(.top)
                
                HStack {
                    Button("DISLIKE") {
                        withAnimation {
                            swipeAction(liked: false)
                        }
                    }
                    .font(.title.bold())
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    Button("LIKE") {
                        withAnimation {
                            swipeAction(liked: true)
                        }
                    }
                    .font(.title.bold())
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                }
            }
        } else {
            ZStack {
                Color.pink.opacity(0.7).ignoresSafeArea()
                ProgressView()
                    .tint(.yellow)
                    .bold()
            }
        }
    }
    
    private func swipeAction(liked: Bool) {
        Task {
            if let avSong {
                avSong.liked = liked
                do {
                    try? modelContext.save()
                }
            }
            
            if let recSong = songModelManager.unusedRecSongs.randomElement() {
                let songURL = URL(string: recSong.previewURL)
                libraryService.avSongURL = songURL
                if let songURL = songURL {
                    let playerItem = AVPlayerItem(url: songURL)
                    await playerViewModel.assignCurrentSong(item: playerItem, song: recSong)
                    playerViewModel.play()
                }
            }
        }
    }
    
    private func fetchArtwork(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("Failed to load artwork: \(error.localizedDescription)")
            return nil
        }
    }
    
    var albumImage: UIImage? {
        return playerViewModel.image
    }
    private var albumElement: some View {
        VStack(spacing: 40) {
            if let albumImage {
                Image(uiImage: albumImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width * 0.75)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(radius: 5)
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .frame(width: UIScreen.main.bounds.width * 0.75, height: 200)
                    .shadow(radius: 5)
            }
        }
    }
}

#Preview {
    PlayerView()
}
