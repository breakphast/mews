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
    
    var body: some View {
        ZStack {
            Color.oreo.ignoresSafeArea()
            
            VStack(alignment: .leading) {
                Capsule()
                    .fill(.snow.opacity(0.8))
                    .frame(width: 55, height: 6)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text("Playlists")
                    .font(.largeTitle.bold())
                    .fontDesign(.rounded)
                    .padding(.vertical)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(libraryService.playlists) { playlist in
                            PlaylistRow(playlist: playlist)
                                .onTapGesture {
                                    libraryService.activePlaylist = playlist
                                    withAnimation(.bouncy) {
                                        dismiss()
                                    }
                                }
                            Divider()
                        }
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    PlaylistsView()
}

struct PlaylistRow: View {
    let playlist: Playlist
    
    var body: some View {
        HStack {
            Text(playlist.name)
                .foregroundStyle(.snow)
                .font(.title3)
                .fontDesign(.rounded)
            Spacer()
        }
        .padding(.vertical, 4)
        .bold()
    }
}
