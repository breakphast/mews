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
    @Environment(\.dismiss) var dismiss
    
    private var artists: [String] {
        libraryService.libraryArtists
    }
    
    private var savedCustomSongs: [SongModel] {
        return songModelManager.customFilterSongs
    }
    
    private var seedOptions: [String] {
        switch customFilter?.activeSeed {
        case .artist: return artists
        default: return Genres.genres
        }
    }
    
    private var customFilter: CustomFilter? {
        songModelManager.customFilter
    }
    
    var body: some View {
        ZStack {
            Color.oreo.ignoresSafeArea()
            
            if !seedOptions.isEmpty {
                VStack(alignment: .leading) {
                    Image(systemName: "arrow.left")
                        .font(.title.bold())
                        .foregroundStyle(.snow)
                        .padding(8)
                        .background(Circle().fill(.oreo))
                        .padding(.leading)
                        .onTapGesture {
                            if savedCustomSongs.isEmpty {
                                songModelManager.customFilter = nil
                            }
                            dismiss()
                        }
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(seedOptions, id: \.self) { option in
                                VStack {
                                    Button {
                                        Task {
                                            guard let customFilter else { return }
                                            try await songModelManager.deleteSongModels(songModels: savedCustomSongs)
                                            await customFilter.assignFilters(
                                                artist: customFilter.activeSeed == SeedOption.artist ? option : nil,
                                                genre: customFilter.activeSeed == SeedOption.genre ? option : nil
                                            )
                                            withAnimation {
                                                dismiss()
                                            }
                                            if let recs = await customFilter.getCustomRecommendations() {
                                                try? await customFilter.persistCustomRecommendations(songs: recs)
                                                try? await songModelManager.fetchItems()
                                                try await playerViewModel.swipeAction(liked: nil, unusedRecSongs: savedCustomSongs)
                                            }
                                        }
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
                        .padding()
                    }
                    .padding(.top, 4)
                }
                .padding(.top)
            }
        }
        .fontDesign(.rounded)
    }
}

#Preview {
    CustomFilterView()
        .environment(LibraryService())
}

enum SeedOption: String, CaseIterable {
    case artist = "Artist"
    case genre = "Genre"
}
