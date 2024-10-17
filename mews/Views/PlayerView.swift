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
    @State private var showFilters = false
    let height = UIScreen.main.bounds.height * 0.1
    
    private var isPlaying: Bool {
        return playerViewModel.isAvPlaying
    }
    
    private var avSong: SongModel? {
        return playerViewModel.currentSong
    }
    
    private var unusedRecSongs: [SongModel] {
        songModelManager.unusedRecSongs
    }
    
    private var customFilter: CustomFilter? {
        songModelManager.customFilter
    }
    
    var customRecommendations: [SongModel]? {
        guard customFilter != nil else { return nil }
        
        return songModelManager.customFilterSongs.isEmpty ? nil : songModelManager.customFilterSongs
    }
    
    var filterButtonColors: [Color] {
        customFilter == nil ? [.appleMusic, .white] : [.appleMusic, .white]
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
                if !spotifyService.fetchingActive {
                    lowRecsTrigger(count: newCount)
                }
            }
            .onChange(of: songModelManager.customFilterSongs.count) { _, songCount in
                if let customFilter, !customFilter.fetchingActive {
                    Task {
                        await customFilter.lowCustomRecsTrigger(count: songCount)
                    }
                }
            }
            .fullScreenCover(isPresented: $showFilters) {
                CustomFilterView()
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
        if let song = (customRecommendations ?? unusedRecSongs).randomElement(),
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
                    dislikedSongs: songModelManager.savedDislikedSongs?.map { $0.url } ?? [],
                    token: token)
                
                try await songModelManager.fetchItems()
            }
        }
    }
    
    private var navBar: some View {
        HStack {
            Image(systemName: "slider.horizontal.2.square")
                .font(.largeTitle)
                .onTapGesture {
                    withAnimation(.bouncy) {
                        showFilters.toggle()
                    }
                }
            Spacer()
            Text("Mews")
                .font(.title)
            Spacer()
            Image(systemName: "person.circle")
                .font(.largeTitle)
        }
        .padding(.horizontal, 4)
        .bold()
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
            button(icon: "wand.and.stars", color: .white, textColor: .appleMusic, custom: true)
                .offset(y: -16)
            Spacer()
            button(liked: true, icon: "heart.fill", color: .appleMusic, textColor: .white)
        }
        .bold()
        .padding()
    }
    
    private func button(liked: Bool? = nil, icon: String, color: Color, textColor: Color, custom: Bool = false) -> some View {
        Button {
            haptic.toggle()
            Task {
                if let liked {
                    try await playerViewModel.swipeAction(liked: liked, unusedRecSongs: (customRecommendations ?? unusedRecSongs))
                } else if let token = spotifyTokenManager.token {
                    
                    if customFilter != nil {
                        withAnimation(.smooth) {
                            songModelManager.customFilter = nil
                        }
                    } else {
                        withAnimation(.bouncy) {
                            songModelManager.customFilter = CustomFilter(token: token, songModelManager: songModelManager)
                        }
                        try await playerViewModel.swipeAction(liked: nil, unusedRecSongs: (customRecommendations ?? unusedRecSongs))
                    }
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle((custom && customFilter != nil) ? filterButtonColors[0] : textColor)
                .grayscale(custom && customFilter == nil ? 1 : 0)
                .padding()
                .background {
                    Circle()
                        .fill((custom && customFilter != nil ? filterButtonColors[1] : color).opacity(0.8))
                        .frame(width: height, height: height)
                        .overlay {
                            Circle()
                                .stroke((custom && customFilter != nil ? filterButtonColors[1] : color).opacity(0.8), lineWidth: 2)
                                .frame(width: height, height: height)
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
