//
//  PlaylistsView.swift
//  mews
//
//  Created by Desmond Fitch on 10/18/24.
//

import SwiftUI
import MusicKit

struct PlaylistsView: View {
    @Environment(LibraryService.self) var libraryService
    @Environment(\.dismiss) var dismiss
    @Binding var selected: String
    
    var playlistText: String {
        if let activePlaylist = libraryService.activePlaylist {
            activePlaylist.name
        } else if libraryService.saveToLibrary == true {
            "Library"
        } else {
            "Found with DiscoMuse"
        }
    }
    
    var body: some View {
        ZStack {
            Color.oreo.ignoresSafeArea()
            
            VStack(alignment: .leading) {
                Capsule()
                    .fill(.snow.opacity(0.6))
                    .frame(width: 55, height: 6)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text("Your Playlists")
                    .font(.largeTitle)
                    .fontWeight(.black)
                    .padding(.top, 24)
                    .padding(.bottom)
                
                HStack(spacing: 0) {
                    Text("Adding to: ")
                        .foregroundStyle(.snow)
                    Text(playlistText)
                        .foregroundStyle(.appleMusic.opacity(0.9))
                        .bold()
                }
                .font(.headline)
                .padding(.bottom, 8)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        PlaylistRow(selected: $selected, playlist: nil, library: true)
                        Divider()
                        if !libraryService.playlists.isEmpty {
                            ForEach(libraryService.playlists) { playlist in
                                if playlist != libraryService.activePlaylist {
                                    PlaylistRow(selected: $selected, playlist: playlist)
                                    Divider()
                                }
                            }
                        } else {
                            Spacer()
                            Text("No playlists found")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            Spacer()
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .task {
            try? await libraryService.fetchLibraryPlaylists()
        }
    }
}
