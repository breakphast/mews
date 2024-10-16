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
    @Environment(SpotifyService.self) var spotifyService
    @Environment(SpotifyTokenManager.self) var spotifyTokenManager
    @Environment(\.modelContext) var modelContext
    @Query var songModels: [SongModel]
    @Environment(ControlsService.self) var mediaControls
    @Environment(\.colorScheme) var colorScheme
    @State private var haptic = false
    
    private var isPlaying: Bool {
        return playerViewModel.isAvPlaying
    }
    
    private var avSong: SongModel? {
        return playerViewModel.currentSong
    }
    
    private var unusedRecSongs: [SongModel] {
        songModelManager.unusedRecSongs
    }
    
    var body: some View {
        if albumImage != nil && avSong != nil {
            VStack(spacing: 24) {
                navBar
                Spacer()
                SongView()
                Spacer()
                if playerViewModel.initalLoad {
                    buttons
                }
            }
            .padding()
            .background(Color.oreo.ignoresSafeArea())
            .onChange(of: unusedRecSongs.count) { _, newCount in
                lowRecsTrigger(count: newCount)
            }
        } else {
            ZStack {
                ProgressView()
                    .tint(.appleMusic)
                    .bold()
            }
            .onChange(of: unusedRecSongs.count) { oldCount, _ in
                assignNewSong(count: oldCount)
            }
        }
    }
    
    private func assignNewSong(count: Int) {
        guard !playerViewModel.initalLoad else { return }
        
        withAnimation {
            playerViewModel.image = nil
        }
        if let song = unusedRecSongs.randomElement(),
           let url = URL(string: song.previewURL) {
            Task {
                let playerItem = AVPlayerItem(url: url)
                if albumImage == nil {
                    await playerViewModel.assignCurrentSong(item: playerItem, song: song)
                }
            }
        }
    }
    
    // MARK: - Functions
    
    private func lowRecsTrigger(count: Int) {
        guard let token = spotifyTokenManager.token else { return }
        if count < 10 {
            Task {
                await
                spotifyService.lowRecsTrigger(
                    songs: songModelManager.savedLibrarySongs,
                    recSongs: songModelManager.savedRecSongs,
                    token: token)
                
                try await songModelManager.fetchItems()
            }
        }
    }
    
    private var navBar: some View {
        HStack {
            Image(systemName: "line.3.horizontal.circle")
            Spacer()
            Text("Mews")
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
        }
        .font(.title.bold())
        .fontDesign(.rounded)
    }
    
    // MARK: - View Properties
        
    var albumImage: UIImage? {
        return playerViewModel.image
    }
    private var buttons: some View {
        HStack {
            button(liked: false, icon: "xmark", color: .gray, textColor: .white)
            Spacer()
            button(icon: "wand.and.stars", color: .white, textColor: .appleMusic)
                .offset(y: -16)
            Spacer()
            button(liked: true, icon: "heart.fill", color: .appleMusic, textColor: .white)
        }
        .bold()
        .padding()
    }
    
    private func button(liked: Bool? = nil, icon: String, color: Color, textColor: Color) -> some View {
        Button {
            haptic.toggle()
            if let liked {
                Task {
                    try await playerViewModel.swipeAction(liked: liked, unusedRecSongs: unusedRecSongs)
                    if !liked {
                        if let avSong {
                            songModelManager.saveDislikedSong(title: avSong.title, url: avSong.catalogURL)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(textColor)
                .padding()
                .background {
                    Circle()
                        .fill(color.opacity(0.8))
                        .frame(width: 88, height: 88)
                        .overlay {
                            Circle()
                                .stroke(color.opacity(0.8), lineWidth: 2)
                                .frame(width: 88, height: 88)
                        }
                        .shadow(color: .snow.opacity(colorScheme == .light ? 0.3 : 0.05), radius: 6, x: 2, y: 4)
                }
        }
        .sensoryFeedback((liked ?? true) ? .impact(weight: .heavy) : .impact(weight: .light), trigger: haptic)
    }
}

#Preview {
    PlayerView()
}
