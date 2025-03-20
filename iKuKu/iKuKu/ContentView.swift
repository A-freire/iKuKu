//
//  ContentView.swift
//  iKuKu
//
//  Created by Adrien Freire on 22/01/2025.
//

import SwiftUI
        
struct ContentView: View {
    @StateObject private var spotifyManager = SpotifyManager()

    var body: some View {
        VStack {
            if spotifyManager.isAuthenticated, let user = spotifyManager.userProfile {
                VStack {
                    Text("Bonjour, \(user.displayName ?? "Utilisateur")!")
                        .font(.title)
                        .padding()
                    if let imageURL = user.images?.first?.url.absoluteString, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                    }
                }
            } else {
                VStack {
                    QRCodeGeneratorView(text: $spotifyManager.url)
                        .padding()
                    TextField("Code Spotify", text: $spotifyManager.shortCode)
                    .padding()
                    Button("Valider") {
                        spotifyManager.fetchTokens()
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(spotifyManager.isCodeValid)
                }
                .task {
                    spotifyManager.authorize()
                }
            }
        }
    }
}
