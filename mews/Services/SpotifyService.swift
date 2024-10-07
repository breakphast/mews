//
//  SpotifyService.swift
//  mews
//
//  Created by Desmond Fitch on 10/7/24.
//

import SwiftUI
import Observation
import MusicKit

@Observable
class SpotifyService {
    let clientID = "a8ba7d7bab8d4e58861664629aee4d95"
    let clientSecret = "97734b3651af45e4bb685a2c709e7dc1"
    
    var artistIDs = [String]()
    var trackIDs = [String]()
    
    var artist: String?
    var title: String?
    var recommendations: [SpotifyTrack]?
    
    var recommendedTrack: SpotifyTrack?
    var recommendedSongs: [Song]?
    
    var accessToken: String?
    private var tokenExpiryDate: Date?
    
    @MainActor
    func fetchCatalogSong(title: String, artist: String) async throws -> Song? {
        let searchRequest = MusicCatalogSearchRequest(term: title.lowercased(), types: [Song.self])
        
        let searchResponse = try await searchRequest.response()
        if let catalogSong = searchResponse.songs.first(where: { $0.artistName.lowercased() == artist.lowercased() }) {
            return catalogSong
        } else {
            print("No matching song found in the Apple Music catalog.")
            return nil
        }
    }
    
    func fetchArtistID() async {
        guard let artist else { return }
        
        let encodedArtistName = artist.lowercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://api.spotify.com/v1/search?q=\(encodedArtistName)&type=artist&limit=1") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                print("Error: Invalid response")
                return
            }
            
            let decodedResponse = try JSONDecoder().decode(SpotifySearchResult.self, from: data)
            artistIDs.append(decodedResponse.artists.items.first?.id ?? "")
            return
        } catch {
            print("Error fetching artist ID: \(error.localizedDescription)")
            return
        }
    }
    
    func fetchTrackID() async {
        guard let artist, let title else { return }
        
        let encodedTrackTitle = title.lowercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedArtistName = artist.lowercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard let url = URL(string: "https://api.spotify.com/v1/search?q=track:\(encodedTrackTitle)%20artist:\(encodedArtistName)&type=track&limit=1") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                print("Error: Invalid response")
                return
            }
            
            let decodedResponse = try JSONDecoder().decode(SpotifyTrackSearchResult.self, from: data)
            trackIDs.append(decodedResponse.tracks.items.first?.id ?? "")
            print(decodedResponse.tracks.items.first?.name ?? "NNNNNNN")
            return
        } catch {
            print("Error fetching track ID: \(error.localizedDescription)")
            return
        }
    }
    
    func fetchRecommendations() async {
        guard !trackIDs.isEmpty && !artistIDs.isEmpty else { return }
        
        let seedArtistsParam = artistIDs.joined(separator: ",")
        let seedGenresParam = ["rap"]
        let seedTracksParam = trackIDs.joined(separator: ",")
        
        guard let url = URL(string: "https://api.spotify.com/v1/recommendations?seed_artists=\(seedArtistsParam)&seed_genres=\(seedGenresParam)&seed_tracks=\(seedTracksParam)&limit=10") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                print("Error: Status code \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                return
            }

            let decodedResponse = try JSONDecoder().decode(SpotifyRecommendationsResult.self, from: data)
            recommendations = decodedResponse.tracks
            
            var tracks = [Song]()
            for track in decodedResponse.tracks {
                if let artist = track.artists.first?.name, let song = try await fetchCatalogSong(title: track.name, artist: artist) {
                    tracks.append(song)
                }
            }
            recommendedSongs = tracks
        } catch {
            print("Error fetching recommendations: \(error.localizedDescription)")
            return
        }
    }
    
    func getAccessToken() async {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            print("Invalid URL")
            return
        }
        
        if let token = accessToken, let expiry = tokenExpiryDate, expiry > Date() {
            print("Already got access token")
            accessToken = token
        }
        
        let credentials = "\(clientID):\(clientSecret)".data(using: .utf8)?.base64EncodedString() ?? ""
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        
        let bodyComponents = "grant_type=client_credentials"
        request.httpBody = bodyComponents.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                accessToken = tokenResponse.access_token
                tokenExpiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
                print("Got new access token.")
                return
            } else {
                print("Error: Status code \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                return
            }
        } catch {
            print("Error retrieving access token: \(error.localizedDescription)")
            return
        }
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
