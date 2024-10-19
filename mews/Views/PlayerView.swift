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
    @Environment(AuthService.self) var authService
    @Environment(LibraryService.self) var libraryService
    @Environment(SpotifyService.self) var spotifyService
    @Environment(\.colorScheme) var colorScheme
    
    @Bindable var playerViewModel: PlayerViewModel
    
    private var songModelManager: SongModelManager {
        libraryService.songModelManager
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
        ZStack {
            Color.oreo.ignoresSafeArea()
            
            VStack(spacing: 24) {
                if let customFilter, customFilter.customFetchingActive, !customFilter.lowRecsActive {
                    splash
                } else {
                    navBar
                    Spacer()
                    if playerViewModel.currentSong != nil {
                        SongView(opacity: $playerViewModel.opacity)
                        Spacer()
                    }
                    buttons
                }
            }
            .padding()
            .task {
                assignNewSong()
            }
            .onChange(of: unusedRecSongs.count) { _, newCount in
                guard newCount <= 15 else { return }
                if let customFilter, customFilter.lowRecsActive || customFilter.customFetchingActive {
                    return
                }
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
            .sheet(isPresented: $playerViewModel.showFilters) {
                if let customFilter, !customFilter.customFetchingActive, !customFilter.active {
                    songModelManager.customFilter = nil
                }
            } content: {
                if let customFilter {
                    CustomFilterView(filter: customFilter)
                }
            }
            .sheet(isPresented: $playerViewModel.showSettings) {
                PlaylistsView()
            }
        }
        .task {
            Task {
                try await authorizeAndFetch()
            }
        }
    }
    
    private var splash: some View {
        Image(systemName: "wand.and.stars")
            .resizable()
            .scaledToFit()
            .frame(width: playerViewModel.scale, height: playerViewModel.scale)
            .foregroundStyle(.appleMusic)
            .onAppear {
                withAnimation(.bouncy(extraBounce: 0.1).repeatForever(autoreverses: true)) {
                    playerViewModel.scale = 200
                }
            }
            .onDisappear {
                playerViewModel.scale = 50
            }
    }
    
    private func assignNewSong() {
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
        Task {
            await
            spotifyService.lowRecsTrigger(
                songs: songModelManager.savedLibrarySongs,
                recSongs: songModelManager.savedRecSongs,
                dislikedSongs: songModelManager.savedDeletedSongs?.map { $0.url } ?? [])
            
            try await libraryService.fetchItems()
        }
    }
    
    private var navBar: some View {
        HStack {
            Image(systemName: "slider.horizontal.2.square")
                .font(.largeTitle)
                .onTapGesture {
                    withAnimation(.bouncy) {
                        playerViewModel.showFilters.toggle()
                        if customFilter == nil {
                            songModelManager.customFilter = CustomFilter(spotifyService: spotifyService, songModelManager: songModelManager)
                        }
                    }
                }
            Spacer()
            Text("Mews")
                .font(.title)
            Spacer()
            Image(systemName: "person.circle")
                .font(.largeTitle)
                .onTapGesture {
                    withAnimation {
                        playerViewModel.showSettings.toggle()
                    }
                }
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
            playerViewModel.haptic.toggle()
            playerViewModel.opacity = 0
            Task { @MainActor in
                if let liked, let avSong = playerViewModel.currentSong {
                    playerViewModel.switchingSongs = true
                    
                    guard let playlist = await libraryService.getPlaylist() else { return }
                    
                    try await playerViewModel.swipeAction(liked: liked, unusedRecSongs: (customRecommendations ?? unusedRecSongs), playlist: playlist)
                    try await songModelManager.deleteSongModel(songModel: avSong)
                    try await libraryService.fetchItems()
                } else if customFilter != nil {
                    withAnimation(.bouncy) {
                        songModelManager.customFilter = nil
                    }
                    try await playerViewModel.swipeAction(liked: nil, unusedRecSongs: unusedRecSongs)
                } else {
                    withAnimation(.bouncy) {
                        // assign custom filter regardless
                        songModelManager.customFilter = CustomFilter(spotifyService: spotifyService, songModelManager: songModelManager)
                        // if there are no customRecs to use, open up custom filter view
                        if customRecommendations == nil { playerViewModel.showFilters.toggle() }
                    }
                    if let customRecommendations {
                        // if there are customRecs, advance to next song using custom bucket
                        try await playerViewModel.swipeAction(liked: nil, unusedRecSongs: customRecommendations)
                        customFilter?.active = true
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
                        .frame(width: playerViewModel.height, height: playerViewModel.height)
                        .overlay {
                            Circle()
                                .stroke((custom && customFilter != nil ? filterButtonColors[1] : color).opacity(0.8), lineWidth: 2)
                                .frame(width: playerViewModel.height, height: playerViewModel.height)
                        }
                        .shadow(color: .snow.opacity(colorScheme == .light ? 0.3 : 0.05), radius: 6, x: 2, y: 4)
                }
        }
        .disabled(playerViewModel.switchingSongs)
        .sensoryFeedback((liked ?? true) ? .impact(weight: .heavy) : .impact(weight: .light), trigger: playerViewModel.haptic)
    }
    
    private func authorizeAndFetch() async throws {
        if authService.status != .authorized {
            await authService.authorizeAction()
        }
        try await libraryService.fetchItems()
        await libraryService.getSavedLibraryArtists()
        try await libraryService.fetchLibraryPlaylists()
        if songModelManager.savedSongs.isEmpty || songModelManager.unusedRecSongs.count <= 10 {
            if let recommendations = await libraryService.getHeavyRotation() {
                var librarySongs = [Song]()
                // find library rotation songs in catalog and return
                for recommendation in recommendations {
                    if let catalogSong = await LibraryService.fetchCatalogSong(title: recommendation.name, artist: recommendation.artistName) {
                        print("Found song in Apple Catalog: \(catalogSong.artistName) - \(catalogSong.title)")
                        if !songModelManager.savedLibrarySongs.contains(where: { $0.id == catalogSong.id.rawValue }) {
                            librarySongs.append(catalogSong)
                        }
                    }
                }
                // save library songs
                try await libraryService.persistLibrarySongs(songs: librarySongs)
                try await libraryService.fetchItems()
                
                // use catalog songs to get spotify recs and persist non catalog
                if let recommendedSongs = await spotifyService.getRecommendations(
                    using: songModelManager.savedLibrarySongs,
                    recSongs: songModelManager.savedRecSongs,
                    dislikedSongs: songModelManager.savedDeletedSongs?.map { $0.url } ?? []
                   ) {
                    try await spotifyService.persistRecommendations(songs: recommendedSongs)
                    try await libraryService.fetchItems()
                }
                
                if let song = songModelManager.unusedRecSongs.randomElement() {
                    let songURL = URL(string: song.previewURL)
                    if let songURL = songURL {
                        let playerItem = AVPlayerItem(url: songURL)
                        await playerViewModel.assignPlayerSong(item: playerItem, song: song)
                    }
                }
            }
        } else {
            if let song = songModelManager.unusedRecSongs.randomElement() {
                let songURL = URL(string: song.previewURL)
                if let songURL = songURL {
                    let playerItem = AVPlayerItem(url: songURL)
                    await playerViewModel.assignPlayerSong(item: playerItem, song: song)
                }
            }
        }
    }
}
