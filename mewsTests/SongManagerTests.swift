//
//  SongManagerTests.swift
//  mewsTests
//
//  Created by Desmond Fitch on 10/11/24.
//

import Testing
import SwiftUI
import MusicKit
import SwiftData
@testable import mews

let manager = SongModelManager()

class SongManagerTests {
    @Test(
        "Filter songs from Swift Data into categories",
        .enabled(if: !manager.savedSongs.isEmpty),
        arguments: SongModelFilter.allCases
    )
    func filterSongs(_ filter: SongModelFilter) {
        let filteredSongs = manager.savedSongs.filtered(by: filter)
        
        switch filter {
        case .library:
            #expect(!filteredSongs.contains(where: { !$0.isCatalog }))
        case .recommended:
            #expect(!filteredSongs.contains(where: { $0.isCatalog }))
        default:
            #expect(true)
        }
    }
}
