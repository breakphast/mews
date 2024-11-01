//
//  SeedsScrollView.swift
//  mews
//
//  Created by Desmond Fitch on 11/1/24.
//

import SwiftUI
import MusicKit

struct SeedsScrollView: View {
    @Environment(CustomFilterService.self) var customFilterService
    @Environment(LibraryService.self) var libraryService
    
    @Binding var artistText: String
    @Binding var genreText: String
    @Binding var selectedSeeds: [String: SeedType]
    @Binding var artistSearchResults: MusicItemCollection<Artist>
    @FocusState.Binding var focus: Bool
    
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
    
    private var token: String? {
        customFilterService.token
    }
    
    @Bindable var filter: CustomFilterModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if artistSearchResults.isEmpty && seedOptions.isEmpty {
                    Text("No results found")
                        .font(.headline)
                        .foregroundStyle(.gray.opacity(0.9))
                }
                if !artistSearchResults.isEmpty && filter.activeSeedOption == SeedOption.artist.rawValue {
                    let options = Array(artistSearchResults).map { $0.name }
                    Text("Search results")
                        .font(.headline)
                        .fontWeight(.heavy)
                        .foregroundStyle(.appleMusic.opacity(0.9))
                    ForEach(options, id: \.self) { option in
                        VStack {
                            Button {
                                focus = false
                                withAnimation(.bouncy) {
                                    if selectedSeeds.count < 5 {
                                        selectedSeeds[option] = filter.activeSeedOption == SeedOption.artist.rawValue ?
                                            .artist : .genre
                                    }
                                }
                                
                                Task {
                                    guard await validArtistCheck(artistName: option, token: token ?? "") else { return }
                                }
                            } label: {
                                HStack {
                                    Text(option)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    if selectedSeeds.keys.contains(option) {
                                        Image(systemName: "wand.and.stars")
                                            .foregroundStyle(.appleMusic)
                                            .bold()
                                    }
                                }
                            }
                            .tint(selectedSeeds.keys.contains(option) ? .appleMusic.opacity(0.9) : .snow)
                            
                            if options.last != option {
                                Divider()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if filter.activeSeedOption == SeedOption.artist.rawValue && !seedOptions.isEmpty {
                    Text("Library Artists")
                        .font(.headline)
                        .fontWeight(.heavy)
                        .foregroundStyle(.appleMusic.opacity(0.9))
                        .padding(.top, 8)
                }
                ForEach(seedOptions, id: \.self) { option in
                    VStack {
                        Button {
                            focus = false
                            withAnimation(.bouncy) {
                                if selectedSeeds.count < 5 {
                                    selectedSeeds[option] = filter.activeSeedOption == SeedOption.artist.rawValue ?
                                        .artist : .genre
                                }
                            }
                            
                            Task {
                                guard await validArtistCheck(artistName: option, token: token ?? "") else { return }
                            }
                        } label: {
                            HStack {
                                Text(option)
                                    .fontWeight(.semibold)
                                Spacer()
                                if selectedSeeds.keys.contains(option) {
                                    Image(systemName: "wand.and.stars")
                                        .foregroundStyle(.appleMusic)
                                        .bold()
                                }
                            }
                        }
                        .tint(selectedSeeds.keys.contains(option) ? .appleMusic.opacity(0.9) : .snow)
                        
                        Divider()
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.horizontal)
        }
        .transaction { transaction in
            transaction.animation = nil
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
}
