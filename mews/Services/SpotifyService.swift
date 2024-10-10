//
//  SpotifyService.swift
//  mews
//
//  Created by Desmond Fitch on 10/7/24.
//

import SwiftUI
import Observation
import MusicKit
import SwiftData

@Observable
class SpotifyService {
    let clientID = "a8ba7d7bab8d4e58861664629aee4d95"
    let clientSecret = "97734b3651af45e4bb685a2c709e7dc1"
    
    var artistIDs = [String]()
    var trackIDs = [String]()
    
    var container: ModelContainer {
        let container = try! ModelContainer(for: SongModel.self)
        return container
    }
    
    @MainActor
    func fetchCatalogSong(title: String, artist: String) async -> Song? {
        let searchRequest = MusicCatalogSearchRequest(term: title.lowercased(), types: [Song.self])
        
        do {
            let searchResponse = try await searchRequest.response()
            if let catalogSong = searchResponse.songs.first(where: { $0.artistName.lowercased() == artist.lowercased() }) {
                return catalogSong
            } else {
                print("No matching song found in the Apple Music catalog.")
                return nil
            }
        } catch {
            print("Error fetching catalog song: \(title)")
        }
        
        return nil
    }
    
    func fetchArtistID(artist: String, token: String) async -> String? {
        let encodedArtistName = artist.lowercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://api.spotify.com/v1/search?q=\(encodedArtistName)&type=artist&limit=1") else {
            print("Invalid URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                print("Error: Invalid response")
                return nil
            }
            
            let decodedResponse = try JSONDecoder().decode(SpotifySearchResult.self, from: data)
            if let firstArtist = decodedResponse.artists.items.first {
                artistIDs.append(firstArtist.id)
                return firstArtist.id
            }
        } catch {
            print("Error fetching artist ID: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    func fetchTrackID(artist: String, title: String, token: String) async -> String? {
        let encodedTrackTitle = title.lowercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedArtistName = artist.lowercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard let url = URL(string: "https://api.spotify.com/v1/search?q=track:\(encodedTrackTitle)%20artist:\(encodedArtistName)&type=track&limit=1") else {
            print("Invalid URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                print("Error: Invalid response")
                return nil
            }
            
            let decodedResponse = try JSONDecoder().decode(SpotifyTrackSearchResult.self, from: data)
            
            for track in decodedResponse.tracks.items {
                trackIDs.append(track.id)
                return nil
            }
        } catch {
            print("Error fetching track ID: \(error.localizedDescription)")
            return nil
        }
        return nil
    }
    
    func fetchRecommendations(token: String) async -> [Song]? {
        guard !trackIDs.isEmpty || !artistIDs.isEmpty else {
            return nil
        }
        let seedArtistsParam = artistIDs.joined(separator: "%2C")
        let seedGenresParam = "rap"
        let seedTracksParam = trackIDs.joined(separator: "%2C")
        
        guard let url = URL(string: "https://api.spotify.com/v1/recommendations?seed_artists=\(seedArtistsParam)&seed_genres=\(seedGenresParam)&seed_tracks=\(seedTracksParam)") else {
            print("Invalid URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                print("Error: Status code \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                return nil
            }

            let decodedResponse = try JSONDecoder().decode(SpotifyRecommendationsResult.self, from: data)
            
            var tracks = [Song]()
            for track in decodedResponse.tracks {
                if let artist = track.artists.first?.name, let song = await fetchCatalogSong(title: track.name, artist: artist) {
                    tracks.append(song)
                }
            }
            return tracks
        } catch {
            print("Error fetching recommendations: \(error.localizedDescription)")
            return nil
        }
    }
    
    @MainActor
    func getRecommendations(using unusedLibSongs: [SongModel], token: String) async -> [Song]? {
        if let song = unusedLibSongs.first {
            let _ = await fetchArtistID(artist: song.artist, token: token)
            let _ = await fetchTrackID(artist: song.artist, title: song.title, token: token)
            song.usedForSeed = true
            try? container.mainContext.save()
        }
        
        if let recommendations = await fetchRecommendations(token: token) {
            var catalogSongs = [Song]()
            
            for song in recommendations {
                guard await !songInLibrary(song: song) else {
                    continue
                }
                
                if let catalogSong = await fetchCatalogSong(title: song.title, artist: song.artistName) {
                    catalogSongs.append(catalogSong)
                }
            }
            print("Fetched \(catalogSongs.count) songs from Spotify catalog")
            return catalogSongs
        }
        return nil
    }
    
    func songInLibrary(song: Song) async -> Bool {
        var libraryRequest = MusicLibraryRequest<Song>()
        libraryRequest.limit = 5
        libraryRequest.filter(matching: \.title.localizedLowercase, contains: song.title.lowercased())
        libraryRequest.filter(matching: \.artistName?.localizedLowercase, contains: song.artistName.lowercased())
        
        do {
            if let libraryResponse = try? await libraryRequest.response(),
            let song = Array(libraryResponse.items.filter { $0.artwork != nil }).first {
                return true
            }
        }
        return false
    }
    
    func songInLibrary(songModel: SongModel) async -> Bool {
        var libraryRequest = MusicLibraryRequest<Song>()
        libraryRequest.limit = 5
        libraryRequest.filter(matching: \.title, equalTo: songModel.title.lowercased())
        
        
        do {
            if let libraryResponse = try? await libraryRequest.response(),
            let song = Array(libraryResponse.items.filter { $0.artwork != nil }).first {
                return true
            }
        }
        return false
    }
}

struct SpotifySearchResult: Codable {
    let artists: SpotifyArtists
}

struct SpotifyArtists: Codable {
    let items: [SpotifyArtist]
}

struct SpotifyArtist: Codable {
    let id: String
    let name: String
}

struct SpotifyTrackSearchResult: Codable {
    let tracks: SpotifyTracks
}

struct SpotifyTracks: Codable {
    let items: [SpotifyTrack]
}

struct SpotifyTrack: Codable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]
}

struct SpotifyRecommendationsResult: Codable {
    let tracks: [SpotifyTrack]
}

struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
}
