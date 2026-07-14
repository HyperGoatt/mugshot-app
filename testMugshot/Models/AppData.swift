//
//  AppData.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation

// Container for all app data
struct AppData: Codable {
    var currentUser: User?
    var cafes: [Cafe]
    var visits: [Visit]
    var ratingTemplate: RatingTemplate
    var hasCompletedOnboarding: Bool
    
    init(
        currentUser: User? = nil,
        cafes: [Cafe] = [],
        visits: [Visit] = [],
        ratingTemplate: RatingTemplate = RatingTemplate(),
        hasCompletedOnboarding: Bool = false
    ) {
        self.currentUser = currentUser
        self.cafes = cafes
        self.visits = visits
        self.ratingTemplate = ratingTemplate
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

