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
    @State private var scale: CGFloat = 50
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
    
    var token: String? {
        return spotifyTokenManager.token
    }
    
    var body: some View {
        ZStack {
            Color.oreo.ignoresSafeArea()
            
            VStack(spacing: 24) {
                if let customFilter, customFilter.customFetchingActive, !customFilter.lowRecsActive {
                    splash
                } else {
                    navBar
                    Spacer()
                    if avSong != nil {
                        SongView()
                        Spacer()
                    }
                    if playerViewModel.initialLoad {
                        buttons
                    }
                }
            }
            .padding()
            .task {
                assignNewSong()
            }
            .onChange(of: unusedRecSongs.count) { _, newCount in
                guard newCount <= 10, let customFilter, !customFilter.lowRecsActive, !customFilter.customFetchingActive else { return }
                if !spotifyService.fetchingActive {
                    lowRecsTrigger()
                }
            }
            .onChange(of: songModelManager.customFilterSongs.count) { _, songCount in
                guard songCount <= 10 else { return }
                if let customFilter, !customFilter.customFetchingActive,
                   let song = songModelManager.customFilterSongs.first {
                    Task {
                        let genre = Genres.genres[song.recSeed ?? ""]
                        await customFilter.assignFilters(
                            artist: customFilter.activeSeed == .artist ? song.recSeed : nil,
                            genre: customFilter.activeSeed != .artist ? genre ?? "" : nil
                        )
                        await customFilter.lowCustomRecsTrigger()
                        customFilter.lowRecsActive = false
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                if let customFilter, !customFilter.customFetchingActive, !customFilter.active {
                    songModelManager.customFilter = nil
                }
            } content: {
                if let customFilter {
                    CustomFilterView(filter: customFilter)
                }
            }
        }
    }
    
    private var splash: some View {
        Image(systemName: "wand.and.stars")
            .resizable()
            .scaledToFit()
            .frame(width: scale, height: scale)
            .foregroundStyle(.appleMusic)
            .onAppear {
                withAnimation(.bouncy(extraBounce: 0.1).repeatForever(autoreverses: true)) {
                    scale = 200
                }
            }
            .onDisappear {
                scale = 50
            }
    }
    
    private func assignNewSong() {
        guard !playerViewModel.initialLoad else { return }
        
        withAnimation {
            playerViewModel.image = nil
        }
        if let song = (customRecommendations ?? unusedRecSongs).randomElement(),
           let url = URL(string: song.previewURL) {
            Task {
                let playerItem = AVPlayerItem(url: url)
                if albumImage == nil {
                    await playerViewModel.assignPlayerSong(item: playerItem, song: song)
                }
            }
        }
    }
    
    // MARK: - Functions
    
    private func lowRecsTrigger() {
        guard let token else { return }
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
    
    private var navBar: some View {
        HStack {
            Image(systemName: "slider.horizontal.2.square")
                .font(.largeTitle)
                .onTapGesture {
                    withAnimation(.bouncy) {
                        showFilters.toggle()
                        if let token, customFilter == nil {
                            songModelManager.customFilter = CustomFilter(token: token, songModelManager: songModelManager)
                        }
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
            Task { @MainActor in
                if let liked, let avSong {
                    try await playerViewModel.swipeAction(liked: liked, unusedRecSongs: (customRecommendations ?? unusedRecSongs))
                    try await songModelManager.deleteSongModel(songModel: avSong)
                } else if let token {
                    if customFilter != nil {
                        withAnimation(.bouncy) {
                            songModelManager.customFilter = nil
                        }
                        try await playerViewModel.swipeAction(liked: nil, unusedRecSongs: unusedRecSongs)
                    } else {
                        withAnimation(.bouncy) {
                            // assign custom filter regardless
                            songModelManager.customFilter = CustomFilter(token: token, songModelManager: songModelManager)
                            // if there are no customRecs to use, open up custom filter view
                            if customRecommendations == nil { showFilters.toggle() }
                        }
                        if let customRecommendations {
                            // if there are customRecs, advance to next song using custom bucket
                            try await playerViewModel.swipeAction(liked: nil, unusedRecSongs: customRecommendations)
                            customFilter?.active = true
                        }
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
