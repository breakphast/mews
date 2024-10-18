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
    @Environment(SongModelManager.self) var songModelManager
    @Environment(PlayerViewModel.self) var playerViewModel
    @Environment(SpotifyTokenManager.self) var spotifyTokenManager
    @Environment(\.dismiss) var dismiss
    
    private var artists: [String] {
        libraryService.libraryArtists
    }
    
    private var savedCustomSongs: [SongModel] {
        songModelManager.customFilterSongs
    }
    
    private var seedOptions: [String] {
        switch filter.activeSeed {
        case .artist: artists
        case .genre: Genres.genres.keys.map { $0 }.sorted { $1 > $0 }
        }
    }
    
    @Bindable var filter: CustomFilter
    
    var body: some View {
        ZStack {
            Color.oreo.ignoresSafeArea()
            
            if !seedOptions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Capsule()
                        .fill(.snow.opacity(0.8))
                        .frame(width: 55, height: 6)
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Picker(selection: $filter.activeSeed, label: Text("Filter by")) {
                        Text("Artist").tag(SeedOption.artist)
                        Text("Genre").tag(SeedOption.genre)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 48)
                    
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(seedOptions, id: \.self) { option in
                                LazyVStack {
                                    Button {
                                        customSeedAction(option: option)
                                    } label: {
                                        HStack {
                                            Text(option)
                                                .fontWeight(.semibold)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .fontWeight(.bold)
                                        }
                                        .font(.title3)
                                    }
                                    .tint(.snow)
                                    
                                    Divider()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
        }
        .fontDesign(.rounded)
    }
    
    private func customSeedAction(option: String) {
        Task {
            filter.customFetchingActive = true
            playerViewModel.pauseAvPlayer()
            withAnimation {
                dismiss()
            }
            print(filter.activeSeed)
            if filter.activeSeed == .artist,
               let artist = await SpotifyService().fetchArtistID(
                artist: option,
                token: spotifyTokenManager.token ?? ""
               ),
               !option.lowercased().contains(artist.artistName.lowercased()) {
                print("Invalid Artist", [artist.artistName, option])
                filter.customFetchingActive = false
                return
            }
            try await songModelManager.deleteSongModels(songModels: savedCustomSongs)
            await filter.assignFilters(
                artist: filter.activeSeed == SeedOption.artist ? option : nil,
                genre: filter.activeSeed == SeedOption.genre ? Genres.genres[option] : nil
            )
            if let recs = await filter.getCustomRecommendations() {
                try? await filter.persistCustomRecommendations(songs: recs)
                try? await songModelManager.fetchItems()
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
