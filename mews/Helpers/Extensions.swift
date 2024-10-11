//
//  Extensions.swift
//  mews
//
//  Created by Desmond Fitch on 10/11/24.
//

import SwiftUI

extension Array where Element == SongModel {
    var library: [SongModel] {
        filter { $0.isCatalog }
    }
    
    var usedLibrary: [SongModel] {
        library.filter { $0.usedForSeed }
    }
    
    var unusedLibrary: [SongModel] {
        library.filter { !$0.usedForSeed }
    }
    
    var recommended: [SongModel] {
        filter { !$0.isCatalog }
    }
    
    var likedRecommended: [SongModel] {
        recommended.filter { $0.liked == true }
    }
    
    var dislikedRecommended: [SongModel] {
        recommended.filter { $0.liked == false }
    }
    
    var unusedRecommended: [SongModel] {
        recommended.filter { $0.liked == nil }
    }
    
    func filtered(by filter: SongModelFilter) -> [SongModel] {
        switch filter {
        case .library:
            library
        case .usedLibrary:
            usedLibrary
        case .unusedLibrary:
            unusedLibrary
        case .recommended:
            recommended
        case .likedRecommended:
            likedRecommended
        case .dislikedRecommended:
            dislikedRecommended
        case .unusedRecommended:
            unusedRecommended
        }
    }
}
