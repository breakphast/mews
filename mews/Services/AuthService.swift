//
//  AuthService.swift
//  mews
//
//  Created by Desmond Fitch on 10/7/24.
//

import SwiftUI
import Observation
import MusicKit
import AuthenticationServices

@Observable
class AuthService {
    var status: MusicAuthorization.Status
    var activeSubscription: Bool?
    var authError: AuthError?
    var appleUserID: String?
    
    init() {
        let authStatus = MusicAuthorization.currentStatus
        status = authStatus
        Task {
            self.activeSubscription = await isActiveSubscription()
        }
        if let userID: String = Helpers.getFromUserDefaults(forKey: "appleUserID") {
            appleUserID = userID
        }
    }
    
    func isActiveSubscription() async -> Bool {
        if let subsription = try? await MusicSubscription.current {
            return subsription.canPlayCatalogContent
        }
        return false
    }
    
    @MainActor
    private func update(status: MusicAuthorization.Status) {
        withAnimation {
            if status == .denied {
                self.status = status
                Task {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        if UIApplication.shared.canOpenURL(settingsURL) {
                            UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                        }
                    }
                }
            } else {
                self.status = status
            }
        }
    }
    
    func authorizeAction() async {
        switch self.status {
        case .notDetermined:
            let status = await MusicAuthorization.request()
            await update(status: status)
            return
        case .denied:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                if await UIApplication.shared.canOpenURL(settingsURL) {
                    await UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                }
            }
        default:
            print("Error.")
        }        
    }
}

enum AuthError: Error {
    case denied
    case noSubscription
}

let users: [String] = [
    "000286.569fb9de8ece4d6fbc7253d905faf294.1359"
]
