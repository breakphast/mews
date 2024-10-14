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
    
    var recommended: [SongModel] {
        filter { !$0.isCatalog }
    }
    
    var likedRecommended: [SongModel] {
        filter { !$0.isCatalog && $0.liked == true }
    }
    
    var dislikedRecommended: [SongModel] {
        filter { !$0.isCatalog && $0.liked == false }
    }
    
    var unusedRecommended: [SongModel] {
        filter { !$0.isCatalog && $0.liked == nil }
    }
    
    func filtered(by filter: SongModelFilter) -> [SongModel] {
        switch filter {
        case .library:
            library
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
