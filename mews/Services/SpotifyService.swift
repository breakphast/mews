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
    
    @MainActor
    func getRecommendations(using unusedLibSongs: [SongModel], token: String) async -> [Song]? {
        var catalogSongs = [Song]()
        var unusedSongsIterator = unusedLibSongs.makeIterator()
        
        while catalogSongs.count < 10, let song = unusedSongsIterator.next() {
            // Fetch artist and track ID for the current unused song
            let _ = await fetchArtistID(artist: song.artist, token: token)
            let _ = await fetchTrackID(artist: song.artist, title: song.title, token: token)
            song.usedForSeed = true
            try? container.mainContext.save()
            
            if let recommendations = await fetchRecommendations(token: token) {
                for song in recommendations {
                    guard await !songInLibrary(song: song) else { continue }
                    
                    if let catalogSong = await fetchCatalogSong(title: song.title, artist: song.artistName) {
                        catalogSongs.append(catalogSong)
                        
                        if catalogSongs.count >= 10 { break }
                    }
                }
            }
        }
        
        print("Fetched \(catalogSongs.count) songs from Spotify catalog")
        return catalogSongs.isEmpty ? nil : catalogSongs
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
    
    func songInLibrary(song: Song) async -> Bool {
        var libraryRequest = MusicLibraryRequest<Song>()
        libraryRequest.limit = 5
        libraryRequest.filter(matching: \.title, equalTo: song.title)
        
        do {
            if let libraryResponse = try? await libraryRequest.response(),
               let _ = Array(libraryResponse.items.filter { $0.artwork != nil }).first {
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
            let _ = Array(libraryResponse.items.filter { $0.artwork != nil }).first {
                return true
            }
        }
        return false
    }
    
    func persistSongModels(songs: [Song], isCatalog: Bool) async throws {
        let context = ModelContext(try ModelContainer(for: SongModel.self))
        
        for song in songs {
            let songModel = (SongModel(song: song, isCatalog: isCatalog))
            context.insert(songModel)
        }
        
        do {
            try context.save()
            print("Successfuly persisted \(songs.count) \(isCatalog ? "library" : "recommended") songs")
        } catch {
            print("Could not persist songs")
        }
    }
    
    func lowRecsTrigger(songs: [SongModel], token: String, libSongIDs: [String]) async {
        let count = songs.count
        if count <= 10 {
            if let recommendedSongs = await getRecommendations(using: songs, token: token) {
                let filteredRecSongs = recommendedSongs.filter {
                    // only inlcude songs that are not in user's Apple Music library
                    !libSongIDs.contains($0.id.rawValue)
                }
                try? await persistSongModels(songs: filteredRecSongs, isCatalog: false)
                return
            }
        }
        return
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
