//
//  SongView2.swift
//  mews
//
//  Created by Desmond Fitch on 10/15/24.
//

import SwiftUI

struct SongView: View {
    @Environment(PlayerViewModel.self) var playerViewModel
    @Environment(SongModelManager.self) var songModelManager
    @Environment(LibraryService.self) var libraryService
    @Environment(\.colorScheme) var colorScheme
    
    var song: SongModel? {
        playerViewModel.currentSong
    }
    var isPlaying: Bool {
        playerViewModel.isAvPlaying
    }
    var recSong: SongModel? {
        if let song, let recSong = songModelManager.savedLibrarySongs.first(where: { $0.id == song.recSong }) {
            return recSong
        }
        return nil
    }
    @State private var artworkImage: UIImage?
    @State private var customMode = "artist"
    
    var recSeed: String? {
        return song?.recSeed
    }
    
    var body: some View {
        if let song {
            ZStack {
                if playerViewModel.initialLoad {
                    VStack(alignment: .leading, spacing: 24) {
                        if let artworkImage {
                            HStack(spacing: 1) {
                                if let recSong {
                                    Text("Inspired by:")
                                        .fontWeight(.light)
                                    Text("\(recSong.artist) - \(recSong.title)")
                                        .bold()
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "wand.and.stars")
                                            .foregroundStyle(.appleMusic)
                                            .fontWeight(.black)
                                        Text(recSeed ?? "")
                                    }
                                    .padding(.leading, -4)
                                    .padding(.bottom, -4)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.snow)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            
                            Image(uiImage: artworkImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(.rect(cornerRadius: 16))
                                .shadow(color: .snow.opacity(colorScheme == .light ? 0.25 : 0.05), radius: 8, x: 4, y: 8)
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
                                HStack(spacing: 2) {
                                    Text(song.title)
                                        .lineLimit(1)
                                    if song.explicit == true {
                                        Image(systemName: "e.square.fill")
                                    }
                                }
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                                
                                Text("\(song.album ?? "") • \(song.artist)")
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
                    .fontDesign(.rounded)
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: playerViewModel.swipeDirection)))
            .task {
                if let imageURL = URL(string: song.artwork) {
                    artworkImage = await Helpers.fetchArtwork(from: imageURL)
                    if !playerViewModel.initialLoad {
                        playerViewModel.initialLoad = true
                    }
                }
            }
            .onChange(of: song) { _, newSong in
                // song change trigger
                Task {
                    withAnimation(.bouncy) {
                        playerViewModel.currentSong = nil
                    }
                    if let imageURL = URL(string: newSong.artwork) {
                        let artwork = await Helpers.fetchArtwork(from: imageURL)
                        self.artworkImage = artwork
                        playerViewModel.currentSong = newSong
                    }
                }
            }
        }
    }
}
