//
//  SpotifyAuthView.swift
//  iKuKu
//
//  Created by Adrien Freire on 05/02/2025.
//

import SwiftUI
import Combine
import CoreImage.CIFilterBuiltins

struct SpotifyAuthView: View {
    @StateObject private var webServer = TVWebServerNIO()
    @State private var accessToken: String? = nil
    @State private var trackTitle: String = "Aucune musique en cours"
    @State private var artistName: String = ""
    @State private var albumArt: UIImage? = nil
    @State private var authCode: String? = nil
    @State private var isAuthenticated = false
    @State private var timer: Timer? = nil
    @State private var ipAddress: String = ""

    let clientId = "80cfbeb8de764c488707ec844293070a"
    let codeVerifier = ""

    var body: some View {
        VStack {
            if !isAuthenticated, !ipAddress.isEmpty {
                QRCodeGeneratorView(text: webServer.authURL)
                    .padding()

                Text("Scannez le QR Code avec votre téléphone pour vous connecter à Spotify")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()

                Text("Une fois connecté, entrez le code reçu ici :")
                    .font(.subheadline)

                TextField("Code Spotify", text: Binding(
                    get: { self.authCode ?? "" },
                    set: { self.authCode = $0 }
                ))
//                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

                Button("Valider") {
                    if let code = authCode {
                        fetchSpotifyAccessToken(authCode: code)
                    }
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            } else {
                


                //            } else {
                //                VStack {
                //                    if let image = albumArt {
                //                        Image(uiImage: image)
                //                            .resizable()
                //                            .scaledToFit()
                //                            .frame(width: 200, height: 200)
                //                            .cornerRadius(10)
                //                            .padding()
                //                    }
                //
                //                    Text(trackTitle)
                //                        .font(.title)
                //                        .bold()
                //                        .multilineTextAlignment(.center)
                //                        .padding()
                //
                //                    Text(artistName)
                //                        .font(.headline)
                //                        .foregroundColor(.gray)
                //
                //                    Button("Rafraîchir") {
                //                        getCurrentSpotifyTrack()
                //                    }
                //                    .padding()
                //                    .background(Color.blue)
                //                    .foregroundColor(.white)
                //                    .cornerRadius(10)
                //                }
                //                .onAppear {
                //                    startTimer()
                //                }
                //            }
            }
        }
        .padding()
        .task {
            fetchLocalIPAddress()
            webServer.start(ipAddress: ipAddress)
        }
    }

    // Générer un QR Code
    func generateQRCode(from string: String) -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")

        if let outputImage = filter.outputImage {
            let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
            return UIImage(ciImage: transformedImage)
        }

        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }

    // Vue pour afficher le QR Code
    struct QRCodeView: View {
        let url: String

        var body: some View {
            Image(uiImage: generateQRCode(from: url))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 250, height: 250)
        }

        func generateQRCode(from string: String) -> UIImage {
            let filter = CIFilter.qrCodeGenerator()
            let data = Data(string.utf8)
            filter.setValue(data, forKey: "inputMessage")

            if let outputImage = filter.outputImage {
                let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
                return UIImage(ciImage: transformedImage)
            }

            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }
    }

    // Échange du code d'authentification contre un Access Token
    func fetchSpotifyAccessToken(authCode: String) {

        guard let decrytedCode = decodeShortCode(authCode) else { print("Code long error"); return }

        let tokenUrl = URL(string: "https://accounts.spotify.com/api/token")!

        var request = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"

        let bodyParams = [
            "grant_type": "authorization_code",
            "code": decrytedCode,
            "redirect_uri": webServer.redirectUri,
            "client_id": clientId,
            "code_verifier": codeVerifier
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Erreur: \(error?.localizedDescription ?? "Erreur inconnue")")
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let token = json["access_token"] as? String {
                DispatchQueue.main.async {
                    self.accessToken = token
                    self.isAuthenticated = true
                    self.getCurrentSpotifyTrack()
                }
            }
        }

        task.resume()
    }

    // Récupérer la musique en cours de lecture
    func getCurrentSpotifyTrack() {
        guard let token = accessToken else { return }

        let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Erreur: \(error?.localizedDescription ?? "Erreur inconnue")")
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let item = json["item"] as? [String: Any],
               let trackName = item["name"] as? String,
               let artists = item["artists"] as? [[String: Any]],
               let firstArtist = artists.first?["name"] as? String {

                DispatchQueue.main.async {
                    self.trackTitle = trackName
                    self.artistName = firstArtist
                }
            }
        }

        task.resume()
    }

    // Rafraîchissement automatique toutes les 5 secondes
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            getCurrentSpotifyTrack()
        }
    }

    // Decode code
    func decodeShortCode(_ shortCode: String) -> String? {
        // Compléter le shortCode avec des "=" pour rétablir Base64
        let paddedCode = shortCode.padding(toLength: 8, withPad: "=", startingAt: 0)

        // Décoder en Base64
        guard let data = Data(base64Encoded: paddedCode, options: .ignoreUnknownCharacters),
              let decodedString = String(data: data, encoding: .utf8) else {
            return nil
        }

        return decodedString
    }

    private func fetchLocalIPAddress() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == AF_INET {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" { // Interface Wi-Fi sur iPhone
                        var addr = interface.ifa_addr.pointee
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                            ipAddress = String(cString: hostname)
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
    }
}
