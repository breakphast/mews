//
//  PlaylistRow.swift
//  mews
//
//  Created by Desmond Fitch on 10/28/24.
//

import SwiftUI
import MusicKit

struct PlaylistRow: View {
    @Environment(LibraryService.self) var libraryService
    let playlist: Playlist
    
    var textColor: Color {
        if libraryService.activePlaylist == playlist {
            return .appleMusic
        } else {
            return .snow
        }
    }
    
    var body: some View {
        HStack {
            Text(playlist.name)
                .foregroundStyle(textColor)
                .font(.title3)
            Spacer()
        }
        .padding(.vertical, 4)
        .fontWeight(.semibold)
    }
}
