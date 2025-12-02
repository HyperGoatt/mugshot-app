//
//  MugshotError.swift
//  testMugshot
//
//  User-friendly error types for Mugshot app
//

import Foundation

enum MugshotError: LocalizedError {
    case userFriendly(String)
    
    var errorDescription: String? {
        switch self {
        case .userFriendly(let message):
            return message
        }
    }
}

