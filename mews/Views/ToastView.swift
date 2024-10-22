//
//  ToastView.swift
//  mews
//
//  Created by Desmond Fitch on 10/22/24.
//

import SwiftUI

struct ToastView: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .foregroundColor(.appleMusic)
            Text("Added to library")
                .fontWeight(.semibold)
                .foregroundStyle(.snow)
        }
        .fontDesign(.rounded)
        .padding()
        .background {
            Capsule()
                .fill(.oreo)
                .shadow(color: .snow.opacity(0.2), radius: 8, x: 2, y: 2)
        }
        .frame(maxWidth: .infinity)
    }
}
