//
//  Helpers.swift
//  mews
//
//  Created by Desmond Fitch on 10/17/24.
//

import SwiftUI
import SwiftData

struct Helpers {
    static func fetchArtwork(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("Failed to load artwork: \(error.localizedDescription)")
            return nil
        }
    }
    
    static let container: ModelContainer = {
        do {
            let container = try ModelContainer(for: SongModel.self, CustomFilterModel.self)
            return container
        } catch {
            fatalError("Failed to create container: \(error)")
        }
    }()
    
    // Apple Music developer token
    static let developerToken = "eyJhbGciOiJFUzI1NiIsImtpZCI6IkY3NjNRQjQ4TUwiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJHOVJQWU1TMlBBIiwiaWF0IjoxNzI3OTkwNjI1LCJleHAiOjE3NDM1NDI2MjV9.PX9Zzu6CtlH52ieCZG7S_w-q6YnINJg6JL5mrYuJ7lSuMpOBBxR3mTxZ1wdGiDjdU-zEJ6qxB-rDk04PxiPdvQ"
    
    static let idiom = UIDevice.current.userInterfaceIdiom
    
    static let actionButtonSize = UIScreen.main.bounds.height * (Helpers.idiom == .pad ? 0.06 : 0.1)
}

struct OrientationChangeModifier: ViewModifier {
    @Binding var isLandscape: Bool
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .onAppear {
                    isLandscape = geometry.size.width > geometry.size.height
                }
                .onChange(of: geometry.size) { _, newSize in
                    isLandscape = newSize.width > newSize.height
                }
        }
    }
}

struct Genres {
    static let genres: [String: String] = [
        "Alternative": "alternative",
        "Ambient": "ambient",
        "Bluegrass": "bluegrass",
        "Classical": "classical",
        "Country": "country",
        "Dance": "dance",
        "Drum & Bass": "drum-and-bass",
        "Dubstep": "dubstep",
        "Electronic": "electronic",
        "Folk": "folk",
        "Hip-Hop/Rap": "hip-hop",
        "House": "house",
        "Indie Pop": "indie-pop",
        "Jazz": "jazz",
        "K-Pop": "k-pop",
        "Latin": "latin",
        "Lo-Fi": "lo-fi",
        "Metal": "metal",
        "New Age": "new-age",
        "Pop": "pop",
        "Punk": "punk",
        "R&B/Soul": "r-n-b",
        "Reggae": "reggae",
        "Rock": "rock",
        "Soundtrack": "soundtracks",
        "Techno": "techno",
        "Trap": "trap",
        "World": "world-music"
    ]
}
