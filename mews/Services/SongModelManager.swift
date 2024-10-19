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
    var savedSongs = [SongModel]()
    
    var savedLibrarySongs: [SongModel] { savedSongs.library }
    var savedRecSongs: [SongModel] { savedSongs.recommended }
    var likedRecSongs: [SongModel] { savedRecSongs.likedRecommended }
    var unusedRecSongs: [SongModel] { savedRecSongs.unusedRecommended }
    
    var customFilter: CustomFilter?
    var customFilterSongs: [SongModel] { savedSongs.customRecommended }
    
    var savedDeletedSongs: [(title: String, url: String)]?
    
    init() {
        savedDeletedSongs = getDeletedSongs()
    }
    
    @MainActor
    func deleteSongModel(songModel: SongModel) async throws {
        let context = Helpers.container.mainContext
        
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
    }
    
    @MainActor
    func deleteSongModels(songModels: [SongModel]) async throws {
        let context = Helpers.container.mainContext

        for songModel in songModels {
            context.delete(songModel)
        }

        do {
            try context.save()
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
