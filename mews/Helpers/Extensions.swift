//
//  Extensions.swift
//  mews
//
//  Created by Desmond Fitch on 10/11/24.
//

import SwiftUI

extension Array where Element == SongModel {
    var library: [SongModel] {
        filter { $0.isCatalog && !$0.custom }
    }
    
    var recommended: [SongModel] {
        filter { !$0.isCatalog && !$0.custom }
    }
    
    var customRecommended: [SongModel] {
        filter { !$0.isCatalog && $0.custom }
    }
    
    func filtered(by filter: SongModelFilter) -> [SongModel] {
        switch filter {
        case .library:
            library
        case .recommended:
            recommended
        case .customRecommended:
            customRecommended
        }
    }
}

extension View {
    func onOrientationChange(isLandscape: Binding<Bool>) -> some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                self.modifier(OrientationChangeModifier(isLandscape: isLandscape))
            } else {
                self
            }
        }
    }
}

extension PlayerViewModel {
    func triggerToast(type: ToastType) {
        withAnimation(.bouncy) {
            switch type {
            case .addedToLibrary:
                showAddedToast = false
                showAddedToast = true
            case .limitReached:
                showLimitToast = false
                showLimitToast = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            withAnimation(.smooth) {
                switch type {
                case .addedToLibrary:
                    self?.showAddedToast = false
                case .limitReached:
                    self?.showLimitToast = false
                }
            }
        }
    }
    
    func triggerFilters() {
        withAnimation(.bouncy.speed(0.5)) {
            showFilters.toggle()
            return
        }
    }
    
    func play() {
        avPlayer.play()
        isAvPlaying = true
    }
    
    func pauseAvPlayer() {
        avPlayer.pause()
        isAvPlaying = false
    }
}
