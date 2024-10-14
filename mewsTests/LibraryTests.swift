//
//  LibraryTests.swift
//  mewsTests
//
//  Created by Desmond Fitch on 10/11/24.
//

import Testing
import SwiftUI
import MusicKit
import SwiftData
@testable import mews

final class LibraryTests {
    let libraryService = LibraryService()
    
    #if !targetEnvironment(simulator)
    @Test func getSongsFromLibrary() async throws {
        if let songs = try await libraryService.fetchLibrarySongs(),
           let songURL = songs.first?.artwork?.url(width: 50, height: 50) {
            #expect(!songs.isEmpty)
            #expect(songs.compactMap { $0.playCount }.isEmpty)
            
            let albumImage = await libraryService.fetchArtwork(from: songURL)
            #expect(albumImage != nil)
        }
    }
    #endif
}
