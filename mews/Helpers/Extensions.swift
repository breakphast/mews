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

struct Genres {
    static let genres: [String] = [
        "Alternative",
        "Ambient",
        "Bluegrass",
        "Classical",
        "Country",
        "Dance",
        "Drum & Bass",
        "Dubstep",
        "Electronic",
        "Folk",
        "Hip-Hop/Rap",
        "House",
        "Indie Pop",
        "Jazz",
        "K-Pop",
        "Latin",
        "Lo-Fi",
        "Metal",
        "New Age",
        "Pop",
        "Punk",
        "R&B/Soul",
        "Reggae",
        "Rock",
        "Soundtrack",
        "Techno",
        "Trap",
        "World"
    ]
}
