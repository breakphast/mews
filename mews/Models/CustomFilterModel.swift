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
    var artistSeedID: String?
    var artistSeedName: String?
    var genreSeed: String?
    var playlistSeed: String?
    
    var active = false
    var activeSeed: String = SeedOption.artist.rawValue
    
    init() {
        
    }
}
