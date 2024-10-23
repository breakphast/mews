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
    func assignFilters(artist: String? = nil, genre: String? = nil) async {
        if let artist {
            customFilterModel?.genreSeed = nil
            
            await spotifyTokenManager.ensureValidToken()
            
            guard let token = spotifyTokenManager.token else {
                print("No valid access token.")
                return
            }
            
            if let spotifyArtist = await SpotifyService.fetchArtistID(artist: artist, token: token) {
                customFilterModel?.artistSeedName = spotifyArtist.artistName
                customFilterModel?.artistSeedID = spotifyArtist.artistID
                print("Assigned Artist \(spotifyArtist.artistName)", spotifyArtist.artistID)
            }
            return
        }
        
        if let genre {
            customFilterModel?.artistSeedID = nil
            customFilterModel?.artistSeedName = nil
            customFilterModel?.genreSeed = Genres.genres[genre]
            print("Assigned Genre")
            return
        }
    }
    
    func getCustomRecommendations() async -> [String: [Song]]? {
        await spotifyTokenManager.ensureValidToken()
        
        guard let token else {
            print("No valid access token.")
            return nil
        }
        
        var recommendedSongs = [String: [Song]]()
        var indieRecs = [Song]()
        print("Getting recs based on \(customFilterModel?.artistSeedID == nil ? "genre \(customFilterModel?.genreSeed ?? "")" : "artist \(customFilterModel?.artistSeedName ?? "")")")
        if let recommendations = await fetchCustomRecommendations(token: token) {
            for recSong in recommendations {
                guard let url = recSong.url?.absoluteString, !dislikedSongs.contains(url) else {
                    continue
                }
                guard await !SpotifyService.songInLibrary(song: recSong) else { continue }
                guard await !SpotifyService.songInRecs(song: recSong, recSongs: songModelManager.recSongs, indieRecommendations: indieRecs) else { continue }
                
                if let catalogSong = await LibraryService.fetchCatalogSong(title: recSong.title, artist: recSong.artistName) {
                    if recommendedSongs[recSong.id.rawValue] != nil {
                        recommendedSongs[recSong.id.rawValue]?.append(catalogSong)
                    } else {
                        recommendedSongs[recSong.id.rawValue] = [catalogSong]
                    }
                    indieRecs.append(catalogSong)
                }
            }
        }
        print("Returned \(recommendedSongs.count) custom recommendations")
        return recommendedSongs.isEmpty ? nil : recommendedSongs
    }
    
    func fetchCustomRecommendations(token: String) async -> [Song]? {
        var queryItems = [URLQueryItem]()
        if let id = customFilterModel?.artistSeedID {
            queryItems.append(URLQueryItem(name: "seed_artists", value: id))
        }
        if let genreSeed = customFilterModel?.genreSeed {
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
                if let artist = track.artists.first?.name, let song = await LibraryService.fetchCatalogSong(title: track.name, artist: artist) {
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
        guard let customFilterModel else { return }
        
        let context = ModelContext(try ModelContainer(for: SongModel.self, CustomFilterModel.self))
        
        for (songID, songArray) in songs {
            for song in songArray {
                let songModel = SongModel(song: song, isCatalog: false)
                songModel.recSong = songID
                songModel.custom = true
                songModel.recSeed = customFilterModel.artistSeedName ?? Genres.genres.first(where: { $0.value == customFilterModel.genreSeed })?.key ?? ""
                context.insert(songModel)
                customFilterModel.songs.append(songModel)
            }
        }
        
        do {
            try context.save()
            active = true
            print("Successfully persisted \(songs.values.flatMap({ $0 }).count) custom recommended songs")
            print("Custom filter song count: \(customFilterModel.songs.count)")
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
