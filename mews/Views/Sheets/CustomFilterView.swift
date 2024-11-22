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
    @State private var selectedSeeds = [String: SeedType]()
    @State private var artistSearchResults = MusicItemCollection<Artist>()
    
    private var artists: [String] {
        libraryService.artists.filter { artist in
            artistText.isEmpty || artist.lowercased().contains(artistText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
    }
    
    private var seedOptions: [String] {
        switch SeedOption(rawValue: filter.activeSeedOption) {
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
                
                CustomPicker(activeSeed: $filter.activeSeedOption)
                seedTextField
                
                if !selectedSeeds.isEmpty {
                    activeFiltersModule
                    getRecsButton
                }
                
                SeedsScrollView(
                    artistText: $artistText,
                    genreText: $genreText,
                    selectedSeeds: $selectedSeeds,
                    artistSearchResults: $artistSearchResults,
                    focus: $focus,
                    filter: filter
                )
            }
            .padding(.top, 8)
        }
        .fontDesign(.rounded)
        .task {
            addSeeds()
            if artists.isEmpty {
                await libraryService.getSavedLibraryArtists()
            }
        }
    }
    
    private var getRecsButton: some View {
        Button {
            Task { executeCustomFetch() }
        } label: {
            HStack(spacing: 4) {
                Text("Get Recommendations")
                Image(systemName: "wand.and.stars")
            }
            .padding(12)
            .foregroundStyle(.white)
            .bold()
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.appleMusic.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    private var activeFiltersModule: some View {
        VStack(alignment: .leading) {
            Text("Active Filters (maximum of 5)")
                .font(.caption.bold())
            VStack(spacing: 4) {
                ForEach(Array(selectedSeeds.keys.sorted()), id: \.self) { seed in
                    VStack {
                        HStack(alignment: .center) {
                            Text(seed)
                                .foregroundStyle(.appleMusic.opacity(0.9))
                            Spacer()
                            Image(systemName: "xmark.circle")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.snow.opacity(0.9))
                                .onTapGesture {
                                    removeSeed(seed: seed, filter: filter)
                                    selectedSeeds.removeValue(forKey: seed)
                                }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    var searchFieldText: String {
        switch SeedOption(rawValue: filter.activeSeedOption) {
        case .artist:
            "Search for artists"
        case .genre:
            "Search for genres"
        case .none:
            "Search"
        }
    }
    private var seedTextField: some View {
        ZStack(alignment: .trailing) {
            TextField(searchFieldText, text: $artistText, onCommit: {
                if artistText.isEmpty {
                    artistSearchResults = []
                } else {
                    performSearch(query: artistText)
                }
            })
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
            .submitLabel(.search)
            
            if !artistText.isEmpty {
                Button(action: {
                    artistText = ""
                    artistSearchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 24)
            }
        }
    }
    
    private func executeCustomFetch() {
        Task {
            customFilterService.customFetchingActive = true
            playerViewModel.pauseAvPlayer()
            withAnimation {
                dismiss()
            }
            
            await spotifyTokenManager.ensureValidToken()
            try await libraryService.songModelManager.deleteSongModels(songModels: savedCustomSongs)
            try await libraryService.songModelManager.fetchItems()
            let artistSeeds = selectedSeeds.filter { $0.value == .artist }.map { $0.key }
            let genreSeeds = selectedSeeds.filter { $0.value == .genre }.map { $0.key }
            await customFilterService.assignSeeds(artists: artistSeeds, genres: genreSeeds)
            if let recs = await customFilterService.getCustomRecommendations() {
                try? await customFilterService.persistCustomRecommendations(songs: recs)
                try await libraryService.songModelManager.fetchItems()
                try await playerViewModel.swipeAction(liked: nil, recSongs: savedCustomSongs, limit: false)
                customFilterService.customFetchingActive = false
            }
        }
    }
    
    func validArtistCheck(artistName: String, token: String) async -> Bool {
        if filter.activeSeedOption == SeedOption.artist.rawValue,
           let artist = await SpotifyService.fetchArtistID(artist: artistName, token: token),
           !artistName.lowercased().contains(artist.artistName.lowercased()) {
            print("Invalid Artist", artist)
            customFilterService.customFetchingActive = false
            return false
        } else {
            return true
        }
    }
    
    func performSearch(query: String) {
        Task {
            var request = MusicCatalogSearchRequest(term: query, types: [Artist.self])
            request.limit = 3 // Adjust as needed
            
            do {
                let response = try await request.response()
                self.artistSearchResults = response.artists
            } catch {
                print("Search failed: \(error.localizedDescription)")
            }
        }
    }
    
    func removeSeed(seed: String, filter: CustomFilterModel) {
        selectedSeeds.removeValue(forKey: seed)
        
        if let index = filter.artists.firstIndex(where: {$0.value == seed}) {
            filter.songs.removeAll(where: {$0.recSeed == seed})
            filter.artists.remove(at: index)
        }
                
        // Remove from genreSeeds if it contains the seed
        if let genre = Genres.genres.first(where: { $0.key == seed })?.value, let index = filter.genreSeeds.firstIndex(of: genre) {
            filter.songs.removeAll(where: {$0.recSeed == seed})
            filter.genreSeeds.remove(at: index)
        }
        try? Helpers.container.mainContext.save()
    }
    
    func addSeeds() {
        for artist in filter.artists {
            selectedSeeds[artist.value] = .artist
        }
        for genre in filter.genreSeeds {
            if let genre = Genres.genres.first(where: { $0.value == genre })?.key {
                selectedSeeds[genre] = .genre
            }
        }
    }
}
