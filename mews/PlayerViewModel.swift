//
//  PlayerViewModel.swift
//  mews
//
//  Created by Desmond Fitch on 10/7/24.
//

import SwiftUI
import MusicKit
import Observation

@MainActor
@Observable
final class PlayerViewModel {
    let player = ApplicationMusicPlayer.shared
    let queue = ApplicationMusicPlayer.shared.queue
    var playerState = ApplicationMusicPlayer.shared.state
    var isPlaying: Bool { return playerState.playbackStatus == .playing }
}
