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
    @Environment(\.dismiss) var dismiss
    @State var activeSeed: SeedOption = .artist
    
    private var artists: [String] {
        libraryService.libraryArtists
    }
    
    private var seedOptions: [String] {
        switch activeSeed {
        case .artist: return artists
        case .genre: return Genres.genres
        }
    }
    
    var body: some View {
        ZStack {
            Color.oreo.ignoresSafeArea()
            
            if !seedOptions.isEmpty {
                VStack(alignment: .leading) {
                    Image(systemName: "arrow.left")
                        .font(.title.bold())
                        .foregroundStyle(.oreo)
                        .padding(8)
                        .background(Circle().fill(.white))
                        .padding(.leading)
                        .onTapGesture {
                            dismiss()
                        }
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(seedOptions, id: \.self) { option in
                                VStack {
                                    Button {
                                        Task {
                                            await songModelManager.customFilter?.assignFilters(
                                                artist: activeSeed == SeedOption.artist ? option : nil,
                                                genre: activeSeed == SeedOption.genre ? option : nil
                                            )
                                            dismiss()
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
