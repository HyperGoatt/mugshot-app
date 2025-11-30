//
//  FeedScope.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation

enum FeedScope: CaseIterable {
    case friends
    case discover
    case everyone
    
    var displayName: String {
        switch self {
        case .friends: return "Friends"
        case .discover: return "Discover"
        case .everyone: return "Everyone"
        }
    }
}

