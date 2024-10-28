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
            
            VStack(spacing: 32) {
                Text("Connect Your Apple Music")
                    .font(.title2.bold())
                    .foregroundStyle(.snow)
                
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                            .background(.appleMusic.opacity(0.8), in: .rect(cornerRadius: 16))
                            .foregroundStyle(.white)
                        VStack(alignment: .leading) {
                            Text("Personalized Experience")
                                .bold()
                                .foregroundStyle(.snow)
                            Text("Recommendations based on your listening history.")
                                .foregroundStyle(.snow.opacity(0.9))
                                .font(.subheadline)
                        }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                            .background(.appleMusic.opacity(0.8), in: .rect(cornerRadius: 16))
                            .foregroundStyle(.white)
                        VStack(alignment: .leading) {
                            Text("Sync Data")
                                .bold()
                                .foregroundStyle(.snow)
                            Text("Save your preferences and data across devices.")
                                .foregroundStyle(.snow.opacity(0.9))
                                .font(.subheadline)
                        }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                            .background(.appleMusic.opacity(0.8), in: .rect(cornerRadius: 16))
                            .foregroundStyle(.white)
                        VStack(alignment: .leading) {
                            Text("Access to Premium Features")
                                .bold()
                                .foregroundStyle(.snow)
                            Text("Try out premium features for free!")
                                .foregroundStyle(.snow.opacity(0.9))
                                .font(.subheadline)
                        }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                            .background(.appleMusic.opacity(0.8), in: .rect(cornerRadius: 16))
                            .foregroundStyle(.white)
                        VStack(alignment: .leading) {
                            Text("Add to library")
                                .bold()
                                .foregroundStyle(.snow)
                            Text("Add liked songs directly to your Apple Music library")
                                .foregroundStyle(.snow.opacity(0.9))
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.top, 8)
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
}

#Preview {
    SignInView()
        .environment(AuthService())
}
