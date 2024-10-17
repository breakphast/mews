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
        .enabled(if: !songManager.savedRecSongs.isEmpty)
    )
    func assignSong() async {
        if let song = songManager.savedRecSongs.first, let url = URL(string: song.catalogURL) {
            let item = AVPlayerItem(url: url)
            await playerViewModel.assignPlayerSong(item: item, song: song)
            #expect(playerViewModel.currentSong == song)
        }
    }
    
    @Test("Like or Dislike Song", .enabled(if: !songManager.savedRecSongs.isEmpty), arguments: [true, false])
    func swipeSong(_ like: Bool) async {
        guard let song = (like ? songManager.savedRecSongs.first : songManager.savedRecSongs.last) else {
            return
        }
        
        if let url = URL(string: song.catalogURL) {
            let item = AVPlayerItem(url: url)
            await playerViewModel.assignPlayerSong(item: item, song: song)
            try? await playerViewModel.swipeAction(liked: like, unusedRecSongs: songManager.unusedRecSongs)
            guard let liked = song.liked else { return }
            
            #expect(liked == (like ? true : false))
        }
        
        if like {
            let songInLibrary = await SpotifyService().songInLibrary(songModel: song)
            #expect(songInLibrary)
        }
    }
}
