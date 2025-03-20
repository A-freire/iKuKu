//
//  Auth.swift
//  iKuKu
//
//  Created by Adrien Freire on 20/03/2025.
//

import Foundation

struct SpotifyToken: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

struct AuthCode: Decodable {
    let auth_code: String
}
