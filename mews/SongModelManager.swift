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
    
    var savedLibrarySongs: [SongModel] { return savedSongs.filter { $0.isCatalog } }
    var usedLibrarySongs: [SongModel] { return savedLibrarySongs.filter { $0.usedForSeed == true } }
    var unusedLibrarySongs: [SongModel] {
        let songs = savedLibrarySongs.filter { $0.usedForSeed == false }
        print(songs.count, "Unused Library Songs Remaining")
        return songs
    }
    
    var savedRecSongs: [SongModel] { return savedSongs.filter { !$0.isCatalog } }
    var likedRecSongs: [SongModel] { savedRecSongs.filter { $0.liked == true } }
    var dislikedRecSongs: [SongModel] { savedRecSongs.filter { $0.liked == false } }
    var unusedRecSongs: [SongModel] {
        let songs = savedRecSongs.filter { $0.liked == nil }
        print(songs.count, "Unused Rec Songs Remaining")
        return songs
    }
    
    init() {
        Task {
            try await fetchItems()
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
    
    func persistSongModels(songs: [Song], isCatalog: Bool) async throws {
        let context = ModelContext(try ModelContainer(for: SongModel.self))
        
        for song in songs {
            let songModel = (SongModel(song: song, isCatalog: isCatalog))
            context.insert(songModel)
        }
        
        do {
            try context.save()
            print("Successfuly persisted \(songs.count) songs", isCatalog)
        } catch {
            print("Could not persist songs")
        }
    }
    
    func deleteSongModel(songModel: SongModel) async throws {
        let context = ModelContext(try ModelContainer(for: SongModel.self))
        context.delete(songModel)
    }
}
