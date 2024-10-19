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
    
    // MARK: - Properties
    
    let spotifyService = SpotifyService()
    var songs = [Song]()
    var playlists = [Playlist]()
    var artists = [String]()
    var activePlaylist: Playlist?
    
    // Apple Music developer token
    let developerToken = "eyJhbGciOiJFUzI1NiIsImtpZCI6IkY3NjNRQjQ4TUwiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJHOVJQWU1TMlBBIiwiaWF0IjoxNzI3OTkwNjI1LCJleHAiOjE3NDM1NDI2MjV9.PX9Zzu6CtlH52ieCZG7S_w-q6YnINJg6JL5mrYuJ7lSuMpOBBxR3mTxZ1wdGiDjdU-zEJ6qxB-rDk04PxiPdvQ"
    
    // MARK: - Heavy Rotation
    
    /// Fetches the user's heavy rotation from Apple Music
    func getHeavyRotation() async -> [(artistName: String, name: String, id: String)]? {
        do {
            // Step 1: Ensure user authorization for Apple Music
            let status = await MusicAuthorization.request()
            guard status == .authorized else {
                print("User is not authorized for Apple Music.")
                return nil
            }
            
            // Step 2: Fetch the Music User Token
            let musicUserToken = try await MusicUserTokenProvider().userToken(for: developerToken, options: .ignoreCache)
            print("Music User Token: \(musicUserToken)")
            
            // Step 3: Prepare the request URL
            guard let url = URL(string: "https://api.music.apple.com/v1/me/history/heavy-rotation") else {
                print("Invalid URL")
                return nil
            }
            
            // Step 4: Set up the URL request with headers
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(developerToken)", forHTTPHeaderField: "Authorization")
            request.addValue(musicUserToken, forHTTPHeaderField: "Music-User-Token")
            
            // Step 5: Execute the request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Step 6: Handle the HTTP response
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Parse the JSON data
                if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let dataArray = jsonObject["data"] as? [[String: Any]] {
                    
                    var recommendations = [(artistName: String, name: String, id: String)]()
                    
                    for item in dataArray {
                        if let id = item["id"] as? String,
                           let attributes = item["attributes"] as? [String: Any],
                           let artistName = attributes["artistName"] as? String,
                           let name = attributes["name"] as? String {
                            recommendations.append((artistName: artistName, name: name, id: id))
                        }
                    }
                    
                    return recommendations
                } else {
                    print("Failed to parse JSON data.")
                    return nil
                }
            } else {
                print("Failed to fetch rotation. Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("Error Response: \(errorData)")
                }
                return nil
            }
        } catch {
            print("Error fetching recommendations: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Library Fetching Methods
    
    /// Fetches songs from the user's music library
    func fetchLibrarySongs() async throws -> [Song]? {
        var libraryRequest = MusicLibraryRequest<Song>()
        libraryRequest.limit = 20
        
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
    
    /// Fetches artists from the user's music library
    func fetchLibraryArtists() async throws -> [String]? {
        let libraryRequest = MusicLibraryRequest<Artist>()
        let libraryResponse = try await libraryRequest.response()
        
        let artists = Array(libraryResponse.items.filter { !$0.name.isEmpty }.map { $0.name })
        return artists.isEmpty ? nil : artists
    }
    
    /// Fetches playlists from the user's music library
    func fetchLibraryPlaylists() async throws {
        let libraryRequest = MusicLibraryRequest<Playlist>()
        let libraryResponse = try await libraryRequest.response()
        
        playlists = Array(libraryResponse.items.filter { $0.kind == .userShared })
    }
    
    /// Fetches a playlist named "Songs To Delete (mews)"
    func getDeletePlaylist() async -> Playlist? {
        let libraryRequest = MusicLibraryRequest<Playlist>()
        let libraryResponse = try? await libraryRequest.response()
        
        return libraryResponse?.items.first(where: { $0.name == "Songs To Delete (mews)" })
    }
    
    // MARK: - Library Saving Methods
    
    /// Saves artists to UserDefaults
    func saveLibraryArtists(artists: [String]) {
        UserDefaults.standard.set(artists, forKey: "libraryArtists")
    }
    
    /// Fetches and saves artists from UserDefaults or MusicKit
    func getSavedLibraryArtists() async {
        if let savedArtists = UserDefaults.standard.array(forKey: "libraryArtists") as? [String], !savedArtists.isEmpty {
            artists = savedArtists
        } else {
            if let savedArtists = try? await fetchLibraryArtists() {
                saveLibraryArtists(artists: savedArtists)
                artists = savedArtists
            }
        }
    }
    
    // MARK: - Library Actions
    
    /// Adds a song to the user's Apple Music library
    func addSongToLibrary(song: Song) async {
        try? await MusicLibrary.shared.add(song)
    }
    
    /// Adds a song to the "Songs To Delete (mews)" playlist
    func addSongToDeletePlaylist(song: Song, playlist: Playlist) async {
        let _ = try? await MusicLibrary.shared.add(song, to: playlist)
    }
    
    /// Creates an Apple Music playlist with the given songs
    func createAppleMusicPlaylist(songs: [Song]) async {
        let library = MusicLibrary.shared
        if let playlist = try? await library.createPlaylist(name: "Songs To Delete (mews)") {
            for song in songs {
                let _ = try? await library.add(song, to: playlist)
            }
        }
    }
}
