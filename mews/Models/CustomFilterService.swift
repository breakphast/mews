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
class CustomFilterService {
    var customFilterModel: CustomFilterModel?
    var active = false
    
    let songModelManager: SongModelManager
    let spotifyTokenManager: SpotifyTokenManager
    
    var recSongs: [SongModel] { songModelManager.recSongs }
    var artistSeeds = [(id: String, name: String)]()
    var dislikedSongs: [String] {
        songModelManager.savedDeletedSongs?.map { $0.url } ?? []
    }
    
    init(songModelManager: SongModelManager, spotifyTokenManager: SpotifyTokenManager) {
        self.songModelManager = songModelManager
        self.spotifyTokenManager = spotifyTokenManager
        Task {
            try? await fetchCustomFilter()
        }
    }
        
    var customFetchingActive = false
    var lowRecsActive = false
    
    var token: String? { spotifyTokenManager.token }
    
    @MainActor
    func assignSeeds(artists: [String], genres: [String]) async {
        customFilterModel?.artists.removeAll()
        customFilterModel?.genreSeeds.removeAll()
        try? Helpers.container.mainContext.save()
        await spotifyTokenManager.ensureValidToken()
        
        guard let token = spotifyTokenManager.token else {
            print("No valid access token.")
            return
        }
        
        for artist in artists {
            if let spotifyArtist = await SpotifyService.fetchArtistID(artist: artist, token: token) {
                customFilterModel?.artists[spotifyArtist.artistID] = artist
                artistSeeds.append((spotifyArtist.artistID, spotifyArtist.artistName))
                print("Assigned Artist \(spotifyArtist.artistName)", spotifyArtist.artistID)
            }
        }
        
        for genre in genres {
            if let genreValue = Genres.genres[genre] {
                customFilterModel?.genreSeeds.append(genreValue)
                print("Assigned Genre \(genreValue)")
            }
        }
        
        return
    }
    
    func getCustomRecommendations() async -> [String: [Song]]? {
        await spotifyTokenManager.ensureValidToken()
        guard let token else {
            print("No valid access token.")
            return nil
        }
        
        var recommendedSongs = [String: [Song]]()
        var indieRecs = [Song]()
        for artist in customFilterModel?.artists ?? [:] {
            print("Getting recs based on \(artist.value)")
            if let recommendations = await fetchCustomRecommendations(token: token, seed: artist.key, seedType: .artist) {
                for recSong in recommendations.0 {
                    guard let url = recSong.url?.absoluteString, !dislikedSongs.contains(url) else {
                        continue
                    }
                    guard await !SpotifyService.songInLibrary(song: recSong) else { continue }
                    guard await !SpotifyService.songInRecs(song: recSong, recSongs: songModelManager.recSongs, indieRecommendations: indieRecs) else { continue }
                    
                    if let catalogSong = await LibraryService.fetchCatalogSong(title: recSong.title, artist: recSong.artistName) {
                        if let artist = artistSeeds.first(where: { $0.id == artist.key }) {
                            if recommendedSongs[artist.name] != nil {
                                recommendedSongs[artist.name]?.append(catalogSong)
                            } else {
                                recommendedSongs[artist.name] = [catalogSong]
                            }
                            indieRecs.append(catalogSong)
                        }
                    }
                }
            }
        }
        
        for genre in customFilterModel?.genreSeeds ?? [] {
            print("Getting recs based on \(genre)")
            if let recommendations = await fetchCustomRecommendations(token: token, seed: genre, seedType: .genre) {
                for recSong in recommendations.0 {
                    guard let url = recSong.url?.absoluteString, !dislikedSongs.contains(url) else {
                        continue
                    }
                    guard await !SpotifyService.songInLibrary(song: recSong) else { continue }
                    guard await !SpotifyService.songInRecs(song: recSong, recSongs: songModelManager.recSongs, indieRecommendations: indieRecs) else { continue }
                    
                    if let catalogSong = await LibraryService.fetchCatalogSong(title: recSong.title, artist: recSong.artistName) {
                        if let genreValue = Genres.genres.first(where: { $0.value == genre })?.key {
                            if recommendedSongs[genreValue] != nil {
                                recommendedSongs[genreValue]?.append(catalogSong)
                            } else {
                                recommendedSongs[genreValue] = [catalogSong]
                            }
                            indieRecs.append(catalogSong)
                        }
                    }
                }
            }
        }
        print("Returned \(recommendedSongs.count) custom recommendations")
        return recommendedSongs.isEmpty ? nil : recommendedSongs
    }
    
    func fetchCustomRecommendations(token: String, seed: String, seedType: SeedType) async -> ([Song], String)? {
        var queryItems = [URLQueryItem]()
        if seedType == .artist {
            queryItems.append(URLQueryItem(name: "seed_artists", value: seed))
        } else {
            queryItems.append(URLQueryItem(name: "seed_genres", value: seed))
        }
        
        if let seeds = customFilterModel?.activeSeeds {
            let limit = SeedLimit(count: seeds.count)
            if limit != .oneSeed {
                queryItems.append(URLQueryItem(name: "limit", value: "\(limit.songsPerSeed)"))
            }
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
                if let artist = track.artists.first?.name, let song = await LibraryService.fetchCatalogSong(title: track.name, artist: artist) {
                    tracks.append(song)
                }
            }
            
            return (tracks, seed)
        } catch {
            print("Error fetching recommendations: \(error.localizedDescription)")
            return nil
        }
    }
    
    func persistCustomRecommendations(songs: [String: [Song]]) async throws {
        guard let customFilterModel else { return }
        
        let context = ModelContext(try ModelContainer(for: SongModel.self, CustomFilterModel.self))
        
        for (seedName, songArray) in songs {
            for song in songArray {
                let songModel = SongModel(song: song, isCatalog: false)
                songModel.recSong = seedName
                songModel.custom = true
                songModel.recSeed = seedName
                context.insert(songModel)
                customFilterModel.songs.append(songModel)
            }
        }
        
        do {
            try context.save()
            active = true
            print("Successfully persisted \(songs.values.flatMap({ $0 }).count) custom recommended songs")
        } catch {
            print("Could not persist songs")
        }
    }
    
    func persistCustomFilter(_ customFilter: CustomFilterModel) async throws {
        let context = ModelContext(try ModelContainer(for: CustomFilterModel.self))
        context.insert(customFilter)
        
        do {
            try context.save()
            print("Successfully saved custom filter")
        } catch {
            print("Could not save custom filter")
        }
    }
    
    @MainActor
    func deleteCustomFilter(_ customFilter: CustomFilterModel) async throws {
        let context = Helpers.container.mainContext
        
        context.delete(customFilter)
        
        do {
            try context.save()
            print("Successfully deleted custom filter")
        } catch {
            print("Could not delete custom filter")
            throw error
        }
    }
    
    @MainActor
    func fetchCustomFilter() async throws {
        let filterDescriptor = FetchDescriptor<CustomFilterModel>()
        
        let context = Helpers.container.mainContext
        let items = try context.fetch(filterDescriptor)
        if let filter = items.first {
            active = false
            customFilterModel = filter
        }
        return
    }
    
    func lowCustomRecsTrigger() async {
        print("Getting low", customFilterModel?.songs.count ?? "None")
        lowRecsActive = true
        if let recommendedSongs = await getCustomRecommendations() {
            try? await persistCustomRecommendations(songs: recommendedSongs)
        }
        return
    }
}

enum SeedType {
    case artist
    case genre
}
