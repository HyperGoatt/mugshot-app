//
//  RatingTemplate.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import Foundation

struct RatingCategory: Identifiable, Codable {
    let id: UUID
    var name: String
    var weight: Double // 0.0 to 1.0, should sum to 1.0 across all categories
    
    init(id: UUID = UUID(), name: String, weight: Double) {
        self.id = id
        self.name = name
        self.weight = weight
    }
}

struct RatingTemplate: Codable {
    var categories: [RatingCategory]
    
    init(categories: [RatingCategory] = RatingTemplate.defaultCategories()) {
        // Don't normalize on init - store as raw multipliers
        self.categories = categories
    }
    
    static func defaultCategories() -> [RatingCategory] {
        return [
            RatingCategory(name: "Presentation", weight: 1.0),
            RatingCategory(name: "Value", weight: 1.0),
            RatingCategory(name: "Taste", weight: 1.0),
            RatingCategory(name: "Ambiance", weight: 1.0)
        ]
    }
    
    func calculateOverallScore(ratings: [String: Double]) -> Double {
        // Normalize weights for calculation
        let normalizedWeights = getNormalizedWeights()
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        for (index, category) in categories.enumerated() {
            if let rating = ratings[category.name] {
                let normalizedWeight = normalizedWeights[index]
                weightedSum += rating * normalizedWeight
                totalWeight += normalizedWeight
            }
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : 0.0
    }
    
    // Get normalized weights for calculation (sum to 1.0)
    private func getNormalizedWeights() -> [Double] {
        let total = categories.reduce(0.0) { $0 + $1.weight }
        guard total > 0 else { return categories.map { _ in 1.0 / Double(categories.count) } }
        return categories.map { $0.weight / total }
    }
    
    // Get weight multiplier for display (1x, 1.5x, 2x, etc.)
    func getWeightMultiplier(for category: RatingCategory) -> Double {
        guard !categories.isEmpty else { return 1.0 }
        let minWeight = categories.map { $0.weight }.min() ?? 1.0
        if minWeight > 0 {
            return category.weight / minWeight
        }
        return 1.0
    }
    
    // Normalize weights (kept for backward compatibility, but weights are stored as multipliers)
    mutating func normalizeWeights() {
        // Weights are stored as multipliers and normalized only during calculation
        // This method is kept for compatibility but doesn't modify weights
    }
}

