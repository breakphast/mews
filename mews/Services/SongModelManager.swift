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
    var usedLibrarySongs: [SongModel] { savedSongs.usedLibrary }
    var unusedLibrarySongs: [SongModel] { savedSongs.unusedLibrary }
    
    var savedRecSongs: [SongModel] { savedSongs.recommended }
    var likedRecSongs: [SongModel] { savedSongs.likedRecommended }
    var dislikedRecSongs: [SongModel] { savedSongs.dislikedRecommended }
    var unusedRecSongs: [SongModel] { savedSongs.unusedRecommended }
    
    var savedDislikedSongs: [(title: String, url: String)]?
    
    init() {
        Task {
            try await fetchItems()
            savedDislikedSongs = getDislikedSongs()
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
    
    func deleteSongModel(songModel: SongModel) async throws {
        let context = ModelContext(try ModelContainer(for: SongModel.self))
        context.delete(songModel)
        
        saveDislikedSong(title: songModel.title, url: songModel.catalogURL)
        savedDislikedSongs = getDislikedSongs()
    }
    
    func saveDislikedSong(title: String, url: String) {
        let songString = "\(title),\(url)"
        var dislikedSongs = UserDefaults.standard.stringArray(forKey: "dislikedSongs") ?? []
        dislikedSongs.append(songString)
        UserDefaults.standard.set(dislikedSongs, forKey: "dislikedSongs")
    }
    
    func getDislikedSongs() -> [(title: String, url: String)] {
        let dislikedSongs = UserDefaults.standard.stringArray(forKey: "dislikedSongs") ?? []
        return dislikedSongs.compactMap { entry in
            let components = entry.split(separator: ",", maxSplits: 1).map(String.init)
            guard components.count == 2 else { return nil }
            return (title: components[0], url: components[1])
        }
    }
}
