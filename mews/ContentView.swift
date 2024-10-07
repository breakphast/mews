//
//  ContentView.swift
//  mews
//
//  Created by Desmond Fitch on 10/4/24.
//

import SwiftUI
import MusicKit

struct ContentView: View {
    @Environment(AuthService.self) var authService
    @Environment(LibraryService.self) var libraryService
    @Environment(SpotifyService.self) var spotifyService
    @Environment(PlayerViewModel.self) var playerViewModel
    @Environment(\.openURL) var openURL
    
    private var song: Song? {
        return spotifyService.recommendedSongs?.randomElement()
    }
    
    var body: some View {
        VStack {
            PlayerView()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
