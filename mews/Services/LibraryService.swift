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
    let spotifyService = SpotifyService()
    var songs = [Song]()
    var playlists = [Playlist]()
    
    func fetchArtwork(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("Failed to load artwork: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getDeletePlaylist() async -> Playlist? {
        let libraryRequest = MusicLibraryRequest<Playlist>()
        
        let libraryResponse = try? await libraryRequest.response()
        if let playlist = libraryResponse?.items.first(where: { $0.name == "Songs To Delete (mews)" }) {
            return playlist
        }
        return nil
    }
    
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

                    // Array to store the recommendations
                    var recommendations = [(artistName: String, name: String, id: String)]()

                    for item in dataArray {
                        if let id = item["id"] as? String,
                           let attributes = item["attributes"] as? [String: Any],
                           let artistName = attributes["artistName"] as? String,
                           let name = attributes["name"] as? String {

                            // Add to the recommendations array
                            recommendations.append((artistName: artistName, name: name, id: id))
                        }
                    }

                    // Return the recommendations array
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
    let developerToken = "eyJhbGciOiJFUzI1NiIsImtpZCI6IkY3NjNRQjQ4TUwiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJHOVJQWU1TMlBBIiwiaWF0IjoxNzI3OTkwNjI1LCJleHAiOjE3NDM1NDI2MjV9.PX9Zzu6CtlH52ieCZG7S_w-q6YnINJg6JL5mrYuJ7lSuMpOBBxR3mTxZ1wdGiDjdU-zEJ6qxB-rDk04PxiPdvQ"
    
    func fetchLibrarySongs() async throws -> [Song]? {
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
    
    func addSongToLibrary(song: Song) async {
        try? await MusicLibrary.shared.add(song)
    }
    
    func addSongToDeletePlaylist(song: Song, playlist: Playlist) async {
        let _ = try? await MusicLibrary.shared.add(song, to: playlist)
    }
    
    func createAppleMusicPlaylist(songs: [Song]) async {
        let library = MusicLibrary.shared
        if let playlist = try? await library.createPlaylist(name: "Songs To Delete (mews)") {
            for song in songs {
                let _ = try? await library.add(song, to: playlist)
            }
        }
    }
}
  
