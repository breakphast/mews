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
    @Environment(\.openURL) var openURL
    
    var appleSong: Song? {
        return spotifyService.recommendedSongs?.randomElement()
    }
    
    var body: some View {
        VStack {
            if let appleSong {
                Text("\(appleSong.title) - \(appleSong.artistName)")
            } else {
                Text("No recommended songs yet.")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
