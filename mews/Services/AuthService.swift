//
//  AuthService.swift
//  mews
//
//  Created by Desmond Fitch on 10/7/24.
//

import SwiftUI
import Observation
import MusicKit

@Observable
class AuthService {
    var status: MusicAuthorization.Status
    
    init() {
        let authStatus = MusicAuthorization.currentStatus
        status = authStatus
    }
    
    @MainActor
    private func update(status: MusicAuthorization.Status) {
        withAnimation {
            self.status = status
        }
    }
    
    func authorizeAction() async throws {
        switch self.status {
        case .notDetermined:
            Task {
                let status = await MusicAuthorization.request()
                await update(status: status)
                return
            }
        case .denied:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                
            }
        default:
            print("Error.")
        }        
    }
}
