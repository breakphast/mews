//
//  Spotlight.swift
//  mews
//
//  Created by Desmond Fitch on 11/14/24.
//

import SwiftUI

extension View {
    @ViewBuilder
    func addSpotlight(_ id: Int, shape: SpotlightShape = .rectangle, roundedRadius: CGFloat = 0, text: String = "") -> some View {
        self
            .anchorPreference(key: BoundsKey.self, value: .bounds) { [id: BoundsKeyProperties(shape: shape, anchor: $0, text: text, radius: roundedRadius)] }
    }
    
    @ViewBuilder
    func addSpotlightOverlay(show: Binding<Bool>, currentSpot: Binding<Int>) -> some View {
        self
            .overlayPreferenceValue(BoundsKey.self) { values in
                GeometryReader { proxy in
                    if let preference = values.first(where: { item in
                        item.key == currentSpot.wrappedValue
                    }) {
                        let screenSize = proxy.size
                        let anchor = proxy[preference.value.anchor]
                        
                        spotlightHelperView(screenSize: screenSize, rect: anchor, show: show, currentSpot: currentSpot, properties: preference.value)
                    }
                }
                .ignoresSafeArea()
                .animation(.easeInOut, value: show.wrappedValue)
                .animation(.easeInOut, value: currentSpot.wrappedValue)
            }
    }
    
    @ViewBuilder
    func spotlightHelperView(screenSize: CGSize, rect: CGRect, show: Binding<Bool>, currentSpot: Binding<Int>, properties: BoundsKeyProperties) -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .opacity(show.wrappedValue ? 1 : 0)
            .onTapGesture {
                // Disable the spotlight when the overlay is tapped
                if show.wrappedValue {
                    if currentSpot.wrappedValue == 2 {
                        Helpers.saveToUserDefaults("false", forKey: "firstTime")
                        show.wrappedValue = false
                    } else {
                        currentSpot.wrappedValue += 1
                    }
                }
            }
            .overlay {
                Text(properties.text)
                    .foregroundStyle(.primary)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .padding(.horizontal, 40)
                    .opacity(show.wrappedValue ? 1 : 0)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .position(
                        x: positionX(for: currentSpot.wrappedValue, rect: rect, screenSize: screenSize),
                        y: positionY(for: currentSpot.wrappedValue, rect: rect)
                    )
            }
            .mask {
                ZStack {
                    Rectangle()
                    
                    // Spotlight shape with correct positioning and blend mode
                    if properties.shape == .circle {
                        Circle()
                            .frame(width: rect.width + 20, height: rect.height + 20)
                            .position(x: rect.midX, y: rect.midY)
                            .blendMode(.destinationOut)
                    } else {
                        let cornerRadius = properties.shape == .rectangle ? 0 : properties.radius
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .frame(width: rect.width + 4, height: rect.height + 4)
                            .position(x: rect.midX, y: rect.midY)
                            .blendMode(.destinationOut)
                    }
                }
            }
            .animation(.easeInOut, value: show.wrappedValue)
    }
    
    // Helper functions for positioning text based on current spot
    
    private func positionX(for spot: Int, rect: CGRect, screenSize: CGSize) -> CGFloat {
        switch spot {
        case 2:
            // Adjusted for leading position near the bottom
            return min(rect.midX + 100, screenSize.width - 20) // Offset to the right
        case 1:
            // Adjusted for trailing position near the bottom
            return max(rect.midX - 100, 20) // Offset to the left
        default:
            // Centered position for spot 0
            return rect.midX
        }
    }
    
    private func positionY(for spot: Int, rect: CGRect) -> CGFloat {
        switch spot {
        case 1, 2:
            // Place text above the spotlight for spots near the bottom
            return rect.minY - 36
        default:
            // Place text below the spotlight for center position
            return rect.maxY + 24
        }
    }
}

struct BoundsKey: PreferenceKey {
    static var defaultValue: [Int: BoundsKeyProperties] = [:]
    
    static func reduce(value: inout [Int : BoundsKeyProperties], nextValue: () -> [Int : BoundsKeyProperties]) {
        value.merge(nextValue()) { $1 }
    }
}

struct BoundsKeyProperties {
    var shape: SpotlightShape
    var anchor: Anchor<CGRect>
    var text: String = ""
    var radius: CGFloat = 0
}

enum SpotlightShape {
    case circle
    case rectangle
    case rounded
}
