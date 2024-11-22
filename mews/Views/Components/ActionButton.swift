//
//  ActionButton.swift
//  mews
//
//  Created by Desmond Fitch on 10/23/24.
//

import SwiftUI
import SwiftData
import MusicKit
import StoreKit

struct ActionButton: View {
    @Environment(PlayerViewModel.self) var playerViewModel
    @Environment(LibraryService.self) var libraryService
    @Environment(CustomFilterService.self) var customFilterService
    @Environment(SubscriptionService.self) var subscriptionService
    @Environment(\.colorScheme) var colorScheme
    @Binding var show: Bool
    @Binding var currentSpot: Int
    
    var liked: Bool? = nil
    let size = Helpers.actionButtonSize
    
    var customFilter: CustomFilterModel? {
        customFilterService.customFilterModel
    }
    
    var activeSongs: [SongModel] {
        customFilterService.active == true && !(customFilter?.songs.isEmpty ?? true) ? customFilter!.songs : libraryService.songModelManager.recSongs
    }
    
    var body: some View {
        if liked == nil {
            customFilterButton()
                .disabled(playerViewModel.buttonDisabled)
        } else if let liked {
            selectionButton(liked)
                .disabled(playerViewModel.buttonDisabled)
        }
    }
    
    private func selectionButton(_ liked: Bool) -> some View {
        Button {
            guard !playerViewModel.browseLimitReached else {
                Task { @MainActor in
                    if await tryResetSongsBrowsed() == true {
                        selectionAction(liked: liked)
                    } else {
                        playerViewModel.limitedSongID = playerViewModel.currentSong?.id ?? ""
                        Helpers.saveToUserDefaults(playerViewModel.limitedSongID, forKey: "limitedSongID")
                        
                        playerViewModel.triggerToast(type: .limitReached)
                        playerViewModel.showPaywall.toggle()
                    }
                }
                return
            }
            
            selectionAction(liked: liked)
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
    
    private func tryResetSongsBrowsed() async -> Bool {
        if let appleUserID = playerViewModel.appleUserID, let browsedCount = await APIService.fetchSongsBrowsed(for: appleUserID) {
            if browsedCount == 0 {
                playerViewModel.songsBrowsed = browsedCount
                playerViewModel.showLimitToast = false
                Helpers.deleteFromUserDefaults(forKey: "limitedSongID")
                print("Reset songs browsed")
                return true
            }
        }
        return false
    }
    
    private func selectionAction(liked: Bool) {
        Task { @MainActor in
            if currentSpot == 1 || currentSpot == 0 {
                currentSpot += 1
            } else if currentSpot == 2 {
                Helpers.saveToUserDefaults("false", forKey: "firstTime")
                show = false
            }
            playerViewModel.opacity = 0
            playerViewModel.switchingSongs = true

            if let song = playerViewModel.currentSong {
                try await libraryService.songModelManager.deleteSongModel(songModel: song)
                try await libraryService.songModelManager.fetchItems()
            }
            try await playerViewModel.swipeAction(
                liked: liked,
                recSongs: activeSongs,
                playlist: libraryService.activePlaylist,
                limit: customFilter == nil
            )

            if liked { playerViewModel.triggerToast(type: .addedToLibrary) }
            
            if customFilter?.songs == [] {
                customFilterService.active = false
            }
        }
    }
    
    private func customFilterButton() -> some View {
        Button {
            guard subscriptionService.isSubscriptionActive || customFilter != nil else {
                playerViewModel.showPaywall.toggle()
                return
            }
            
            if let customFilter {
                if !customFilterService.active {
                    if customFilter.songs.isEmpty {
                        playerViewModel.triggerFilters()
                    } else {
                        customFilterService.active = true
                        advanceWithCustomSongs(customFilter)
                    }
                } else {
                    customFilterService.active = false
                    advanceWithCustomSongs(customFilter)
                }
            }
        } label: {
            Image(systemName: "wand.and.stars")
                .font(.largeTitle)
                .foregroundStyle(.appleMusic)
                .grayscale(customFilterService.active ? 0 : 1)
                .padding()
                .background {
                    Circle()
                        .fill(.white.opacity(customFilterService.active ? 1 : 0.8))
                        .frame(width: size, height: size)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(customFilterService.active ? 1 : 0.8), lineWidth: 2)
                                .frame(width: size, height: size)
                        }
                        .shadow(color: .snow.opacity(colorScheme == .light ? 0.3 : 0.05), radius: 6, x: 2, y: 4)
                }
        }
    }
    
    private func advanceWithCustomSongs(_ customFilter: CustomFilterModel) {
        Task {
            try await playerViewModel.swipeAction(liked: nil, recSongs: activeSongs, limit: false)
        }
    }
    
    private func assignNewFilter() {
        let customFilterModel = CustomFilterModel()
        Task {
            try await customFilterService.persistCustomFilter(customFilterModel)
            try await customFilterService.fetchCustomFilter()
            playerViewModel.triggerFilters()
        }
    }    
}

//#Preview {
//    ActionButton()
//}
