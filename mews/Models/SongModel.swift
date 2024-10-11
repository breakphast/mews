//
//  SongModel.swift
//  mews
//
//  Created by Desmond Fitch on 10/8/24.
//

import SwiftUI
import SwiftData
import MusicKit

@Model
class SongModel {
    var id: String = ""
    var title: String = ""
    var artist: String = ""
    var artwork: String = ""
    var previewURL: String = ""
    var catalogURL: String = ""
    var isCatalog: Bool
    var liked: Bool? = nil
    var usedForSeed = false
    
    init(song: Song, isCatalog: Bool) {
        id = song.id.rawValue
        title = song.title
        artist = song.artistName
        artwork = song.artwork?.url(width: 600, height: 600)?.absoluteString ?? ""
        catalogURL = song.url?.absoluteString ?? ""
        previewURL = song.previewAssets?.first?.url?.absoluteString ?? ""
        self.isCatalog = isCatalog
    }
}

enum SongModelFilter: CaseIterable {
    case library
    case usedLibrary
    case unusedLibrary
    case recommended
    case likedRecommended
    case dislikedRecommended
    case unusedRecommended
}
