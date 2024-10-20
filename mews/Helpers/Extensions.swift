//
//  Extensions.swift
//  mews
//
//  Created by Desmond Fitch on 10/11/24.
//

import SwiftUI

extension Array where Element == SongModel {
    var library: [SongModel] {
        filter { $0.isCatalog && !$0.custom }
    }
    
    var recommended: [SongModel] {
        filter { !$0.isCatalog && !$0.custom }
    }
    
    var likedRecommended: [SongModel] {
        filter { !$0.isCatalog && $0.liked == true && !$0.custom }
    }
    
    var unusedRecommended: [SongModel] {
        filter { !$0.isCatalog && $0.liked == nil && !$0.custom }
    }
    
    var customRecommended: [SongModel] {
        filter { !$0.isCatalog && $0.custom }
    }
    
    func filtered(by filter: SongModelFilter) -> [SongModel] {
        switch filter {
        case .library:
            library
        case .recommended:
            recommended
        case .likedRecommended:
            likedRecommended
        case .unusedRecommended:
            unusedRecommended
        case .customRecommended:
            customRecommended
        }
    }
}

extension View {
    func onOrientationChange(isLandscape: Binding<Bool>) -> some View {
        self.modifier(OrientationChangeModifier(isLandscape: isLandscape))
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
