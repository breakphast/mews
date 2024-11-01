//
//  Settings.swift
//  mews
//
//  Created by Desmond Fitch on 10/26/24.
//

import SwiftUI
import MusicKit
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(PlayerViewModel.self) var playerViewModel
    @Environment(CustomFilterService.self) var customFilterService
    @Environment(LibraryService.self) var libraryService
    @Environment(\.openURL) var openURL
    
    @State private var selectedPlaylist = ""
    @State private var showPlaylists = false
    
    private var customfilterActive: Bool {
        customFilterService.customFilterModel != nil
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.oreo.ignoresSafeArea()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .bold()
                    .padding()
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                    }
            }
            .tint(.snow)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing)
            
            VStack(alignment: .leading, spacing: 32) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.black)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 24) {
                            Text("Pro")
                                .font(.headline.bold())
                            button(item: .playlist, playlist: true)
                            separator
                            button(item: .upgrade)
                            separator
                            button(item: .restore)
                            separator
                        }
                        VStack(alignment: .leading, spacing: 24) {
                            Text("General")
                                .font(.headline.bold())
                            button(item: .review)
                            separator
                            button(item: .contact)
                            separator
                            button(item: .policy)
                            separator
                            button(item: .terms)
                        }
                    }
                }
            }
            .padding(.top, 48)
            .padding(.leading, 24)
            .padding(.trailing, 16)
        }
        .onAppear {
            if let playlistName: String = Helpers.getFromUserDefaults(forKey: "defaultPlaylist") {
                selectedPlaylist = playlistName
            } else if libraryService.saveToLibrary == true {
                selectedPlaylist = "Library"
            }
        }
        .onChange(of: selectedPlaylist) { _, playlistName in
            if let playlist = libraryService.playlists.first(where: {
                $0.name == playlistName
            }) {
                libraryService.activePlaylist = playlist
            } else if libraryService.saveToLibrary == true {
                selectedPlaylist = "Library"
            }
        }
        .sheet(isPresented: $showPlaylists) {
            PlaylistsView(selected: $selectedPlaylist)
        }
    }
    
    private var separator: some View {
        Divider()
            .padding(.trailing, 24)
    }
    
    private func button(item: SettingsItem, playlist: Bool = false) -> some View {
        VStack(alignment: .leading) {
            Button {
                withAnimation(.bouncy) {
                    settingsButtonAction(item: item)
                }
            } label: {
                HStack(alignment: .center, spacing: 0) {
                    Image(systemName: item.icon)
                        .font(.title2.bold())
                        .frame(width: 33, alignment: .center)
                    Text(item.text)
                    if playlist {
                        Text(selectedPlaylist)
                            .bold()
                            .lineLimit(1)
                            .foregroundStyle(customFilterService.customFilterModel == nil ? .gray : .appleMusic)
                    }
                    Spacer()
                }
            }
            .tint(.snow)
            .disabled(!customfilterActive && item == .playlist)
            .opacity(!customfilterActive && item == .playlist ? 0.5 : 1)
            .grayscale(!customfilterActive && item == .playlist ? 1 : 0)
        }
    }
    
    private func settingsButtonAction(item: SettingsItem) {
        switch item {
        case .playlist:
            showPlaylists.toggle()
        case .upgrade, .restore:
            playerViewModel.showPaywall.toggle()
            dismiss()
        case .review:
            requestAppReview()
        case .contact:
            openEmail(to: "discoSupport@gmail.com", subject: "Support Inquiry", body: "Hello, I need help with...")
        case .policy:
            openURL(URL(string: "https://www.devsmond.com")!)
        case .terms:
            openURL(URL(string: "https://www.devsmond.com")!)
        }
    }
    
    func openEmail(to recipient: String, subject: String, body: String) {
        let email = "mailto:\(recipient)?subject=\(subject)&body=\(body)"
        if let emailURL = URL(string: email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
            openURL(emailURL)
        }
    }
}

#Preview {
    SettingsView()
        .environment(PlayerViewModel())
        .environment(LibraryService(songModelManager: SongModelManager()))
}

enum SettingsItem {
    case playlist
    case upgrade
    case restore
    case review
    case contact
    case policy
    case terms
    
    var icon: String {
        switch self {
        case .playlist:
            return "plus.circle"
        case .upgrade:
            return "wand.and.stars"
        case .restore:
            return "arrow.clockwise"
        case .review:
            return "star"
        case .contact:
            return "envelope"
        case .policy:
            return "shield"
        case .terms:
            return "doc.plaintext"
        }
    }
    
    var text: String {
        switch self {
        case .playlist:
            return "Save liked songs to:  "
        case .upgrade:
            return "Upgrade to Pro"
        case .restore:
            return "Restore Purchases"
        case .review:
            return "Rate and Review"
        case .contact:
            return "Contact Us"
        case .policy:
            return "Privacy Policy"
        case .terms:
            return "Terms"
        }
    }
}
