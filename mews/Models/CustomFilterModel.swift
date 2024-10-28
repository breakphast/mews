//
//  CustomFilterModel.swift
//  mews
//
//  Created by Desmond Fitch on 10/23/24.
//

import SwiftUI
import MusicKit
import SwiftData

@Model
class CustomFilterModel: Identifiable {
    var id: String = UUID().uuidString
    
    @Relationship(deleteRule: .cascade, inverse: \SongModel.customFilter)
    var songs: [SongModel] = []
    var artists = [String: String]()
    var genreSeeds = [String]()
    var playlistSeed: String?
    var activeSeedOption: String = SeedOption.artist.rawValue
    var activeSeeds: [String] {
        artists.map { $0.value } + genreSeeds
    }
    
    init() {}
}
