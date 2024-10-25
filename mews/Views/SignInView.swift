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
    
    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                if let userCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                    authService.saveUserID(userCredential.user)
                    authService.appleUserID = userCredential.user
                    print(userCredential.user)
                    if userCredential.authorizedScopes.contains(.fullName) {
                        print(userCredential.fullName?.givenName ?? "No given name")
                    }
                    print(userCredential.email ?? "nino")
                    if userCredential.authorizedScopes.contains(.email) {
                        print(userCredential.email ?? "No email")
                    }
                }
            case .failure(_):
                print("Could not authenticate: \\(error.localizedDescription)")
            }
        }
        .buttonStyle(.borderedProminent)
        .clipShape(.rect(cornerRadius: 16))
        .frame(height: 60)
        .padding(.horizontal)
        .tint(.appleMusic.opacity(0.8))
    }
}

#Preview {
    SignInView()
}
