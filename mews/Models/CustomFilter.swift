//
//  CustomFilter.swift
//  mews
//
//  Created by Desmond Fitch on 10/16/24.
//

import SwiftUI
import MusicKit
import SwiftData

@Observable
class CustomFilter {
    var token: String
    var songModelManager: SongModelManager
    
    var recSongs: [SongModel] { songModelManager.savedRecSongs }
    
    var dislikedSongs: [String] {
        songModelManager.savedDeletedSongs?.map { $0.url } ?? []
    }
    
    init(token: String, songModelManager: SongModelManager) {
        self.token = token
        self.songModelManager = songModelManager
        print("Init.")
    }
    
    var artistName: String?
    var artistSeed: String?
    var genreSeed: String?
    
    var customFetchingActive = false
    var lowRecsActive = false
    
    var activeSeed: SeedOption = .genre
    var active = false
    
    @MainActor
    func assignFilters(artist: String? = nil, genre: String? = nil) async {
        if let artist {
            genreSeed = nil
            if let artistID = await SpotifyService().fetchArtistID(artist: artist, token: token) {
                artistName = artist
                artistSeed = artistID.artistID
                print("Assigned Artist \(artist)", artistID.artistID)
            }
            return
        }
        
        if let genre {
            artistSeed = nil
            genreSeed = genre
            print("Assigned Genre")
            return
        }
    }
    
    func getCustomRecommendations() async -> [String: [Song]]? {
        var recommendedSongs = [String: [Song]]()
        print("Getting recs based on \(artistSeed == nil ? "genre \(genreSeed ?? "")" : "artist \(artistName ?? "")")")
        if let recommendations = await fetchCustomRecommendations() {
            for recSong in recommendations {
                guard let url = recSong.url?.absoluteString, !dislikedSongs.contains(url) else {
                    continue
                }
                guard await !SpotifyService().songInLibrary(song: recSong) else { continue }
                guard await !SpotifyService().songInRecs(song: recSong, recSongs: songModelManager.savedRecSongs) else { continue }
                
                if let catalogSong = await SpotifyService().fetchCatalogSong(title: recSong.title, artist: recSong.artistName) {
                    if recommendedSongs[recSong.id.rawValue] != nil {
                        recommendedSongs[recSong.id.rawValue]?.append(catalogSong)
                    } else {
                        recommendedSongs[recSong.id.rawValue] = [catalogSong]
                    }
                }
            }
        }
        print("Returned \(recommendedSongs.count) custom recommendations")
        return recommendedSongs.isEmpty ? nil : recommendedSongs
    }
    
    func fetchCustomRecommendations() async -> [Song]? {
        var queryItems = [URLQueryItem]()
        if let artistSeed = artistSeed {
            queryItems.append(URLQueryItem(name: "seed_artists", value: artistSeed))
        }
        if let genreSeed = genreSeed {
            queryItems.append(URLQueryItem(name: "seed_genres", value: genreSeed))
        }
        
        var urlComponents = URLComponents(string: "https://api.spotify.com/v1/recommendations")
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
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
                if let artist = track.artists.first?.name, let song = await SpotifyService().fetchCatalogSong(title: track.name, artist: artist) {
                    tracks.append(song)
                }
            }
            return tracks
        } catch {
            print("Error fetching recommendations: \(error.localizedDescription)")
            return nil
        }
    }
    
    func persistCustomRecommendations(songs: [String: [Song]]) async throws {
        let context = ModelContext(try ModelContainer(for: SongModel.self))
        
        for (songID, songArray) in songs {
            for song in songArray {
                let songModel = SongModel(song: song, isCatalog: false)
                songModel.recSong = songID
                songModel.custom = true
                songModel.recSeed = artistName ?? Genres.genres.first(where: { $0.value == genreSeed })?.key ?? ""
                context.insert(songModel)
            }
        }
        
        do {
            try context.save()
            print("Successfully persisted \(songs.values.flatMap({ $0 }).count) custom recommended songs")
        } catch {
            print("Could not persist songs")
        }
    }
    
    func lowCustomRecsTrigger() async {
        print("Getting low", songModelManager.customFilterSongs.count)
        lowRecsActive = true
        if let recommendedSongs = await getCustomRecommendations() {
            try? await persistCustomRecommendations(songs: recommendedSongs)
            return
        }
        return
    }
}
