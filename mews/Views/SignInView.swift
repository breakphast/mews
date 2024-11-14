//
//  SignInView.swift
//  mews
//
//  Created by Desmond Fitch on 10/25/24.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AuthService.self) var authService
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                VStack(spacing: 4) {
                    Image(.appIconTinted)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100)
                    Text("DiscoMuse")
                        .fontWeight(.black)
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .kerning(2)
                }
            }
            .frame(maxHeight: 200)
            .background(Color.appleMusic.opacity(0.9).gradient)
            
            Spacer()
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Connect Your Apple Music")
                        .font(.title2.bold())
                    Text("Unlock DiscoMuse’s complete potential—personalized just for Apple Music users.")
                        .font(.subheadline)
                        .padding(.horizontal, 40)
                        .multilineTextAlignment(.center)
                }
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.snow)
                VStack(alignment: .leading, spacing: 24) {
                    featureElement(icon: "person.crop.circle", title: "Personalized Experience", description: "Recommendations based on your listening history.")
                    featureElement(icon: "plus.circle", title: "Add to library", description: "Add liked songs directly to your Apple Music library.")
                    featureElement(icon: "wand.and.stars", title: "Premium Features", description: "Full access to PRO features.")
                    featureElement(icon: "headphones.circle", title: "Use Without Apple Music", description: "Apple Music unlocks more, but it’s not required.")
                }
                .padding(.horizontal)
            }
            .padding(.horizontal)
            
            Spacer()
            signInButton
            Spacer()
        }
        .background {
            Color.oreo.ignoresSafeArea()
        }
    }
    
    private var signInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                if let userCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                    Helpers.saveToUserDefaults(userCredential.user, forKey: "appleUserID")
                    authService.appleUserID = userCredential.user
                }
            case .failure(_):
                print("Could not authenticate: \\(error.localizedDescription)")
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 24)
        .signInWithAppleButtonStyle(.whiteOutline)
    }
    
    private func featureElement(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3.bold())
                .frame(width: 44, height: 44)
                .background(.appleMusic.opacity(0.8), in: .rect(cornerRadius: 16))
                .foregroundStyle(.white)
            VStack(alignment: .leading) {
                Text(title)
                    .bold()
                    .foregroundStyle(.snow)
                Text(description)
                    .foregroundStyle(.snow.opacity(0.9))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    SignInView()
        .environment(AuthService())
}
