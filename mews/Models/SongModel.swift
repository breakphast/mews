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
    var album: String? = ""
    var artwork: String = ""
    var genre: String? = ""
    var previewURL: String = ""
    var catalogURL: String = ""
    var isCatalog: Bool
    var liked: Bool? = nil
    var recSong: String = ""
    var explicit: Bool? = nil
    var custom: Bool = false
    
    init(song: Song, isCatalog: Bool) {
        id = song.id.rawValue
        title = song.title
        artist = song.artistName
        album = song.albumTitle
        artwork = song.artwork?.url(width: 600, height: 600)?.absoluteString ?? ""
        genre = song.genres?.first?.name
        catalogURL = song.url?.absoluteString ?? ""
        previewURL = song.previewAssets?.first?.url?.absoluteString ?? ""
        explicit = song.contentRating == .explicit
        self.isCatalog = isCatalog
    }
}

enum SongModelFilter: CaseIterable {
    case library
    case recommended
    case likedRecommended
    case unusedRecommended
    case customRecommended
}
