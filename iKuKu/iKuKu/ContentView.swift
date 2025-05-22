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
                WavyLineView()
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

struct WavyLineView: View {
    let bpm: Double = 120 // Ton tempo ici

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let start = CGPoint(x: 0, y: height / 2)
            let end = CGPoint(x: width, y: height / 2)
            let midX = width / 2
            let waveHeight: CGFloat = 100

            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let beatDuration = 60.0 / bpm
                let cyclesPerSecond = 1.0 / beatDuration
                let waveOffset = sin(time * .pi * 2 * cyclesPerSecond) // Oscille à chaque battement
                let midY = height / 2 + waveOffset * waveHeight
                let control = CGPoint(x: midX, y: midY)

                Path { path in
                    path.move(to: start)
                    path.addQuadCurve(to: end, control: control)
                }
                .stroke(Color.blue, lineWidth: 4)
            }
        }
    }
}
//struct TestVueSpot: View {
//    VStack {
//        Text("Bonjour, \(user.displayName ?? "Utilisateur")!")
//            .font(.title)
//            .padding()
//        if let imageURL = user.images?.first?.url.absoluteString, let url = URL(string: imageURL) {
//            AsyncImage(url: url) { image in
//                image.resizable()
//            } placeholder: {
//                ProgressView()
//            }
//            .frame(width: 150, height: 150)
//            .clipShape(Circle())
//        }
//        Button {
//            spotifyManager.getCurrentPlaybackInfo()
//        } label: {
//            Text("yollo")
//        }
//
//    }
//
//}
