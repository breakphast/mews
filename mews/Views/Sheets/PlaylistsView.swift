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
        } else {
            "Found with DiscoMuse"
        }
    }
    
    var body: some View {
        ZStack {
            Color.oreo.ignoresSafeArea()
            
            VStack(alignment: .leading) {
                Capsule()
                    .fill(.snow.opacity(0.8))
                    .frame(width: 55, height: 6)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text("Your Playlists")
                    .font(.largeTitle.bold())
                    .padding(.top, 24)
                    .padding(.bottom)
                
                Text("Active Playlist: \(playlistText)")
                    .font(.title3.bold())
                    .padding(.bottom, 8)
                    .foregroundStyle(.appleMusic)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if !libraryService.playlists.isEmpty {
                            ForEach(libraryService.playlists) { playlist in
                                if playlist != libraryService.activePlaylist {
                                    PlaylistRow(playlist: playlist)
                                        .onTapGesture {
                                            libraryService.activePlaylist = playlist
                                            selected = playlist.name
                                            Helpers.saveToUserDefaults(playlist.name, forKey: "defaultPlaylist")
                                            withAnimation(.bouncy) {
                                                dismiss()
                                            }
                                        }
                                    Divider()
                                }
                            }
                        } else {
                            Text("No playlists in library")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .task {
            try? await libraryService.fetchLibraryPlaylists()
        }
    }
}
