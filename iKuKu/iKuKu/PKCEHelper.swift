//
//  PKCEHelper.swift
//  iKuKu
//
//  Created by Adrien Freire on 20/03/2025.
//

import Foundation
import CryptoKit

struct PKCEHelper {
    static func generateCodeVerifier() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        return String((0..<128).map { _ in characters.randomElement()! })
    }
}
