//
//  SongView2.swift
//  mews
//
//  Created by Desmond Fitch on 10/15/24.
//

import SwiftUI

struct SongView: View {
    @Environment(PlayerViewModel.self) var playerViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var song: SongModel? {
        playerViewModel.currentSong
    }
    var isPlaying: Bool {
        playerViewModel.isAvPlaying
    }
    @State private var artworkImage: UIImage?
    
    var body: some View {
        if let song {
            VStack(alignment: .leading, spacing: 24) {
                if let artworkImage {
                    Image(uiImage: artworkImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 16))
                        .shadow(color: (colorScheme == .dark ? Color.white : Color.black).opacity(0.25), radius: 8, x: 4, y: 8)
                        .overlay {
                            if !isPlaying {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.ultraThinMaterial.opacity(0.9))
                                    Image(systemName: "pause")
                                        .font(.title)
                                        .fontWeight(.black)
                                        .fontDesign(.rounded)
                                        .foregroundStyle(.appleMusic.opacity(0.9))
                                }
                            }
                        }
                        .onTapGesture {
                            withAnimation {
                                isPlaying ? playerViewModel.pauseAvPlayer() : playerViewModel.play()
                            }
                        }
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(song.title)
                                .lineLimit(1)
                            Image(systemName: "e.square.fill")
                        }
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                        
                        Text("Mixtape Pluto • \(song.artist)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(.appleMusic)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .padding(.leading)
                }
            }
            .transition(.slide)
            .task {
                if let imageURL = URL(string: song.artwork) {
                    artworkImage = await LibraryService().fetchArtwork(from: imageURL)
                }
            }
            .onChange(of: song) { _, newSong in
                Task {
                    withAnimation(.smooth(duration: 0.5)) {
                        playerViewModel.currentSong = nil
                    }
                    if let imageURL = URL(string: newSong.artwork) {
                        let artwork = await LibraryService().fetchArtwork(from: imageURL)
                        self.artworkImage = artwork
                        playerViewModel.currentSong = newSong
                    }
                }
            }
        }
    }
}
