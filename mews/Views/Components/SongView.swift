//
//  SongView2.swift
//  mews
//
//  Created by Desmond Fitch on 10/15/24.
//

import SwiftUI

struct SongView: View {
    @Environment(PlayerViewModel.self) var playerViewModel
    @Environment(LibraryService.self) var libraryService
    @Environment(CustomFilterService.self) var customFilterService
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) var openURL
    @Binding var opacity: Double
    @Binding var show: Bool
    @Binding var currentSpot: Int
    
    @State private var artworkImage: UIImage?
    @State private var customMode = "artist"
    @State private var isLandscape: Bool = UIScreen.main.bounds.width > UIScreen.main.bounds.height
        
    var recSeed: String? {
        return playerViewModel.currentSong?.recSeed == "" ? nil : playerViewModel.currentSong?.recSeed
    }
    
    var body: some View {
        if let song = playerViewModel.currentSong {
            ZStack {
                VStack(spacing: 24) {
                    if let artworkImage {
                        HStack(spacing: 1) {
                            if let recSeed {
                                HStack(spacing: 4) {
                                    Image(systemName: "wand.and.stars")
                                        .foregroundStyle(.appleMusic)
                                        .fontWeight(.black)
                                    Text(recSeed)
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
                        
                        VStack(spacing: 24) {
                            Image(uiImage: artworkImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(.rect(cornerRadius: 16))
                                .shadow(color: .snow.opacity(colorScheme == .light ? 0.25 : 0.05), radius: 8, x: 4, y: 8)
                                .addSpotlight(0, shape: .rounded, roundedRadius: 16, text: "Tap artwork to pause or play")
                                .overlay {
                                    if !playerViewModel.isAvPlaying {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(.ultraThinMaterial.opacity(0.6))
                                            Image(systemName: "pause")
                                                .font(.title)
                                                .fontWeight(.black)
                                                .fontDesign(.rounded)
                                                .foregroundStyle(.appleMusic.opacity(0.9))
                                        }
                                    }
                                }
                                .onTapGesture {
                                    if currentSpot == 0 {
                                        currentSpot += 1
                                    }
                                    withAnimation {
                                        playerViewModel.isAvPlaying ? playerViewModel.pauseAvPlayer() : playerViewModel.play()
                                    }
                                }
                            
                            if playerViewModel.currentSong != nil {
                                songInfo(song: song)
                                    .padding(.horizontal, (Helpers.idiom == .pad ? 16 : 0))
                            }
                        }
                        .frame(maxWidth: Helpers.idiom == .pad ? (isLandscape ? 400 : .infinity) : .infinity)
                    }
                }
                .fontDesign(.rounded)
            }
            .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: playerViewModel.swipeDirection)))
            .task {
                if let imageURL = URL(string: song.artwork) {
                    artworkImage = await Helpers.fetchArtwork(from: imageURL)
                }
            }
            .onOrientationChange(isLandscape: $isLandscape)
            .onChange(of: song) { _, newSong in
                Task {
                    withAnimation(.bouncy.speed(0.8)){
                        playerViewModel.currentSong = nil
                    }
                    if let imageURL = URL(string: newSong.artwork) {
                        let artwork = await Helpers.fetchArtwork(from: imageURL)
                        self.artworkImage = artwork
                        playerViewModel.currentSong = newSong
                        withAnimation(.easeIn.speed(0.6)) {
                            opacity = 1
                            playerViewModel.switchingSongs = false
                        }
                    }
                }
            }
            .onChange(of: UIScreen.main.bounds.height) { _, _ in
                isLandscape = UIScreen.main.bounds.width > UIScreen.main.bounds.height
            }
        }
    }
    
    private func songInfo(song: SongModel) -> some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 2) {
                    Text(song.title)
                        .animation(.none)
                        .lineLimit(1)
                    if song.explicit == true {
                        Image(systemName: "e.square.fill")
                            .animation(.none)
                    }
                }
                .font(.title3.bold())
                .foregroundColor(.primary)
                
                Text("\(song.album ?? "") • \(song.artist)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .animation(.none)
            }
            Spacer()
            Image(.appleMusic)
                .resizable()
                .scaledToFit()
                .frame(width: 33, height: 33)
                .padding(.leading)
                .onTapGesture {
                    if let url = URL(string: song.catalogURL) {
                        openURL(url)
                    }
                }
        }
        .opacity(opacity)
    }
}
