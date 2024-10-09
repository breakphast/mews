//
//  SongModelManager.swift
//  mews
//
//  Created by Desmond Fitch on 10/8/24.
//

import SwiftUI
import SwiftData

@Observable
class SongModelManager {
    var savedSongs = [SongModel]()
    
    var savedLibrarySongs: [SongModel] {
        savedSongs.filter { $0.isCatalog }
    }
    
    var usedLibrarySongs: [SongModel] {
        savedLibrarySongs.filter { $0.usedForSeed == true }
    }
    
    var unusedLibrarySongs: [SongModel] {
        savedLibrarySongs.filter { $0.usedForSeed == false }
    }
    
    var savedRecSongs: [SongModel] {
        savedSongs.filter { !$0.isCatalog }
    }
    
    var likedRecSongs: [SongModel] {
        savedRecSongs.filter { $0.liked == true }
    }
    
    var dislikedRecSongs: [SongModel] {
        savedRecSongs.filter { $0.liked == false }
    }
    
    var unusedRecSongs: [SongModel] {
        savedRecSongs.filter { $0.liked == nil }
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
}
