//
//  SpotifyManager.swift
//  iKuKu
//
//  Created by Adrien Freire on 20/03/2025.
//

import Foundation
import SpotifyWebAPI
import SpotifyWebAPI
import Combine

class SpotifyManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userProfile: SpotifyUser?
    @Published var url: String = ""
    @Published var shortCode: String = ""

    private let clientId: String? = Bundle.main.object(forInfoDictionaryKey: "CLIENT_ID") as? String
    private let clientSecret: String? = Bundle.main.object(forInfoDictionaryKey: "CLIENT_SECRET") as? String
    private let codeVerifier: String = PKCEHelper.generateCodeVerifier()
    private let redirectURI: String = "http://192.168.1.14:8080"
    private var spotify = SpotifyAPI(
        authorizationManager: AuthorizationCodeFlowManager(
            clientId: Bundle.main.object(forInfoDictionaryKey: "CLIENT_ID") as? String ?? "",
            clientSecret: Bundle.main.object(forInfoDictionaryKey: "CLIENT_SECRET") as? String ?? ""
        )
    )
    private var cancellables: Set<AnyCancellable> = []

    var isCodeValid: Bool {
        shortCode.count == 6 ? false : true
    }

    /// Generate URL
    func authorize() {
        if let manager = TokenStore.loadManager() {
            self.spotify = SpotifyAPI(authorizationManager: manager)
            DispatchQueue.main.async {
                self.isAuthenticated = true
                self.fetchUserProfile()
            }
            return
        }
        // Open Spotify authorization URL
        guard let url = spotify.authorizationManager.makeAuthorizationURL(redirectURI: URL(string: redirectURI)!, showDialog: true, scopes: [
            .playlistModifyPrivate,
            .userModifyPlaybackState,
            .playlistReadCollaborative,
            .userReadPlaybackPosition,
            .userReadCurrentlyPlaying,
            .userReadPlaybackState,
            .streaming,
        ]) else { return }

        self.url = url.absoluteString
    }

    ///Fetch the accesstoken
    func fetchTokens() {
        guard !shortCode.isEmpty else { print("Code long error"); return }

        let url = URL(string: redirectURI+"/get-auth-code/\(shortCode)")
        let requesdt = URLRequest(url: url!)

        let task = URLSession.shared.dataTask(with: requesdt) { data, response, error in
            guard let data = data else {
                print("Erreur: \(error?.localizedDescription ?? "Erreur inconnue")")
                return
            }

            if let json = try? JSONDecoder().decode(AuthCode.self, from: data) {
                print(json.auth_code)
                self.fetchSpotifyAccessToken(code: json.auth_code)
            }

        }
        task.resume()
    }

    // Échange du code d'authentification contre un Access Token
    func fetchSpotifyAccessToken(code: String) {
        let tokenUrl = URL(string: "https://accounts.spotify.com/api/token")!

        var request = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"

        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientId ?? "",
            "client_secret": clientSecret ?? "",
            "code_verifier": codeVerifier
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) {
            data,
            response,
            error in
            guard let data = data,
                  error == nil else {
                print("Erreur: \(error?.localizedDescription ?? "Erreur inconnue")")
                return
            }

            //            if let response = response as? HTTPURLResponse {
            //                print("HTTP Status: \(response.statusCode)")
            //                print("Content-Type: \(response.allHeaderFields["Content-Type"] ?? "inconnu")")
            //                print("Réponse brute:", String(data: data, encoding: .utf8) ?? "Impossible de décoder la réponse")
            //            }
            if let json = try? JSONDecoder().decode(SpotifyToken.self, from: data) {
                print(json)

                let authManager = AuthorizationCodeFlowManager(
                    clientId: self.clientId ?? "",
                    clientSecret: self.clientSecret ?? "",
                    accessToken: json.accessToken,
                    expirationDate: Date().addingTimeInterval(TimeInterval(json.expiresIn)),
                    refreshToken: json.refreshToken,
                    scopes: Set(json.scope.split(separator: " ").compactMap { Scope(rawValue: String($0)) })
                )

                self.spotify = SpotifyAPI(authorizationManager: authManager)

                DispatchQueue.main.async {
                    self.isAuthenticated = true
                    self.fetchUserProfile()
                    TokenStore.saveManager(authManager)
                }
            }
        }
        task.resume()
    }

    func fetchUserProfile() {
        spotify.currentUserProfile()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error fetching user profile: \(error)")
                }
            }, receiveValue: { profile in
                DispatchQueue.main.async {
                    self.userProfile = profile
                    self.getCurrentPlaybackInfo()
                }
            })
            .store(in: &cancellables)
    }
}

extension SpotifyManager {
    func getCurrentPlaybackInfo() {
        spotify.currentPlayback()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Erreur currentPlayback : \(error)")
                }
            }, receiveValue: { playback in
                guard let item = playback?.item else {
                    print("Aucune lecture en cours")
                    return
                }

                switch item {
                case .track(let track):
                    let artist = track.artists?.first?.name ?? "Inconnu"
                    let name = track.name
                    let isPlaying = playback?.isPlaying ?? false
                    print("🎧 \(name) - \(artist) | En cours : \(isPlaying ? "✅" : "⏸")")
                default:
                    print("Contenu non musical")
                }
            })
            .store(in: &cancellables)
    }

    func getNextTrack() {
        spotify.queue()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Erreur lors de la récupération de la file d’attente : \(error)")
                }
            }, receiveValue: { queue in
                if let nextTrack = queue.queue.first {
                    let name = nextTrack.name
                    print("⏭ Prochaine musique : \(name ?? "")")
                    //                    DispatchQueue.main.async {
                    //                        self.nextTrackInfo = "\(name)"
                    //                    }
                } else {
                    print("🎶 Aucun morceau dans la file d’attente")
                    //                    DispatchQueue.main.async {
                    //                        self.nextTrackInfo = "Aucune musique dans la file d’attente"
                    //                    }
                }
            })
            .store(in: &cancellables)
    }

    func getTrack(uri: String) {
        spotify.track(uri)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Erreur récupération track : \(error)")
                }
            }, receiveValue: { track in
                print("🎧 Track retrouvé : \(track.name) - \(track.artists?.first?.name ?? "Inconnu")")
            })
            .store(in: &cancellables)
    }

    func getTracks(from uris: [String]) {
        spotify.tracks(uris)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Erreur récupération de plusieurs tracks : \(error)")
                }
            }, receiveValue: { tracksPage in
                for track in tracksPage {
                    if let track = track {
                        let name = track.name
                        let artist = track.artists?.first?.name ?? "Inconnu"
                        print("🎧 \(name) - \(artist)")
                    }
                }
            })
            .store(in: &cancellables)
    }
}
