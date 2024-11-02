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
    let songModelManager: SongModelManager
    // MARK: - Properties
    var songs = [Song]()
    var playlists = [Playlist]()
    var artists = [String]()
    var activePlaylist: Playlist?
    var saveToLibrary = false
    
    var likeActionOptions: [String] {
        return playlists.map { $0.name }
    }
    
    var savedSongs = [SongModel]()
    
    init(songModelManager: SongModelManager) {
        self.songModelManager = songModelManager
        Task {
            await getSavedLibraryArtists()
            
            if let fetchedArtists = try await fetchLibraryArtists() {
                if fetchedArtists.count > artists.count {
                    Helpers.saveToUserDefaults(fetchedArtists, forKey: "libraryArtists")
                    artists = fetchedArtists
                }
            }
            if let playlistName: String = Helpers.getFromUserDefaults(forKey: "defaultPlaylist") {
                if let playlist = await getPlaylist(playlistName) {
                    activePlaylist = playlist
                }
            }
            if let _: String = Helpers.getFromUserDefaults(forKey: "saveToLibrary") {
                self.saveToLibrary = true
            }
        }
    }
        
    // MARK: - Heavy Rotation
    
    /// Fetches the user's heavy rotation from Apple Music
    static func getHeavyRotation() async -> [(artistName: String, name: String, id: String)]? {
        do {
            // Step 1: Ensure user authorization for Apple Music
            let status = await MusicAuthorization.request()
            guard status == .authorized else {
                print("User is not authorized for Apple Music.")
                return nil
            }
            
            // Step 2: Fetch the Music User Token
            let musicUserToken = try await MusicUserTokenProvider().userToken(for: Helpers.developerToken, options: .ignoreCache)
            
            // Step 3: Prepare the request URL
            guard let url = URL(string: "https://api.music.apple.com/v1/me/history/heavy-rotation") else {
                print("Invalid URL")
                return nil
            }
            
            // Step 4: Set up the URL request with headers
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(Helpers.developerToken)", forHTTPHeaderField: "Authorization")
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
            if let catalogSong = await Self.fetchCatalogSong(title: song.title, artist: song.artistName) {
                catalogSongs.append(catalogSong)
            }
        }
        return catalogSongs.isEmpty ? nil : catalogSongs
    }
    
    func persistLibrarySongs(songs: [Song]) async throws {
        let context = ModelContext(try ModelContainer(for: SongModel.self, CustomFilterModel.self))
        
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
    
    @MainActor
    static func fetchCatalogSong(title: String, artist: String) async -> Song? {
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
    
    static func fetchCatalogSong(song: SongModel) async -> Song? {
        let searchRequest = MusicCatalogSearchRequest(term: "\(song.title) \(song.artist)", types: [Song.self])
        do {
            let searchResponse = try await searchRequest.response()
            
            if let catalogSong = searchResponse.songs.first(where: { $0.url?.absoluteString == song.catalogURL }) {
                return catalogSong
            } else {
                print("URLs do not match")
                return nil
            }
            
        } catch {
            print("Error fetching catalog song: \(song.title)")
        }
        
        return nil
    }
    
    /// Fetches artists from the user's music library
    func fetchLibraryArtists() async throws -> [String]? {
        let libraryRequest = MusicLibraryRequest<Artist>()
        let libraryResponse = try await libraryRequest.response()
        
        let fetchedArtists = Array(libraryResponse.items.filter { !$0.name.isEmpty }.map { $0.name })
        return fetchedArtists.isEmpty ? nil : fetchedArtists
    }
    
    /// Fetches playlists from the user's music library
    func fetchLibraryPlaylists() async throws {
        let libraryRequest = MusicLibraryRequest<Playlist>()
        do {
            let libraryResponse = try await libraryRequest.response()
            playlists = Array(libraryResponse.items.filter { $0.kind == .userShared })
        } catch {
            return
        }
    }
    
    func getPlaylist() async {
        let libraryRequest = MusicLibraryRequest<Playlist>()
        var libraryResponse: MusicLibraryResponse<Playlist>?
        do {
            libraryResponse = try await libraryRequest.response()
        } catch {
            return
        }
        
        guard !saveToLibrary else { return }
        
        if let activePlaylist {
            self.activePlaylist = activePlaylist
        } else if let defaultPlaylist = libraryResponse?.items.first(where: { $0.name == "Found with DiscoMuse" }) {
            self.activePlaylist = defaultPlaylist
        } else if let newDefaultPlaylist = await Self.createDefaultPlaylist() {
            self.activePlaylist = newDefaultPlaylist
        }
        
        return
    }
    
    static func createDefaultPlaylist() async -> Playlist? {
        let library = MusicLibrary.shared
        return try? await library.createPlaylist(name: "Found with DiscoMuse")
    }
    
    func getPlaylist(_ name: String) async -> Playlist? {
        let libraryRequest = MusicLibraryRequest<Playlist>()
        let libraryResponse = try? await libraryRequest.response()
        
        if let defaultPlaylist = libraryResponse?.items.first(where: { $0.name == name }) {
            return defaultPlaylist
        }
        return nil
    }
    
    // MARK: - Library Saving Methods
    
    /// Fetches and saves artists from UserDefaults or MusicKit
    func getSavedLibraryArtists() async {
        if let savedArtists = UserDefaults.standard.array(forKey: "libraryArtists") as? [String], !savedArtists.isEmpty {
            artists = savedArtists
        } else {
            if let savedArtists = try? await fetchLibraryArtists() {
                Helpers.saveToUserDefaults(savedArtists, forKey: "libraryArtists")
                artists = savedArtists
            }
        }
    }
    
    // MARK: - Library Actions
    
    /// Adds a song to the user's Apple Music library
    static func addSongToLibrary(song: Song) async {
        try? await MusicLibrary.shared.add(song)
    }
    
    /// Adds a song to the "Songs To Delete (mews)" playlist
    static func addSongToPlaylist(song: Song, playlist: Playlist) async {
        let library = MusicLibrary.shared
        let _ = try? await library.add(song, to: playlist)
    }
}
