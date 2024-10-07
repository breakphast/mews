//
//  LibraryService.swift
//  mews
//
//  Created by Desmond Fitch on 10/7/24.
//

import SwiftUI
import MusicKit
import Observation

@Observable
class LibraryService {
    var songs = [Song]()
    var playlists = [Playlist]()
    
    var recommendedSong: Song?
    
    func fetchSongs() async throws {
        let libraryRequest = MusicLibraryRequest<Song>()
        
        do {
            let libraryResponse = try await libraryRequest.response()
            songs = Array(libraryResponse.items)
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
}
  
