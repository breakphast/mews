//
//  CustomFilterView.swift
//  mews
//
//  Created by Desmond Fitch on 10/16/24.
//

import SwiftUI
import MusicKit

struct CustomFilterView: View {
    @Environment(LibraryService.self) var libraryService
    @Environment(PlayerViewModel.self) var playerViewModel
    @Environment(SpotifyTokenManager.self) var spotifyTokenManager
    @Environment(SpotifyService.self) var spotifyService
    @Environment(CustomFilterService.self) var customFilterService
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var artistText = ""
    @State private var genreText = ""
    @FocusState private var focus: Bool
    @State private var selectedSeed: String?
    
    private var artists: [String] {
        libraryService.artists.filter { artist in
            artistText.isEmpty || artist.lowercased().contains(artistText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
    }
    
    private var seedOptions: [String] {
        switch SeedOption(rawValue: filter.activeSeed) {
        case .artist:
            return artists.filter { artist in
                artistText.isEmpty || artist.lowercased().contains(artistText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            }
        case .genre:
            return Genres.genres.keys.filter { genre in
                genreText.isEmpty || genre.lowercased().contains(genreText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            }.sorted { $1 > $0 }
        case .none:
            return []
        }
    }
    
    private var savedCustomSongs: [SongModel] {
        customFilterService.customFilterModel?.songs ?? []
    }
    
    private var token: String? {
        customFilterService.token
    }
    
    @Bindable var filter: CustomFilterModel
    var body: some View {
        ZStack {
            Color.oreo.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                Capsule()
                    .fill(.snow.opacity(0.6))
                    .frame(width: 55, height: 6)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                CustomPicker(activeSeed: $filter.activeSeed)
                seedTextField
                seedsScrollView
            }
            .padding(.top, 8)
        }
        .fontDesign(.rounded)
        .task {
            if let seed = savedCustomSongs.first?.recSeed {
                selectedSeed = seed
            }
            if artists.isEmpty {
                await libraryService.getSavedLibraryArtists()
            }
        }
    }
    
    private var seedTextField: some View {
        TextField("Search for \(filter.activeSeed == SeedOption.artist.rawValue ? "artist in library" : "genre")", text: (filter.activeSeed == SeedOption.artist.rawValue ? $artistText : $genreText))
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.oreo.opacity(0.9))
                    .shadow(color: .snow.opacity(colorScheme == .light ? 0.15 : 0.05), radius: 4, x: 2, y: 2)
            }
            .padding(.vertical, 8)
            .bold()
            .autocorrectionDisabled()
            .padding(.horizontal)
            .tint(.appleMusic)
            .focused($focus)
    }
    
    private var seedsScrollView: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if let selectedSeed {
                    VStack {
                        HStack {
                            Text(selectedSeed)
                            Spacer()
                            Image(systemName: "wand.and.stars")
                        }
                        .foregroundStyle(.appleMusic.opacity(0.9))
                        .font(.title3.bold())
                    }
                    Divider()
                }
                
                if seedOptions.isEmpty {
                    Text("No results found")
                        .font(.headline)
                        .foregroundColor(.gray)
                } else {
                    ForEach(seedOptions, id: \.self) { option in
                        VStack {
                            Button {
                                focus = false
                                selectCustomSeed(option: option)
                            } label: {
                                HStack {
                                    Text(option)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    if option == selectedSeed {
                                        Image(systemName: "wand.and.stars")
                                            .foregroundStyle(.appleMusic)
                                            .bold()
                                    }
                                }
                                .font(.title3)
                            }
                            .tint(option == selectedSeed ? .appleMusic.opacity(0.9) : .snow)
                            
                            Divider()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal)
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }
    
    private func selectCustomSeed(option: String) {
        Task {
            customFilterService.customFetchingActive = true
            playerViewModel.pauseAvPlayer()
            withAnimation {
                dismiss()
            }
            guard let token else { return }
            if filter.activeSeed == SeedOption.artist.rawValue,
               let artist = await SpotifyService.fetchArtistID(artist: option, token: token),
               !option.lowercased().contains(artist.artistName.lowercased()) {
                print("Invalid Artist", [artist.artistName, option])
                customFilterService.customFetchingActive = false
                return
            }
            
            await spotifyTokenManager.ensureValidToken()
            try await libraryService.songModelManager.deleteSongModels(songModels: savedCustomSongs)
            try await libraryService.songModelManager.fetchItems()
            await customFilterService.assignFilters(
                artist: filter.activeSeed == SeedOption.artist.rawValue ? option : nil,
                genre: filter.activeSeed == SeedOption.genre.rawValue ? option : nil
            )
            if let recs = await customFilterService.getCustomRecommendations() {
                try? await customFilterService.persistCustomRecommendations(songs: recs)
                try await libraryService.songModelManager.fetchItems()
                try await playerViewModel.swipeAction(liked: nil, recSongs: savedCustomSongs, limit: false)
                customFilterService.customFetchingActive = false
            }
        }
    }
}

enum SeedOption: String, CaseIterable {
    case artist = "Artist"
    case genre = "Genre"
}
