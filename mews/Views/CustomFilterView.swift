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
    @Environment(\.dismiss) var dismiss
    @State private var artistText = ""
    @State private var genreText = ""
    @FocusState private var focus: Bool
    
    private var artists: [String] {
        libraryService.artists.filter { artist in
            artistText.isEmpty || artist.lowercased().contains(artistText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
    }
    
    private var seedOptions: [String] {
        switch filter.activeSeed {
        case .artist:
            return artists.filter { artist in
                artistText.isEmpty || artist.lowercased().contains(artistText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            }
        case .genre:
            return Genres.genres.keys.filter { genre in
                genreText.isEmpty || genre.lowercased().contains(genreText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            }.sorted { $1 > $0 }
        }
    }
    
    private var savedCustomSongs: [SongModel] {
        libraryService.songModelManager.customFilterSongs
    }
    
    @Bindable var filter: CustomFilter
    var body: some View {
        ZStack {
            Color.oreo.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                Capsule()
                    .fill(.snow.opacity(0.8))
                    .frame(width: 55, height: 6)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                seedPicker
                seedTextField
                seedsScrollView
            }
            .padding(.top)
        }
        .fontDesign(.rounded)
    }
    
    private var seedPicker: some View {
        Picker(selection: $filter.activeSeed, label: Text("Filter by")) {
            Text("Artist").tag(SeedOption.artist)
            Text("Genre").tag(SeedOption.genre)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 48)
    }
    
    private var seedTextField: some View {
        TextField("Search for \(filter.activeSeed == .artist ? "library artist" : "genre")", text: (filter.activeSeed == .artist ? $artistText : $genreText))
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.oreo.opacity(0.7))
                    .shadow(color: .snow.opacity(0.1), radius: 12, x: 2, y: 2)
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
                if seedOptions.isEmpty {
                    Text("No results found")
                        .font(.headline)
                        .foregroundColor(.gray)
                } else {
                    ForEach(seedOptions, id: \.self) { option in
                        LazyVStack {
                            Button {
                                focus = false
                                customSeedAction(option: option)
                            } label: {
                                HStack {
                                    Text(option)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .font(.title3)
                            }
                            .tint(.snow)
                            
                            Divider()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func customSeedAction(option: String) {
        Task {
            filter.customFetchingActive = true
            playerViewModel.pauseAvPlayer()
            withAnimation {
                dismiss()
            }
            if filter.activeSeed == .artist,
               let artist = await spotifyService.fetchArtistID(artist: option),
               !option.lowercased().contains(artist.artistName.lowercased()) {
                print("Invalid Artist", [artist.artistName, option])
                filter.customFetchingActive = false
                return
            }
            await spotifyTokenManager.ensureValidToken()
            try await libraryService.songModelManager.deleteSongModels(songModels: savedCustomSongs)
            try await libraryService.fetchItems()
            await filter.assignFilters(
                artist: filter.activeSeed == SeedOption.artist ? option : nil,
                genre: filter.activeSeed == SeedOption.genre ? Genres.genres[option] : nil
            )
            if let recs = await filter.getCustomRecommendations() {
                try? await filter.persistCustomRecommendations(songs: recs)
                try? await libraryService.fetchItems()
                try await playerViewModel.swipeAction(liked: nil, unusedRecSongs: savedCustomSongs)
                filter.customFetchingActive = false
            }
        }
    }
}

//#Preview {
//    CustomFilterView()
//        .environment(LibraryService())
//}

enum SeedOption: String, CaseIterable {
    case artist = "Artist"
    case genre = "Genre"
}
