//
//  CustomPicker.swift
//  mews
//
//  Created by Desmond Fitch on 10/19/24.
//

import SwiftUI

struct CustomPicker: View {
    @Namespace var animation
    @Binding var activeSeed: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            pickerOption(title: "Artist", seed: .artist)
            pickerOption(title: "Genre", seed: .genre)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func pickerOption(title: String, seed: SeedOption) -> some View {
        Text(title)
            .bold()
            .padding(.vertical, 8)
            .padding(.horizontal, 24)
            .background {
                ZStack {
                    if activeSeed == seed.rawValue {
                        Color.oreo.cornerRadius(12)
                            .shadow(color: .snow.opacity(colorScheme == .light ? 0.1 : 0.05), radius: 4, x: seed == .artist ? 2 : -2, y: 2)
                            .matchedGeometryEffect(id: "SEED", in: animation)
                    }
                }
            }
            .foregroundStyle(activeSeed == seed.rawValue ? .appleMusic.opacity(0.7) : .gray)
            .onTapGesture {
                withAnimation(.bouncy) {
                    activeSeed = seed.rawValue
                }
            }
    }
}

#Preview {
    CustomPicker(activeSeed: .constant(SeedOption.artist.rawValue))
}
