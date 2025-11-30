//
//  BadgeEngine.swift
//  testMugshot
//
//  Engine for computing badge unlock states from visit data.
//

import Foundation

struct BadgeEngine {
    
    // MARK: - Public API
    
    /// Computes all badge states from the user's visits
    /// - Parameters:
    ///   - visits: Array of user's visits
    ///   - today: Current date (injectable for testing)
    ///   - calendar: Calendar to use (injectable for testing)
    /// - Returns: Array of BadgeState sorted with unlocked first, then by category
    static func computeBadges(
        visits: [Visit],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [BadgeState] {
        // Precompute aggregates
        let aggregates = computeAggregates(visits: visits, today: today, calendar: calendar)
        
        // Log aggregates
        print("[BadgeEngine] totalVisits=\(aggregates.totalVisits), uniqueCafes=\(aggregates.uniqueCafeCount), notesCount=\(aggregates.visitsWithNotesCount), drinkTypes=\(aggregates.distinctDrinkTypesCount), earlyMorning=\(aggregates.earlyMorningVisitsCount)")
        
        // Compute state for each badge
        var badgeStates: [BadgeState] = []
        
        for definition in BadgeDefinition.all {
            let state = computeBadgeState(for: definition, aggregates: aggregates)
            badgeStates.append(state)
        }
        
        // Sort: unlocked first, then by category, then by name
        badgeStates.sort { lhs, rhs in
            if lhs.isUnlocked != rhs.isUnlocked {
                return lhs.isUnlocked // Unlocked badges first
            }
            if lhs.definition.category.sortOrder != rhs.definition.category.sortOrder {
                return lhs.definition.category.sortOrder < rhs.definition.category.sortOrder
            }
            return lhs.definition.name < rhs.definition.name
        }
        
        let unlockedCount = badgeStates.filter { $0.isUnlocked }.count
        let lockedCount = badgeStates.count - unlockedCount
        print("[BadgeEngine] Computed \(badgeStates.count) badges (unlocked: \(unlockedCount), locked: \(lockedCount))")
        
        return badgeStates
    }
    
    // MARK: - Aggregates
    
    struct Aggregates {
        let totalVisits: Int
        let uniqueCafeCount: Int
        let visitsWithNotesCount: Int
        let distinctDrinkTypesCount: Int
        let earlyMorningVisitsCount: Int
        let currentStreakDays: Int
        let longestStreakDays: Int
        let consecutiveWeekendsCount: Int
    }
    
    private static func computeAggregates(
        visits: [Visit],
        today: Date,
        calendar: Calendar
    ) -> Aggregates {
        let totalVisits = visits.count
        
        // Unique cafes
        let uniqueCafeIds = Set(visits.map { $0.cafeId })
        let uniqueCafeCount = uniqueCafeIds.count
        
        // Visits with notes
        let visitsWithNotesCount = visits.filter { 
            $0.notes != nil && !($0.notes?.isEmpty ?? true) 
        }.count
        
        // Distinct drink types
        let drinkTypes = Set(visits.map { $0.drinkType })
        let distinctDrinkTypesCount = drinkTypes.count
        
        // Early morning visits (before 9am local time)
        let earlyMorningVisitsCount = visits.filter { visit in
            let hour = calendar.component(.hour, from: visit.createdAt)
            return hour < 9
        }.count
        
        // Streaks (reuse JournalStatsHelper)
        let currentStreakDays = JournalStatsHelper.calculateCurrentStreak(visits: visits)
        let longestStreakDays = JournalStatsHelper.calculateLongestStreak(visits: visits)
        
        // Consecutive weekends
        let consecutiveWeekendsCount = computeConsecutiveWeekends(visits: visits, calendar: calendar)
        
        return Aggregates(
            totalVisits: totalVisits,
            uniqueCafeCount: uniqueCafeCount,
            visitsWithNotesCount: visitsWithNotesCount,
            distinctDrinkTypesCount: distinctDrinkTypesCount,
            earlyMorningVisitsCount: earlyMorningVisitsCount,
            currentStreakDays: currentStreakDays,
            longestStreakDays: longestStreakDays,
            consecutiveWeekendsCount: consecutiveWeekendsCount
        )
    }
    
    // MARK: - Weekend Warrior Logic
    
    /// Computes the maximum number of consecutive weekends with visits
    private static func computeConsecutiveWeekends(visits: [Visit], calendar: Calendar) -> Int {
        guard !visits.isEmpty else { return 0 }
        
        // Get all unique week numbers that had a weekend visit
        // A "weekend" is Saturday (7) or Sunday (1)
        var weekendsWithVisits: Set<Int> = []
        
        for visit in visits {
            let weekday = calendar.component(.weekday, from: visit.createdAt)
            // Sunday = 1, Saturday = 7
            if weekday == 1 || weekday == 7 {
                // Get the week of year for this weekend
                // For Sunday, use the previous week's number to group with Saturday
                var dateToCheck = visit.createdAt
                if weekday == 1 {
                    // Sunday - go back to Saturday to get the same weekend
                    dateToCheck = calendar.date(byAdding: .day, value: -1, to: visit.createdAt) ?? visit.createdAt
                }
                
                let year = calendar.component(.yearForWeekOfYear, from: dateToCheck)
                let week = calendar.component(.weekOfYear, from: dateToCheck)
                
                // Create a unique identifier for this weekend (year * 100 + week)
                let weekendId = year * 100 + week
                weekendsWithVisits.insert(weekendId)
            }
        }
        
        guard !weekendsWithVisits.isEmpty else { return 0 }
        
        // Sort weekend IDs and find consecutive runs
        let sortedWeekends = weekendsWithVisits.sorted()
        
        var maxConsecutive = 1
        var currentConsecutive = 1
        
        for i in 1..<sortedWeekends.count {
            let prev = sortedWeekends[i - 1]
            let curr = sortedWeekends[i]
            
            // Check if consecutive weeks
            // Same year: week difference of 1
            // Year boundary: prev is last week of year, curr is first week of next year
            let prevYear = prev / 100
            let prevWeek = prev % 100
            let currYear = curr / 100
            let currWeek = curr % 100
            
            let isConsecutive: Bool
            if currYear == prevYear && currWeek == prevWeek + 1 {
                isConsecutive = true
            } else if currYear == prevYear + 1 && currWeek == 1 && prevWeek >= 52 {
                // Year boundary case
                isConsecutive = true
            } else {
                isConsecutive = false
            }
            
            if isConsecutive {
                currentConsecutive += 1
                maxConsecutive = max(maxConsecutive, currentConsecutive)
            } else {
                currentConsecutive = 1
            }
        }
        
        return maxConsecutive
    }
    
    // MARK: - Badge State Computation
    
    private static func computeBadgeState(
        for definition: BadgeDefinition,
        aggregates: Aggregates
    ) -> BadgeState {
        let (currentValue, isUnlocked) = computeValueAndUnlock(for: definition.id, aggregates: aggregates)
        
        return BadgeState(
            definition: definition,
            isUnlocked: isUnlocked,
            currentValue: currentValue,
            targetValue: definition.targetValue
        )
    }
    
    private static func computeValueAndUnlock(
        for badgeId: String,
        aggregates: Aggregates
    ) -> (currentValue: Int, isUnlocked: Bool) {
        switch badgeId {
        case "first_pour":
            let value = aggregates.totalVisits
            return (min(value, 1), value >= 1)
            
        case "steady_sipper":
            let value = aggregates.totalVisits
            return (value, value >= 10)
            
        case "regular":
            let value = aggregates.totalVisits
            return (value, value >= 25)
            
        case "weekend_warrior":
            let value = aggregates.consecutiveWeekendsCount
            return (value, value >= 2)
            
        case "daily_drip_7":
            // Use longest streak for progress, but check current or longest for unlock
            let value = max(aggregates.currentStreakDays, aggregates.longestStreakDays)
            return (value, value >= 7)
            
        case "neighborhood_sipper":
            let value = aggregates.uniqueCafeCount
            return (value, value >= 3)
            
        case "cafe_explorer":
            let value = aggregates.uniqueCafeCount
            return (value, value >= 10)
            
        case "thoughtful_sipper":
            let value = aggregates.visitsWithNotesCount
            return (value, value >= 3)
            
        case "coffee_chronicler":
            let value = aggregates.visitsWithNotesCount
            return (value, value >= 10)
            
        case "adventurous_palate":
            let value = aggregates.distinctDrinkTypesCount
            return (value, value >= 3)
            
        case "early_bird_brew":
            let value = aggregates.earlyMorningVisitsCount
            return (value, value >= 5)
            
        default:
            return (0, false)
        }
    }
}

