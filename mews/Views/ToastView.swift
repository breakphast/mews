//
//  ToastView.swift
//  mews
//
//  Created by Desmond Fitch on 10/22/24.
//

import SwiftUI

struct ToastView: View {
    @Environment(\.colorScheme) var colorScheme
    let type: ToastType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type == .addedToLibrary ? "heart.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(type == .addedToLibrary ? .appleMusic : .red)
            Text(type == .addedToLibrary ? "Added to library" : "Browse limit reached")
                .fontWeight(.semibold)
                .foregroundStyle(.snow)
        }
        .fontDesign(.rounded)
        .padding()
        .background {
            Capsule()
                .fill(.oreo)
                .shadow(color: .snow.opacity(colorScheme == .light ? 0.2 : 0.05), radius: 6, x: 2, y: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

enum ToastType {
    case addedToLibrary
    case limitReached
}
