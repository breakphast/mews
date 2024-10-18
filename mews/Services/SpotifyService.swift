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
    var artistSeeds = [String]()
    var trackSeeds = [String]()
    var genreSeed = "rap"
    
    var fetchingActive = false
    
    var container: ModelContainer {
        let container = try! ModelContainer(for: SongModel.self)
        return container
    }
    
    @MainActor
    func fetchCatalogSong(title: String, artist: String) async -> Song? {
        let searchRequest = MusicCatalogSearchRequest(term: "\(title) \(artist)", types: [Song.self])
        do {
            let searchResponse = try await searchRequest.response()
            for catalogSong in searchResponse.songs {
                if catalogSong.artistName.lowercased().contains(artist.lowercased()) {
                    return catalogSong
                }
            }
            return nil
        } catch {
            print("Error fetching catalog song: \(title), \(error)")
            return nil
        }
    }
    
    func fetchCatalogSong(title: String, artist: String, url: String) async -> Song? {
        let searchRequest = MusicCatalogSearchRequest(term: "\(title) \(artist)", types: [Song.self])
        do {
            let searchResponse = try await searchRequest.response()
            
            if let catalogSong = searchResponse.songs.first(where: { $0.url?.absoluteString == url }) {
                return catalogSong
            } else {
                print("URLs do not match")
                return nil
            }
            
        } catch {
            print("Error fetching catalog song: \(title)")
        }
        
        return nil
    }
    
    func fetchArtistID(artist: String, token: String) async -> (artistName: String, artistID: String)? {
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
                artistSeeds.append(firstArtist.id)  // Assuming artistSeeds is a global or class-level array
                return (artistName: firstArtist.name, artistID: firstArtist.id)  // Return name and ID as a tuple
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
                trackSeeds.append(track.id)
                return track.id
            }
        } catch {
            print("Error fetching track ID: \(error.localizedDescription)")
            return nil
        }
        return nil
    }
    
    @MainActor
    func getRecommendations(using unusedLibSongs: [SongModel], recSongs: [SongModel], dislikedSongs: [String], token: String) async -> [String: [Song]]? {
        var recommendedSongs = [String: [Song]]()
        fetchingActive = true
        for song in unusedLibSongs {
            print("Using song \(song.title) for recommendations.")
            
            artistSeeds.removeAll()
            trackSeeds.removeAll()
            let _ = await fetchArtistID(artist: song.artist, token: token)
            let _ = await fetchTrackID(artist: song.artist, title: song.title, token: token)
            
            if let recommendations = await fetchRecommendations(token: token) {
                var indieRecommendations = [Song]()
                
                while indieRecommendations.count < 10 {
                    for recSong in recommendations {
                        guard let url = recSong.url?.absoluteString, !dislikedSongs.contains(url) else {
                            continue
                        }
                        guard await !songInLibrary(song: recSong) else { continue }
                        guard await !songInRecs(song: recSong, recSongs: recSongs) else { continue }
                        
                        if let catalogSong = await fetchCatalogSong(title: recSong.title, artist: recSong.artistName) {
                            indieRecommendations.append(catalogSong)
                        }
                    }
                }
                if recommendedSongs[song.id] != nil {
                    recommendedSongs[song.id]?.append(contentsOf: indieRecommendations)
                } else {
                    recommendedSongs[song.id] = indieRecommendations
                }
                
                print("Added recommendations for \(song.title), total recommendations now: \(recommendedSongs.values.flatMap({ $0 }).count)")
                
                if recommendedSongs.values.flatMap({ $0 }).count >= 20 {
                    print("Reached 20 recommendations. Stopping further processing.")
                    fetchingActive = false
                    return recommendedSongs
                }
            }
        }
        fetchingActive = false
        print("Returned \(recommendedSongs.values.flatMap({ $0 }).count) recommendations")
        return recommendedSongs.isEmpty ? nil : recommendedSongs
    }
    
    func fetchRecommendations(token: String) async -> [Song]? {
        guard !trackSeeds.isEmpty || !artistSeeds.isEmpty else {
            return nil
        }
        let seedArtistsParam = artistSeeds.joined(separator: "%2C")
        let seedGenresParam = genreSeed
        let seedTracksParam = trackSeeds.joined(separator: "%2C")
        
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
                print("Recs Error: Status code \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
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
        libraryRequest.limit = 20
        libraryRequest.filter(text: song.title)
        
        do {
            if let libraryResponse = try? await libraryRequest.response() {
                if let _ = Array(libraryResponse.items.filter { $0.artwork != nil && $0.artistName.lowercased().contains(song.artistName.lowercased()) }).first {
                    return true
                }
            }
        }
        return false
    }
    
    func songInRecs(song: Song, recSongs: [SongModel]) async -> Bool {
        return recSongs.contains(where: { $0.id == song.id.rawValue })
    }
    
    func songInLibrary(songModel: SongModel) async -> Bool {
        var libraryRequest = MusicLibraryRequest<Song>()
        libraryRequest.limit = 20
        libraryRequest.filter(text: songModel.title)
        
        do {
            if let libraryResponse = try? await libraryRequest.response() {
                if let _ = Array(libraryResponse.items.filter { $0.artwork != nil && $0.artistName.lowercased().contains(songModel.artist.lowercased()) }).first {
                    return true
                }
            }
        }
        return false
    }
    
    func persistLibrarySongs(songs: [Song]) async throws {
        let context = ModelContext(try ModelContainer(for: SongModel.self))
        
        for song in songs {
            let songModel = (SongModel(song: song, isCatalog: true))
            context.insert(songModel)
        }
        
        do {
            try context.save()
            print("Successfuly persisted \(songs.count) \("library") songs")
        } catch {
            print("Could not persist songs")
        }
    }
    
    func persistRecommendations(songs: [String: [Song]]) async throws {
        let context = ModelContext(try ModelContainer(for: SongModel.self))
        
        for (songID, songArray) in songs {
            for song in songArray {
                let songModel = SongModel(song: song, isCatalog: false)
                songModel.recSong = songID
                context.insert(songModel)
            }
        }
        
        do {
            try context.save()
            print("Successfully persisted \(songs.values.flatMap({ $0 }).count) recommended songs")
        } catch {
            print("Could not persist songs")
        }
    }
    
    func lowRecsTrigger(songs: [SongModel], recSongs: [SongModel], dislikedSongs: [String], token: String) async {
        artistSeeds.removeAll()
        trackSeeds.removeAll()
        
        if let recommendedSongs = await getRecommendations(using: songs, recSongs: recSongs, dislikedSongs: dislikedSongs, token: token) {
            try? await persistRecommendations(songs: recommendedSongs)
            return
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
