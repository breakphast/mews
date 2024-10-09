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
    
    let spotifyService = SpotifyService()
    
    func fetchSongs() async throws -> [Song]? {
        var libraryRequest = MusicLibraryRequest<Song>()
        libraryRequest.limit = 50
        
        do {
            let libraryResponse = try await libraryRequest.response()
            songs = Array(libraryResponse.items.filter { $0.artwork != nil })
            
            if let song = songs.first, let catalogSong = await spotifyService.fetchCatalogSong(title: song.title, artist: song.artistName) {
                avSong = catalogSong
            }
            
            var catalogSongs = [Song]()
            for song in songs {
                if let catalogSong = await spotifyService.fetchCatalogSong(title: song.title, artist: song.artistName) {
                    catalogSongs.append(catalogSong)
                }
            }
            return catalogSongs.isEmpty ? nil : catalogSongs
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
        
    func fetchArtwork(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("Failed to load artwork: \(error.localizedDescription)")
            return nil
        }
    }
}
  
