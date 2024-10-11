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
    
    let spotifyService = SpotifyService()
    
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
}
  
