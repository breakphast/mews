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
    var isCatalog: Bool
    var liked: Bool? = nil
    var usedForSeed = false
    
    init(song: Song, isCatalog: Bool) {
        id = song.id.rawValue
        title = song.title
        artist = song.artistName
        artwork = song.artwork?.url(width: 600, height: 600)?.absoluteString ?? ""
        previewURL = song.previewAssets?.first?.url?.absoluteString ?? ""
        self.isCatalog = isCatalog
    }
}
