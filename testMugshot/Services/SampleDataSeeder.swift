//
//  SampleDataSeeder.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation
import CoreLocation

class SampleDataSeeder {
    static func seedSampleData(dataManager: DataManager) {
        // Only seed if there's no existing data
        guard dataManager.appData.cafes.isEmpty && dataManager.appData.visits.isEmpty else {
            return
        }
        
        // Create sample cafes with locations (SF area)
        let cafes = [
            Cafe(
                name: "Blue Bottle Coffee",
                location: CLLocationCoordinate2D(latitude: 37.7879, longitude: -122.4075),
                address: "315 Linden St, San Francisco, CA",
                isFavorite: true,
                wantToTry: false,
                averageRating: 0.0,
                visitCount: 0
            ),
            Cafe(
                name: "Sightglass Coffee",
                location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                address: "301 Divisadero St, San Francisco, CA",
                isFavorite: false,
                wantToTry: true,
                averageRating: 0.0,
                visitCount: 0
            ),
            Cafe(
                name: "Ritual Coffee Roasters",
                location: CLLocationCoordinate2D(latitude: 37.7614, longitude: -122.4244),
                address: "1026 Valencia St, San Francisco, CA",
                isFavorite: true,
                wantToTry: false,
                averageRating: 0.0,
                visitCount: 0
            ),
            Cafe(
                name: "Four Barrel Coffee",
                location: CLLocationCoordinate2D(latitude: 37.7685, longitude: -122.4217),
                address: "375 Valencia St, San Francisco, CA",
                isFavorite: false,
                wantToTry: false,
                averageRating: 0.0,
                visitCount: 0
            ),
            Cafe(
                name: "Philz Coffee",
                location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
                address: "3101 24th St, San Francisco, CA",
                isFavorite: false,
                wantToTry: false,
                averageRating: 0.0,
                visitCount: 0
            )
        ]
        
        // Add cafes
        for cafe in cafes {
            dataManager.addCafe(cafe)
        }
        
        // Create sample visits
        guard let userId = dataManager.appData.currentUser?.id else { return }
        
        var visits: [Visit] = []
        
        let visit1 = Visit(
            id: UUID(),
            cafeId: cafes[0].id,
            userId: userId,
            createdAt: Date().addingTimeInterval(-86400 * 2), // 2 days ago
            drinkType: .coffee,
            customDrinkType: nil,
            caption: "Perfect morning brew. The pour-over was exceptional!",
            notes: nil,
            photos: ["photo1"],
            posterPhotoIndex: 0,
            ratings: ["Taste": 4.5, "Vibe": 4.0, "Service": 4.5, "Value": 3.5],
            overallScore: 4.2,
            visibility: .everyone,
            likeCount: 12,
            likedByUserIds: [],
            comments: [],
            mentions: []
        )
        visits.append(visit1)
        
        let visit2 = Visit(
            id: UUID(),
            cafeId: cafes[2].id,
            userId: userId,
            createdAt: Date().addingTimeInterval(-86400 * 5), // 5 days ago
            drinkType: .matcha,
            customDrinkType: nil,
            caption: "Best matcha in the city. The atmosphere is so calming.",
            notes: nil,
            photos: ["photo2"],
            posterPhotoIndex: 0,
            ratings: ["Taste": 5.0, "Vibe": 5.0, "Service": 4.0, "Value": 4.0],
            overallScore: 4.6,
            visibility: .everyone,
            likeCount: 18,
            likedByUserIds: [],
            comments: [],
            mentions: []
        )
        visits.append(visit2)
        
        let visit3 = Visit(
            id: UUID(),
            cafeId: cafes[0].id,
            userId: userId,
            createdAt: Date().addingTimeInterval(-86400 * 10), // 10 days ago
            drinkType: .coffee,
            customDrinkType: nil,
            caption: "Quick stop for an espresso. Always reliable.",
            notes: nil,
            photos: ["photo3"],
            posterPhotoIndex: 0,
            ratings: ["Taste": 4.0, "Vibe": 3.5, "Service": 4.0, "Value": 3.0],
            overallScore: 3.7,
            visibility: .friends,
            likeCount: 5,
            likedByUserIds: [],
            comments: [],
            mentions: []
        )
        visits.append(visit3)
        
        let visit4 = Visit(
            id: UUID(),
            cafeId: cafes[3].id,
            userId: userId,
            createdAt: Date().addingTimeInterval(-86400 * 15), // 15 days ago
            drinkType: .chai,
            customDrinkType: nil,
            caption: "Tried their chai latte. Spicy and warming!",
            notes: nil,
            photos: ["photo4"],
            posterPhotoIndex: 0,
            ratings: ["Taste": 3.5, "Vibe": 4.5, "Service": 3.5, "Value": 3.5],
            overallScore: 3.7,
            visibility: .everyone,
            likeCount: 8,
            likedByUserIds: [],
            comments: [],
            mentions: []
        )
        visits.append(visit4)
        
        // Add visits (this will also update cafe stats)
        for visit in visits {
            dataManager.addVisit(visit)
        }
    }
}

