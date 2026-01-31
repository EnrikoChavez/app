//
//  APIConfig.swift
//  ai_anti_doomscroll
//
//  Created by Enriko Chavez on 8/24/25.
//
import Foundation

enum APIConfig {
    static var baseURL: String {
       Shared.defaults.set("https://ds-sqxf.onrender.com", forKey: Shared.baseURLKey)
        // Shared.defaults.set("http://192.168.1.159:8000", forKey: Shared.baseURLKey)
        return Shared.defaults.string(forKey: Shared.baseURLKey)
        ?? "IMPOSSIBLE"
    }
    static func url(_ path: String) -> URL? {
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let p = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: "\(base)\(p)")
    }
}
