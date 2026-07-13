//
//  FeedScope.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation

enum FeedScope: CaseIterable, Equatable {
    case ranked
    case friends
    case everyone
    
    var displayName: String {
        switch self {
        case .ranked: return "For You"
        case .friends: return "Friends"
        case .everyone: return "Everyone"
        }
    }

    var rpcValue: String {
        switch self {
        case .ranked: return "ranked"
        case .friends: return "friends"
        case .everyone: return "everyone"
        }
    }
}
