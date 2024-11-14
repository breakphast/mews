//
//  PlayerView.swift
//  mews
//
//  Created by Desmond Fitch on 10/7/24.
//

import SwiftUI
import MusicKit
import SwiftData
import AVFoundation

struct PlayerView: View {
    @Environment(AuthService.self) var authService
    @Environment(LibraryService.self) var libraryService
    @Environment(SpotifyService.self) var spotifyService
    @Environment(CustomFilterService.self) var customFilterService
    @Environment(SubscriptionService.self) var subscriptionService
    @Environment(\.colorScheme) var colorScheme
    @Bindable var playerViewModel: PlayerViewModel
    
    private var songModelManager: SongModelManager { libraryService.songModelManager }
    private var customFilter: CustomFilterModel? { customFilterService.customFilterModel }
    
    private var accessGranted: Bool {
        authService.status == .authorized
    }
    
    var body: some View {
        ZStack {
            Color.oreo.ignoresSafeArea()
            
            VStack(spacing: 24) {
                if customFilterService.customFetchingActive, !customFilterService.lowRecsActive {
                    customRecsSplash
                } else {
                    if playerViewModel.initialLoad && authService.status == .authorized {
                        navBar
                        Spacer()
                        if playerViewModel.currentSong != nil {
                            SongView(opacity: $playerViewModel.opacity, show: $playerViewModel.showSpotlight, currentSpot: $playerViewModel.currentSpot)
                            Spacer()
                        }
                        buttons
                    } else {
                        progressView
                            .padding(.horizontal, 48)
                    }
                }
            }
            .padding()
            .task {
                assignNewBucketSong()
            }
            .onChange(of: songModelManager.recSongs.count) { _, newCount in
                guard newCount <= 15 else { return }
                if customFilterService.lowRecsActive || customFilterService.customFetchingActive {
                    return
                }
                if !spotifyService.fetchingActive {
                    lowRecsTrigger()
                }
            }
            .onChange(of: customFilter?.songs.count) { _, songCount in
                guard let songCount, songCount <= 15 else { return }
                if !customFilterService.customFetchingActive, !customFilterService.lowRecsActive {
                    Task {
                        await customFilterService.lowCustomRecsTrigger()
                        customFilterService.lowRecsActive = false
                    }
                }
            }
            .sheet(isPresented: $playerViewModel.showFilters) {
                if let customFilter {
                    CustomFilterView(filter: customFilter)
                }
            }
            .fullScreenCover(isPresented: $playerViewModel.showSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $playerViewModel.showPaywall) {
                Paywall()
            }
        }
        .task {
            try? await mainInit()
        }
        .overlay {
            if playerViewModel.showAddedToast {
                ToastView(type: .addedToLibrary)
                    .transition(.move(edge: .top))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .overlay {
            if playerViewModel.showLimitToast {
                ToastView(type: .limitReached)
                    .transition(.move(edge: .top))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .overlay {
            if !accessGranted {
                ZStack {
                    Color.oreo.ignoresSafeArea()
                    Text("You must grant DiscoMuse access to your Media Library to continue")
                        .multilineTextAlignment(.center)
                        .bold()
                        .padding(.horizontal, 40)
                }
            }
        }
        .addSpotlightOverlay(show: $playerViewModel.showSpotlight, currentSpot: $playerViewModel.currentSpot)
    }
    
    private var customRecsSplash: some View {
        Image(systemName: "wand.and.stars")
            .resizable()
            .scaledToFit()
            .frame(width: playerViewModel.scale, height: playerViewModel.scale)
            .foregroundStyle(.appleMusic)
            .onAppear {
                withAnimation(.bouncy(extraBounce: 0.1).repeatForever(autoreverses: true)) {
                    playerViewModel.scale = 200
                }
            }
            .onDisappear {
                playerViewModel.scale = 50
            }
    }
    private var progressView: some View {
        VStack(spacing: 16) {
            Text(playerViewModel.progressMessage)
                .bold()
                .foregroundStyle(.snow.opacity(0.9))
                .fontDesign(.rounded)
            
            ProgressView(value: playerViewModel.progress)
                .tint(.appleMusic.opacity(0.9))
        }
    }
    private var inactiveOverlay: some View {
        ZStack {
            Color.oreo.ignoresSafeArea()
            
            Text("Inactive Apple Music subscription!\nPlease subscribe to continue.")
                .multilineTextAlignment(.center)
                .bold()
                .padding(.horizontal)
        }
        .fontDesign(.rounded)
    }
    
    private func assignNewBucketSong() {
        withAnimation {
            playerViewModel.image = nil
        }
        let songs = customFilterService.active == true && !(customFilter?.songs.isEmpty ?? true) ? customFilter!.songs : songModelManager.recSongs

        if let song = songs.randomElement() {
            Task {
                if albumImage == nil {
                    await playerViewModel.assignPlayerSong(song: song)
                }
            }
        }
    }
    
    // MARK: - Functions
    
    private func lowRecsTrigger() {
        Task {
            await
            spotifyService.lowRecsTrigger(
                songs: songModelManager.savedLibrarySongs,
                recSongs: songModelManager.recSongs,
                dislikedSongs: songModelManager.savedDeletedSongs?.map { $0.url } ?? []
            )
            
            try await songModelManager.fetchItems()
        }
    }
    
    private var navBar: some View {
        HStack {
            Image(systemName: "slider.horizontal.2.square")
                .font(.largeTitle)
                .foregroundStyle(customFilter == nil ? .gray : .snow)
                .onTapGesture {
                    guard customFilter != nil else {
                        playerViewModel.showPaywall.toggle()
                        return
                    }
                    withAnimation(.bouncy) {
                        playerViewModel.showFilters.toggle()
                    }
                }
            Spacer()
            Text("DiscoMuse\(customFilter == nil ? "" : " PRO")")
                .font(.title)
                .fontWeight(.heavy)
                .foregroundStyle(.appleMusic.opacity(0.8))
                .kerning(0.2)
            Spacer()
            Image(systemName: "gear.circle")
                .font(.largeTitle)
                .foregroundStyle(.snow)
                .onTapGesture {
                    withAnimation {
                        playerViewModel.showSettings.toggle()
                    }
                }
        }
        .padding(.horizontal, 4)
        .fontDesign(.rounded)
    }
    
    // MARK: - View Properties
    
    var albumImage: UIImage? {
        return playerViewModel.image
    }
    private var buttons: some View {
        HStack {
            ActionButton(show: $playerViewModel.showSpotlight, currentSpot: $playerViewModel.currentSpot, liked: false)
                .addSpotlight(2, shape: .circle, roundedRadius: 0, text: "Tap to skip")
            Spacer()
            ActionButton(show: $playerViewModel.showSpotlight, currentSpot: $playerViewModel.currentSpot)
            .offset(y: -16)
            Spacer()
            ActionButton(show: $playerViewModel.showSpotlight, currentSpot: $playerViewModel.currentSpot, liked: true)
                .addSpotlight(1, shape: .circle, roundedRadius: 0, text: "Tap to like/add to library")
        }
        .bold()
        .padding()
    }
    
    private func mainInit() async throws {
        do {
            if authService.status != .authorized { await authService.authorizeAction() }
            if !subscriptionService.isSubscriptionActive {
                customFilterService.customFilterModel = nil
            }
            playerViewModel.appleUserID = authService.appleUserID
            if customFilterService.customFilterModel == nil {
                if let userID = authService.appleUserID {
                    playerViewModel.songsBrowsed = await APIService.fetchSongsBrowsed(for: userID) ?? 0
                    if playerViewModel.browseLimitReached {
                        playerViewModel.triggerToast(type: .limitReached)
                    }
                }
            }
            if authService.activeSubscription == nil || customFilter == nil {
                libraryService.activePlaylist = nil
            } else if authService.activeSubscription != nil {
                await libraryService.getPlaylist()
            }
            try await playerViewModel.authorizeAndFetch(
                libraryService: libraryService,
                spotifyService: spotifyService
            )
        } catch {
            print("Unable to authorize: \(error.localizedDescription)")
        }
    }
}
