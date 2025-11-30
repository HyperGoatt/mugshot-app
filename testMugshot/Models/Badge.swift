//
//  Badge.swift
//  testMugshot
//
//  Badge model types and definitions for the coffee-themed badge system.
//

import Foundation

// MARK: - Badge Category

enum BadgeCategory: String, CaseIterable {
    case milestone = "Milestone"
    case streak = "Streak"
    case exploration = "Exploration"
    case journal = "Journal"
    case variety = "Variety"
    case timeOfDay = "Time of Day"
    
    var displayName: String { rawValue }
    
    var sortOrder: Int {
        switch self {
        case .milestone: return 0
        case .streak: return 1
        case .exploration: return 2
        case .journal: return 3
        case .variety: return 4
        case .timeOfDay: return 5
        }
    }
}

// MARK: - Badge Definition

struct BadgeDefinition {
    let id: String
    let name: String
    let description: String
    let category: BadgeCategory
    let iconName: String
    let targetValue: Int?
    
    /// Human-readable explanation of how to unlock this badge
    var unlockHint: String {
        switch id {
        case "first_pour":
            return "Log your first visit to any cafe."
        case "steady_sipper":
            return "Log 10 visits to cafes."
        case "regular":
            return "Log 25 visits to cafes."
        case "weekend_warrior":
            return "Log visits on 2 consecutive weekends."
        case "daily_drip_7":
            return "Maintain a 7-day visit streak."
        case "neighborhood_sipper":
            return "Visit 3 different cafes."
        case "cafe_explorer":
            return "Visit 10 different cafes."
        case "thoughtful_sipper":
            return "Add notes to 3 of your visits."
        case "coffee_chronicler":
            return "Add notes to 10 of your visits."
        case "adventurous_palate":
            return "Try 3 different drink types."
        case "early_bird_brew":
            return "Log 5 visits before 9am."
        default:
            return description
        }
    }
}

// MARK: - Badge State

struct BadgeState: Identifiable {
    let definition: BadgeDefinition
    let isUnlocked: Bool
    let currentValue: Int
    let targetValue: Int?
    
    var id: String { definition.id }
    
    /// Progress from 0.0 to 1.0
    var progress: Double {
        guard let target = targetValue, target > 0 else {
            return isUnlocked ? 1.0 : 0.0
        }
        return min(1.0, Double(currentValue) / Double(target))
    }
    
    /// Progress text for display (e.g., "3/10 visits" or "Unlocked")
    var progressText: String {
        if isUnlocked {
            return "Unlocked"
        }
        guard let target = targetValue else {
            return "Locked"
        }
        return "\(currentValue)/\(target)"
    }
}

// MARK: - Badge Definitions Library

extension BadgeDefinition {
    
    /// All available badge definitions
    static let all: [BadgeDefinition] = [
        // Milestone / visit count
        BadgeDefinition(
            id: "first_pour",
            name: "First Pour",
            description: "Logged your first Mugshot visit.",
            category: .milestone,
            iconName: "cup.and.saucer.fill",
            targetValue: 1
        ),
        BadgeDefinition(
            id: "steady_sipper",
            name: "Steady Sipper",
            description: "Logged 10 visits.",
            category: .milestone,
            iconName: "mug.fill",
            targetValue: 10
        ),
        BadgeDefinition(
            id: "regular",
            name: "Regular",
            description: "Logged 25 visits.",
            category: .milestone,
            iconName: "star.fill",
            targetValue: 25
        ),
        
        // Streaks / consistency
        BadgeDefinition(
            id: "weekend_warrior",
            name: "Weekend Warrior",
            description: "Logged visits on 2 consecutive weekends.",
            category: .streak,
            iconName: "sun.max.fill",
            targetValue: 2
        ),
        BadgeDefinition(
            id: "daily_drip_7",
            name: "Daily Drip (7)",
            description: "7-day visit streak.",
            category: .streak,
            iconName: "flame.fill",
            targetValue: 7
        ),
        
        // Exploration / cafes
        BadgeDefinition(
            id: "neighborhood_sipper",
            name: "Neighborhood Sipper",
            description: "Visited 3 unique cafes.",
            category: .exploration,
            iconName: "map.fill",
            targetValue: 3
        ),
        BadgeDefinition(
            id: "cafe_explorer",
            name: "Cafe Explorer",
            description: "Visited 10 unique cafes.",
            category: .exploration,
            iconName: "globe.americas.fill",
            targetValue: 10
        ),
        
        // Journaling / notes
        BadgeDefinition(
            id: "thoughtful_sipper",
            name: "Thoughtful Sipper",
            description: "Added notes to 3 visits.",
            category: .journal,
            iconName: "pencil.line",
            targetValue: 3
        ),
        BadgeDefinition(
            id: "coffee_chronicler",
            name: "Coffee Chronicler",
            description: "Added notes to 10 visits.",
            category: .journal,
            iconName: "book.fill",
            targetValue: 10
        ),
        
        // Variety / drink style
        BadgeDefinition(
            id: "adventurous_palate",
            name: "Adventurous Palate",
            description: "Logged 3 different drink types.",
            category: .variety,
            iconName: "sparkles",
            targetValue: 3
        ),
        
        // Time / vibe
        BadgeDefinition(
            id: "early_bird_brew",
            name: "Early Bird Brew",
            description: "Logged 5 visits before 9am.",
            category: .timeOfDay,
            iconName: "sunrise.fill",
            targetValue: 5
        )
    ]
    
    /// Get a badge definition by ID
    static func find(id: String) -> BadgeDefinition? {
        all.first { $0.id == id }
    }
}

