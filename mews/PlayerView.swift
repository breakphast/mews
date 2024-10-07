//
//  PlayerView.swift
//  mews
//
//  Created by Desmond Fitch on 10/7/24.
//

import SwiftUI
import MusicKit

struct PlayerView: View {
    @Environment(PlayerViewModel.self) var playerViewModel
    @Environment(LibraryService.self) var libraryService
    @ObservedObject private var playerState = ApplicationMusicPlayer.shared.state
    
    var song: Song? {
        guard let item = playerViewModel.queue.currentEntry?.item else { return nil }
        
        switch item {
        case .song(let song):
            return song
        default:
            return nil
        }
    }
    
    private var isPlaying: Bool {
        return playerState.playbackStatus == .playing
    }
    
    var body: some View {
        VStack(spacing: 16) {
            albumElement
            
            VStack(alignment: .leading) {
                Text(song?.title ?? "")
                Text(song?.artistName ?? "")
            }
            .font(.title3)
            .fontWeight(.semibold)
                        
            Button("\(isPlaying ? "Pause" : "Play")\(isPlaying ? "⏸" : "▶")") {
                Task {
                    isPlaying ? playerViewModel.player.pause() : try await playerViewModel.player.play()
                }
            }
            .font(.title.bold())
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .padding(.top)
            
            Button("NEXT") {
                Task {
                    try await playerViewModel.player.skipToNextEntry()
                }
            }
            .font(.title.bold())
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top)
        }
    }
    
    private var albumElement: some View {
        VStack(spacing: 40) {
            if let artwork = song?.artwork {
                ArtworkImage(artwork, width: UIScreen.main.bounds.width * 0.75)
                    .clipShape(.rect(cornerRadius: 24, style: .continuous))
                    .shadow(radius: 5)
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .frame(width: UIScreen.main.bounds.width, height: 200)
                    .shadow(radius: 5)
            }
        }
    }
}

#Preview {
    PlayerView()
}
