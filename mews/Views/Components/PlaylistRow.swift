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
    @Environment(\.dismiss) var dismiss
    @Binding var selected: String
    
    let playlist: Playlist?
    var library: Bool? = nil
    
    var textColor: Color {
        if libraryService.activePlaylist == playlist {
            return .appleMusic.opacity(0.9)
        } else {
            return .snow
        }
    }
    
    var title: String {
        if let playlist {
            return playlist.name
        } else if library == true {
            return "No Playlist"
        }
        return ""
    }
    
    var icon: String {
        if libraryService.activePlaylist == playlist {
            "square.fill"
        } else if library == true && libraryService.saveToLibrary == true {
            "square.fill"
        } else {
            "square"
        }
    }
    
    var body: some View {
        Button {
            if let playlist {
                libraryService.saveToLibrary = nil
                Helpers.deleteFromUserDefaults(forKey: "saveToLibrary")
                libraryService.activePlaylist = playlist
                selected = playlist.name
                Helpers.saveToUserDefaults(playlist.name, forKey: "defaultPlaylist")
                withAnimation(.bouncy) {
                    dismiss()
                }
            } else {
                libraryService.saveToLibrary = true
                libraryService.activePlaylist = nil
                selected = "Library"
                Helpers.deleteFromUserDefaults(forKey: "defaultPlaylist")
                Helpers.saveToUserDefaults("Library", forKey: "saveToLibrary")
                withAnimation(.bouncy) {
                    dismiss()
                }
            }
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(textColor)
                Spacer()
                Image(systemName: icon)
                    .foregroundStyle(textColor)
                    .bold()
            }
            .padding(.vertical, 4)
            .padding(.trailing)
            .fontWeight(.semibold)
        }
    }
}
