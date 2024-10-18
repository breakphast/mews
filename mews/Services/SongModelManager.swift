//
//  SongModelManager.swift
//  mews
//
//  Created by Desmond Fitch on 10/8/24.
//

import SwiftUI
import SwiftData
import MusicKit

@Observable
class SongModelManager {
    let spotifyService = SpotifyService()
    var accessToken: String?
    
    var savedSongs = [SongModel]()
    
    var savedLibrarySongs: [SongModel] { savedSongs.library }
    var savedRecSongs: [SongModel] { savedSongs.recommended }
    var likedRecSongs: [SongModel] { savedRecSongs.likedRecommended }
    var unusedRecSongs: [SongModel] { savedRecSongs.unusedRecommended }
    
    var customFilter: CustomFilter?
    var customFilterSongs: [SongModel] { savedSongs.customRecommended }
    
    var savedDeletedSongs: [(title: String, url: String)]?
    
    init() {
        Task {
            try await fetchItems()
            savedDeletedSongs = getDeletedSongs()
        }
    }
    
    let container: ModelContainer = {
        do {
            let container = try ModelContainer(for: SongModel.self)
            return container
        } catch {
            fatalError("Failed to create container: \(error)")
        }
    }()
    
    let descriptor = FetchDescriptor<SongModel>()
    
    @MainActor
    func fetchItems() async throws {
        let context = container.mainContext
        let items = try context.fetch(descriptor).filter { !$0.artwork.isEmpty }
        savedSongs = items
        return
    }
    
    @MainActor
    func deleteSongModel(songModel: SongModel) async throws {
        let context = container.mainContext
        
        saveDeletedSong(title: songModel.title, url: songModel.catalogURL)
        
        context.delete(songModel)
        
        do {
            try context.save()
            print("Successfully deleted song model.")
        } catch {
            print("Failed to delete song model:", error)
            throw error
        }

        savedDeletedSongs = getDeletedSongs()
        try await fetchItems()
    }
    
    @MainActor
    func deleteSongModels(songModels: [SongModel]) async throws {
        let context = container.mainContext

        for songModel in songModels {
            context.delete(songModel)
        }

        do {
            try context.save()
            try await fetchItems()
        } catch {
            print("Failed to delete songs:", error)
        }
    }
    
    func saveDeletedSong(title: String, url: String) {
        let songString = "\(title),\(url)"
        var deletedSongs = UserDefaults.standard.stringArray(forKey: "deletedSongs") ?? []
        deletedSongs.append(songString)
        UserDefaults.standard.set(deletedSongs, forKey: "deletedSongs")
    }
    
    func getDeletedSongs() -> [(title: String, url: String)] {
        let dislikedSongs = UserDefaults.standard.stringArray(forKey: "deletedSongs") ?? []
        return dislikedSongs.compactMap { entry in
            let components = entry.split(separator: ",", maxSplits: 1).map(String.init)
            guard components.count == 2 else { return nil }
            return (title: components[0], url: components[1])
        }
    }
}
