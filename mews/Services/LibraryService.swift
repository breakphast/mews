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
    var librarySongIDs = [String]()
    
    var recommendedSong: Song?
    
    let spotifyService = SpotifyService()
    
    init() {
        loadSavedLibrarySongs()
    }
    
    func fetchSongs() async throws -> [Song]? {
        var libraryRequest = MusicLibraryRequest<Song>()
        libraryRequest.limit = 20
        
        do {
            let libraryResponse = try await libraryRequest.response()
            songs = Array(libraryResponse.items.filter { $0.artwork != nil })
                        
            var catalogSongs = [Song]()
            for song in songs {
                if let catalogSong = await spotifyService.fetchCatalogSong(title: song.title, artist: song.artistName) {
                    catalogSongs.append(catalogSong)
                }
            }
            return catalogSongs.isEmpty ? nil : catalogSongs
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
    
    func saveLibrarySongIDs(songs: [Song]) {
        let librarySongIDs = songs.map { $0.id.rawValue }
        var currentLibrarySongIDs = UserDefaults.standard.array(forKey: "librarySongIDs") as? [String] ?? []
        currentLibrarySongIDs.append(contentsOf: librarySongIDs)
        
        UserDefaults.standard.set(currentLibrarySongIDs, forKey: "librarySongIDs")
    }
    
    func loadSavedLibrarySongs() {
        let savedLibrarySongIDs = UserDefaults.standard.array(forKey: "librarySongIDs") as? [String]
        librarySongIDs = savedLibrarySongIDs ?? []
    }
}
  
