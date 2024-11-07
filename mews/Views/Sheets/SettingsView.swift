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
    @Environment(AuthService.self) var authService
    @Environment(\.openURL) var openURL
    
    @State private var selectedPlaylist = ""
    @State private var showPlaylists = false
    @State private var showDeleteSheet = false
    @State private var showDeletePrompt = false
    @State private var deletedAccount = false
    
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
                            separator
                            button(item: .delete)
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
        .sheet(isPresented: $showDeleteSheet, onDismiss: {
            if deletedAccount {
                deleteAccountLocally()
                print("Dismissed and deleted account part 2.")
            }
        }, content: {
            deleteInstructions
        })
        .sheet(isPresented: $showDeleteSheet) {
            deleteInstructions
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
            openURL(URL(string: "https://github.com/breakphast/DiscoMuse/blob/main/PrivacyPolicy.md")!)
        case .terms:
            openURL(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
        case .delete:
            showDeleteSheet.toggle()
            
        }
    }
    
    private var deleteInstructions: some View {
        VStack(spacing: 48) {
            Text("Account Deletion Instructions")
                .font(.title3)
                .fontWeight(.heavy)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("1. Open the **Settings** app.")
                Text("2. Tap on **Apple ID** (your name at the top).")
                Text("3. Select **Sign in with Apple**.")
                Text("4. Find **DiscoMuse or Mews** in the list.")
                Text("5. Tap **Delete** to remove access.")
            }
            
            Text("Pressing **Delete & Open Settings** will first remove your data locally from this device, and then open the Apple ID settings for you to proceed with the deletion.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { showDeletePrompt.toggle() }) {
                Text("Delete & Open Settings")
                    .bold()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .alert(isPresented: $showDeletePrompt) {
                Alert(
                    title: Text("Confirm Deletion"),
                    message: Text("Are you sure you want to delete your account from this device? This action will remove your information locally, and you will be logged out."),
                    primaryButton: .destructive(Text("Delete & Open Settings")) {
                        deletedAccount = true
                        openSettings()
                        dismiss()
                        print("Dismissed and deleted account.")
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal)
    }
    
    private func deleteAccountLocally() {
        playerViewModel.pauseAvPlayer()
        authService.appleUserID = nil
        authService.status = .notDetermined
        Helpers.deleteFromUserDefaults(forKey: "appleUserID")
    }
    
    private func openSettings() {
        if let url = URL(string: "App-Prefs:prefs:root=ACCESSIBILITY") {
            openURL(url)
        } else {
            print("Unable to open Apple ID settings.")
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
        .environment(AuthService())
        .environment(CustomFilterService(songModelManager: SongModelManager(), spotifyTokenManager: SpotifyTokenManager()))
}

enum SettingsItem {
    case playlist
    case upgrade
    case restore
    case review
    case contact
    case policy
    case terms
    case delete
    
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
        case .delete:
            return "trash"
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
        case .delete:
            return "Remove Apple Account"
        }
    }
}
