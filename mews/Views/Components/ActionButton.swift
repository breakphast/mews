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
    @Environment(\.colorScheme) var colorScheme
    
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
                playerViewModel.triggerToast(type: .limitReached)
                return
            }
            
            Task { @MainActor in
                playerViewModel.opacity = 0
                playerViewModel.switchingSongs = true
                
                #if !targetEnvironment(simulator)
                let playlist = await LibraryService.getPlaylist(libraryService.activePlaylist)
                #else
                let playlist: Playlist? = nil
                #endif
                                
                if let song = playerViewModel.currentSong {
                    try await libraryService.songModelManager.deleteSongModel(songModel: song)
                    try await libraryService.songModelManager.fetchItems()
                }
                
                try await playerViewModel.swipeAction(
                    liked: liked,
                    recSongs: activeSongs,
                    playlist: playlist,
                    limit: customFilter == nil
                )
                
                if customFilter?.songs == [] {
                    customFilterService.active = false
                }
                
                if liked { playerViewModel.triggerToast(type: .addedToLibrary) }
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
            Task { await checkSubscriptionStatus() }
            
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
            } else {
                playerViewModel.showStore.toggle()
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
    
    func checkSubscriptionStatus() async -> Bool {
        do {
            let products = try await Product.products(for: ["discomuse.monthly"])
            guard let subscriptionProduct = products.first else { return false }
            
            let status = try await subscriptionProduct.subscription?.status.first
            
            if let state = status?.state {
                if state == .subscribed {
                    print("Subscription active.")
                    return true
                }
            }
        } catch {
            print("Error fetching subscription status: \(error)")
        }
        print("Failed to fetch subscription status.")
        if let _ = customFilterService.customFilterModel {
            try? await customFilterService.deleteCustomFilter(customFilterService.customFilterModel!)
            customFilterService.customFilterModel = nil
            customFilterService.active = false
            try? await playerViewModel.swipeAction(liked: nil, recSongs: activeSongs, limit: customFilter == nil)
        }
        
        return false
    }
}

//#Preview {
//    ActionButton()
//}
