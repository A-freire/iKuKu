//
//  TokenStore.swift
//  iKuKu
//
//  Created by Adrien Freire on 28/03/2025.
//

import Foundation
import SpotifyWebAPI

class TokenStore {
    static let key = "spotify_auth_manager"

    static func saveManager(_ manager: AuthorizationCodeFlowManager) {
        if let data = try? JSONEncoder().encode(manager) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func loadManager() -> AuthorizationCodeFlowManager? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AuthorizationCodeFlowManager.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
