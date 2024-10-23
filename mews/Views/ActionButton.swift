//
//  ActionButton.swift
//  mews
//
//  Created by Desmond Fitch on 10/23/24.
//

import SwiftUI
import SwiftData

struct ActionButton: View {
    @Environment(PlayerViewModel.self) var playerViewModel
    @Environment(LibraryService.self) var libraryService
    @Environment(CustomFilterService.self) var customFilterService
    @Environment(\.colorScheme) var colorScheme
    
    var liked: Bool? = nil
    let size = Helpers.actionButtonSize
    
    var customFilter: CustomFilterModel? {
        customFilterService.customFilterModel
    }
    
    var activeSongs: [SongModel] {
        customFilter?.active == true && !(customFilter?.songs.isEmpty ?? true) ? customFilter!.songs : libraryService.songModelManager.recSongs
    }
    
    var body: some View {
        if liked == nil {
            customFilterButton()
                .disabled(playerViewModel.buttonDisabled)
                .sensoryFeedback(.impact(weight: .light), trigger: playerViewModel.haptic)
        } else if let liked {
            selectionButton(liked)
                .disabled(playerViewModel.buttonDisabled)
                .sensoryFeedback(.impact(weight: liked ? .heavy : .light), trigger: playerViewModel.haptic)
        }
    }
    
    private func selectionButton(_ liked: Bool) -> some View {
        Button {
            playerViewModel.haptic.toggle()
            Task { @MainActor in
                playerViewModel.opacity = 0
                playerViewModel.switchingSongs = true
                
                #if !targetEnvironment(simulator)
                let playlist = await LibraryService.getPlaylist(libraryService.activePlaylist)
                #else
                let playlist: Playlist? = nil
                #endif
                                
                if liked { triggerToast() }
                
                if let song = playerViewModel.currentSong {
                    try await libraryService.songModelManager.deleteSongModel(songModel: song)
                    try await libraryService.songModelManager.fetchItems()
                }
                
                try await playerViewModel.swipeAction(
                    liked: liked,
                    recSongs: activeSongs,
                    playlist: playlist
                )
            }
        } label: {
            Image(systemName: liked ? "heart.fill" : "xmark")
                .font(.largeTitle)
                .foregroundStyle(.white)
                .padding()
                .background {
                    Circle()
                        .fill((liked ? Color.appleMusic : .gray).opacity(0.8))
                        .frame(width: size, height: size)
                        .overlay {
                            Circle()
                                .stroke((liked ? Color.appleMusic : .gray).opacity(0.8), lineWidth: 2)
                                .frame(width: size, height: size)
                        }
                        .shadow(color: .snow.opacity(colorScheme == .light ? 0.2 : 0.05), radius: 6, x: 2, y: 4)
                }
        }
    }
    
    private func customFilterButton() -> some View {
        Button {
            playerViewModel.haptic.toggle()
            if let customFilter {
                if !customFilter.active {
                    if customFilter.songs.isEmpty {
                        triggerFilters()
                    } else {
                        customFilter.active = true
                        advanceWithCustomSongs(customFilter)
                    }
                } else {
                    customFilter.active = false
                    advanceWithCustomSongs(customFilter)
                }
            } else {
                assignNewFilter()
            }
        } label: {
            Image(systemName: "wand.and.stars")
                .font(.largeTitle)
                .foregroundStyle(.appleMusic)
                .grayscale((customFilter?.active ?? false) ? 0 : 1)
                .padding()
                .background {
                    Circle()
                        .fill(.white.opacity((customFilter?.active ?? false) ? 1 : 0.8))
                        .frame(width: size, height: size)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity((customFilter?.active ?? false) ? 1 : 0.8), lineWidth: 2)
                                .frame(width: size, height: size)
                        }
                        .shadow(color: .snow.opacity(colorScheme == .light ? 0.3 : 0.05), radius: 6, x: 2, y: 4)
                }
        }
    }
    
    private func advanceWithCustomSongs(_ customFilter: CustomFilterModel) {
        Task {
            try await playerViewModel.swipeAction(liked: nil, recSongs: activeSongs)
//            withAnimation(.bouncy.speed(0.5)) {
//                customFilter.active = true
//            }
        }
    }
    
    private func assignNewFilter() {
        let customFilterModel = CustomFilterModel()
        Task {
            try await customFilterService.persistCustomFilter(customFilterModel)
            try await customFilterService.fetchCustomFilter()
            triggerFilters()
        }
    }
    
    private func triggerToast() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.bouncy) {
                playerViewModel.showToast = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.smooth) {
                playerViewModel.showToast = false
            }
        }
    }
    
    private func triggerFilters() {
        withAnimation(.bouncy.speed(0.5)) {
            playerViewModel.showFilters.toggle()
            return
        }
    }
}

//#Preview {
//    ActionButton()
//}
