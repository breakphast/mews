//
//  Settings.swift
//  mews
//
//  Created by Desmond Fitch on 10/26/24.
//

import SwiftUI
import MusicKit

struct Settings: View {
    @Environment(\.dismiss) var dismiss
    @Environment(PlayerViewModel.self) var playerViewModel
    @Environment(LibraryService.self) var libraryService
    
    var activePlaylist: Playlist? {
        if selectedPlaylist == "Library" {
            nil
        } else {
            libraryService.activePlaylist
        }
    }
    @State private var selectedPlaylist = "Library"
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.oreo.ignoresSafeArea()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .bold()
                    .padding()
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                    }
            }
            .tint(.snow)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing)
            
            VStack(alignment: .leading, spacing: 32) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.black)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 24) {
                            Text("Pro")
                                .font(.headline.bold())
                            button(icon: "plus.circle", text: "Save liked songs to:", picker: true)
                            separator
                            button(icon: "wand.and.stars", text: "Upgrade to Pro")
                            separator
                            button(icon: "arrow.clockwise", text: "Restore Purchases")
                            separator
                        }
                        VStack(alignment: .leading, spacing: 24) {
                            Text("General")
                                .font(.headline.bold())
                            button(icon: "star", text: "Rate and Review")
                            separator
                            button(icon: "envelope", text: "Contact Us")
                            separator
                            button(icon: "shield", text: "Privacy Policy")
                            separator
                            button(icon: "doc.plaintext", text: "Terms")
                        }
                    }
                }
            }
            .padding(.top, 48)
            .padding(.leading, 24)
            .padding(.trailing, 16)
        }
        .task {
            try? await libraryService.fetchLibraryPlaylists()
        }
    }
    
    private var playlistPicker: some View {
        Picker(selection: $selectedPlaylist) {
            ForEach(libraryService.likeActionOptions, id: \.self) { option in
                Text(option)
            }
        } label: {
            Text("\(libraryService.activePlaylist?.name ?? "Library")")
        }
        .bold()
        .offset(x: -12)
        .scrollIndicators(.hidden)
    }
    
    private var separator: some View {
        Divider()
            .padding(.trailing, 24)
    }
    
    private func button(icon: String, text: String, picker: Bool = false) -> some View {
        VStack(alignment: .leading) {
            Button {
                
            } label: {
                HStack {
                    Image(systemName: icon)
                        .font(.title2.bold())
                        .frame(width: 33, alignment: .leading)
                    Text(text)
                    if picker {
                        playlistPicker
                            .tint(.snow)
                    }
                }
            }
            .tint(.snow)
        }
    }
}

#Preview {
    Settings()
        .environment(PlayerViewModel())
        .environment(LibraryService(songModelManager: SongModelManager()))
}
