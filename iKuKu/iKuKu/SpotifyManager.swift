//
//  SpotifyManager.swift
//  iKuKu
//
//  Created by Adrien Freire on 20/03/2025.
//

import Foundation
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
        print("CLIENT_ID: \(clientId ?? "")")
        print("CLIENT_SECRET: \(clientSecret ?? "")")
        // Open Spotify authorization URL
        guard let url = spotify.authorizationManager.makeAuthorizationURL(redirectURI: URL(string: redirectURI)!, showDialog: true, scopes: [
            .playlistModifyPrivate,
            .userModifyPlaybackState,
            .playlistReadCollaborative,
            .userReadPlaybackPosition
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

            if let response = response as? HTTPURLResponse {
                print("HTTP Status: \(response.statusCode)")
                print("Content-Type: \(response.allHeaderFields["Content-Type"] ?? "inconnu")")
                print("Réponse brute:", String(data: data, encoding: .utf8) ?? "Impossible de décoder la réponse")
            }
            if let json = try? JSONDecoder().decode(SpotifyToken.self, from: data) {
                print(json)

                self.spotify = SpotifyAPI(
                    authorizationManager: AuthorizationCodeFlowManager(
                        clientId: self.clientId ?? "",
                        clientSecret: self.clientSecret ?? "",
                        accessToken: json.accessToken,
                        expirationDate: Date().addingTimeInterval(TimeInterval(json.expiresIn)),
                        refreshToken: json.refreshToken,
                        scopes: Set(json.scope.split(separator: " ").compactMap { Scope(rawValue: String($0)) })
                    )
                )
                DispatchQueue.main.async {
                    self.isAuthenticated = true
                    self.fetchUserProfile()
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
                }
            })
            .store(in: &cancellables)
    }
}
