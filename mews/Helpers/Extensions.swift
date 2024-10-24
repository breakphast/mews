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
    func triggerToast() {
        withAnimation(.bouncy) {
            showToast = false
            showToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            withAnimation(.smooth) {
                self?.showToast = false
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
