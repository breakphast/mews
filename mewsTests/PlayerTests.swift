//
//  PlayerTests.swift
//  mewsTests
//
//  Created by Desmond Fitch on 10/14/24.
//

import Testing
import SwiftUI
import AVFoundation
import SwiftData
import MusicKit
@testable import mews

@MainActor
let playerViewModel = PlayerViewModel()
let songManager = SongModelManager()

@MainActor
final class PlayerTests {
    @Test("Initialize AVPlayer") func avPlayerInit() {
        #expect(!playerViewModel.isAvPlaying)
    }
    
    @Test(
        "Assign song to AVPlayer",
        .enabled(if: !songManager.recSongs.isEmpty)
    )
    func assignSong() async {
        if let song = songManager.recSongs.first, let url = URL(string: song.catalogURL) {
            let item = AVPlayerItem(url: url)
            await playerViewModel.assignPlayerSong(item: item, song: song)
            #expect(playerViewModel.currentSong == song)
        }
    }    
}
