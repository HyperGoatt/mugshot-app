//
//  FriendRequest.swift
//  testMugshot
//
//  Created as part of Friends system implementation.
//

import Foundation

struct FriendRequest: Identifiable {
    let id: UUID
    let fromUserId: String
    let toUserId: String
    let status: FriendRequestStatus
    let createdAt: Date
    
    var isPending: Bool {
        status == .pending
    }
    
    func isIncoming(currentUserId: String) -> Bool {
        // Incoming means "toUserId" is the current user
        return toUserId == currentUserId
    }
}

extension FriendRequest {
    init(from remote: RemoteFriendRequest) {
        self.id = remote.id
        self.fromUserId = remote.fromUserId
        self.toUserId = remote.toUserId
        self.status = remote.status
        self.createdAt = remote.createdAt ?? Date()
    }
}

