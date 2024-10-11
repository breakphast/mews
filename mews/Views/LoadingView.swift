//
//  LoadingView.swift
//  mews
//
//  Created by Desmond Fitch on 10/11/24.
//

import SwiftUI
import Lottie

struct LoadingView: View {
    var body: some View {
        LottieView(animationFileName: "loadingAnimation")
            .frame(height: UIScreen.main.bounds.width * 0.33)
    }
}

struct LottieView: UIViewRepresentable {
    var animationFileName: String
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        
    }
    
    func makeUIView(context: Context) -> Lottie.LottieAnimationView {
        let animationView = LottieAnimationView(name: animationFileName)
        animationView.loopMode = .loop
        animationView.play(fromProgress: 0.34, toProgress: 0.69, loopMode: .autoReverse)
        animationView.contentMode = .scaleAspectFill
        animationView.animationSpeed = 0.4
        return animationView
    }
}

#Preview {
    LoadingView()
}
