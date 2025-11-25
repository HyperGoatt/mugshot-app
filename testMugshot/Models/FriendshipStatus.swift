//
//  FriendshipStatus.swift
//  testMugshot
//
//  Created as part of Friends system implementation.
//

import Foundation

enum FriendshipStatus: Equatable {
    case none
    case outgoingRequest(UUID) // request ID
    case incomingRequest(UUID) // request ID
    case friends
}

