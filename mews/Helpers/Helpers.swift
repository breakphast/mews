//
//  Helpers.swift
//  mews
//
//  Created by Desmond Fitch on 10/17/24.
//

import SwiftUI
import SwiftData

struct Helpers {
    static func fetchArtwork(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("Failed to load artwork: \(error.localizedDescription)")
            return nil
        }
    }
    
    static let container: ModelContainer = {
        do {
            let container = try ModelContainer(for: SongModel.self)
            return container
        } catch {
            fatalError("Failed to create container: \(error)")
        }
    }()
    
    // Apple Music developer token
    static let developerToken = "eyJhbGciOiJFUzI1NiIsImtpZCI6IkY3NjNRQjQ4TUwiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJHOVJQWU1TMlBBIiwiaWF0IjoxNzI3OTkwNjI1LCJleHAiOjE3NDM1NDI2MjV9.PX9Zzu6CtlH52ieCZG7S_w-q6YnINJg6JL5mrYuJ7lSuMpOBBxR3mTxZ1wdGiDjdU-zEJ6qxB-rDk04PxiPdvQ"
    
    static let idiom = UIDevice.current.userInterfaceIdiom
}

struct OrientationChangeModifier: ViewModifier {
    @Binding var isLandscape: Bool
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .onAppear {
                    isLandscape = geometry.size.width > geometry.size.height
                }
                .onChange(of: geometry.size) { _, newSize in
                    isLandscape = newSize.width > newSize.height
                }
        }
    }
}
