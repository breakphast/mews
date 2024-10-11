//
//  AccessTokenManager.swift
//  mews
//
//  Created by Desmond Fitch on 10/8/24.
//

import SwiftUI
import Observation

@Observable
class SpotifyTokenManager {
    let clientID = "a8ba7d7bab8d4e58861664629aee4d95"
    let clientSecret = "97734b3651af45e4bb685a2c709e7dc1"
    
    var token: String?
    var tokenExpiryDate: Date?
    
    init() {
        loadTokenFromUserDefaults()
        Task {
            await getAccessToken()
        }
    }
    
    func saveTokenToUserDefaults() {
        UserDefaults.standard.set(token, forKey: "accessToken")
        UserDefaults.standard.set(tokenExpiryDate, forKey: "tokenExpiryDate")
    }
    
    func loadTokenFromUserDefaults() {
        token = UserDefaults.standard.string(forKey: "accessToken")
        tokenExpiryDate = UserDefaults.standard.object(forKey: "tokenExpiryDate") as? Date
    }
    
    func getAccessToken() async {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            print("Invalid URL")
            return
        }
        
        if let token, let tokenExpiryDate, tokenExpiryDate > Date() {
            self.token = token
            self.tokenExpiryDate = tokenExpiryDate
            print("Using current key.")
            return
        }
        print("Getting new key.")
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
                token = tokenResponse.access_token
                tokenExpiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
                saveTokenToUserDefaults()
                return
            } else {
                print("Token Error: Status code \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                return
            }
        } catch {
            print("Error retrieving access token: \(error.localizedDescription)")
            return
        }
    }
}
