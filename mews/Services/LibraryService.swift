//
//  LibraryService.swift
//  mews
//
//  Created by Desmond Fitch on 10/7/24.
//

import SwiftUI
import MusicKit
import Observation
import SwiftData

@Observable
class LibraryService {
    var songs = [Song]()
    var playlists = [Playlist]()
    
    var recommendedSong: Song?
    var avSong: Song?
    var avSongURL: URL?
    var catalogSongs = [Song]()
    
    let spotifyService = SpotifyService()
    
    func fetchSongs() async throws {
        var libraryRequest = MusicLibraryRequest<Song>()
        libraryRequest.limit = 50
        
        do {
            let libraryResponse = try await libraryRequest.response()
            songs = Array(libraryResponse.items.filter { $0.artwork != nil })
            
            if let song = songs.first, let catalogSong = await spotifyService.fetchCatalogSong(title: song.title, artist: song.artistName) {
                avSong = catalogSong
            }
            for song in songs {
                if let catalogSong = await spotifyService.fetchCatalogSong(title: song.title, artist: song.artistName) {
                    catalogSongs.append(catalogSong)
                }
            }
            try await persistSongModels(songs: Array(catalogSongs), isCatalog: true)
        }
    }
    
    func fetchPlaylists() async throws {
        let libraryRequest = MusicLibraryRequest<Playlist>()
        
        do {
            let libraryResponse = try await libraryRequest.response()
            self.playlists = Array(libraryResponse.items)
        } catch {
            print("No playlists found")
        }
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
}
  
