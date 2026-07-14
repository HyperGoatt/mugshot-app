//
//  User.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    var username: String
    var displayName: String? // Optional display name
    var location: String
    var avatarImageName: String? // For now, store image name/path
    var bio: String
    
    init(
        id: UUID = UUID(),
        username: String,
        displayName: String? = nil,
        location: String,
        avatarImageName: String? = nil,
        bio: String = ""
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.location = location
        self.avatarImageName = avatarImageName
        self.bio = bio
    }
    
    // Computed property for display
    var displayNameOrUsername: String {
        displayName ?? username
    }
}

