//
//  MediaControls.swift
//  mews
//
//  Created by Desmond Fitch on 10/14/24.
//

import MediaPlayer

@Observable
class ControlsService {
    let playerViewModel: PlayerViewModel
    var unusedRecSongs: [SongModel]
    
    init(_ playerViewModel: PlayerViewModel, recSongs: [SongModel]) {
        self.playerViewModel = playerViewModel
        self.unusedRecSongs = recSongs
        setupRemoteCommandCenter()
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
//        commandCenter.nextTrackCommand.addTarget { [weak self] event in
//            Task {
//                try? await self?.playerViewModel.swipeAction(liked: true, unusedRecSongs: self?.unusedRecSongs ?? [])
//            }
//            return .success
//        }
//        
//        commandCenter.previousTrackCommand.addTarget { [weak self] event in
//            Task {
//                try? await self?.playerViewModel.swipeAction(liked: false, unusedRecSongs: self?.unusedRecSongs ?? [])
//            }
//            return .success
//        }
//        
//        commandCenter.playCommand.addTarget { [weak self] event in
//            Task { @MainActor in
//                self?.playerViewModel.play()
//            }
//            return .success
//        }
//        
//        commandCenter.pauseCommand.addTarget { [weak self] event in
//            Task { @MainActor in
//                self?.playerViewModel.pauseAvPlayer()
//            }
//            return .success
//        }
        
        
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
    }
}
