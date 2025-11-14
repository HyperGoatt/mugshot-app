//
//  FeedScope.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation

enum FeedScope: CaseIterable {
    case friends
    case everyone
    
    var displayName: String {
        switch self {
        case .friends: return "Friends"
        case .everyone: return "Everyone"
        }
    }
}

