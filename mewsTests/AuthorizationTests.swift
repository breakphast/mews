//
//  mewsTests.swift
//  mewsTests
//
//  Created by Desmond Fitch on 10/10/24.
//

import Testing
@testable import mews
import SwiftUI

final class AuthorizationTests {
    let authService = AuthService()
    let spotifyTokenManager = SpotifyTokenManager()
    
    init() {
        spotifyTokenManager.token = nil
        spotifyTokenManager.tokenExpiryDate = nil
    }
    
    @Test("Get initial access token")
    func getAccessTokenSucces() async {
        await spotifyTokenManager.getAccessToken()
        #expect(spotifyTokenManager.token != nil)
    }
    
    #if targetEnvironment(simulator)
    @Test("Save and load token from user defaults")
    func saveAndLoadToken() {
        spotifyTokenManager.token = "444666"
        spotifyTokenManager.saveTokenToUserDefaults()
        spotifyTokenManager.token = nil
        spotifyTokenManager.loadTokenFromUserDefaults()
        #expect(UserDefaults.standard.string(forKey: "accessToken") == "444666")
        UserDefaults.standard.removeObject(forKey: "accessToken")
    }
    #endif
    
    @Test("Use current key")
    func useCurrentKey() async {
        spotifyTokenManager.token = "123"
        spotifyTokenManager.tokenExpiryDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        await spotifyTokenManager.getAccessToken()
        #expect(spotifyTokenManager.token == "123")
    }
    
    @Test("Get new key")
    func getNewKey() async {
        spotifyTokenManager.token = "123"
        spotifyTokenManager.tokenExpiryDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date())
        await spotifyTokenManager.getAccessToken()
        #expect(spotifyTokenManager.token != "123")
    }
}
