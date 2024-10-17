//
//  Helpers.swift
//  mews
//
//  Created by Desmond Fitch on 10/17/24.
//

import SwiftUI

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
}
