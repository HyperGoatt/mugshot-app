//
//  JournalStatsHelper.swift
//  testMugshot
//
//  Helper utilities for calculating journal statistics like streaks and visit counts.
//

import Foundation

struct JournalStatsHelper {
    
    // MARK: - Streak Calculations
    
    /// Calculates the current streak of consecutive days with visits up to today.
    /// - Parameter visits: Array of visits to analyze
    /// - Returns: Number of consecutive days with visits ending today (or yesterday if no visit today yet)
    static func calculateCurrentStreak(visits: [Visit]) -> Int {
        // PERFORMANCE: Early exit for common case
        guard !visits.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // PERFORMANCE: Only create Set if we have visits to analyze
        let visitDates = Set(visits.map { calendar.startOfDay(for: $0.createdAt) })
        
        // Check if there's a visit today or yesterday to start counting
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        
        var currentDate: Date
        if visitDates.contains(today) {
            currentDate = today
        } else if visitDates.contains(yesterday) {
            currentDate = yesterday
        } else {
            return 0
        }
        
        // Count consecutive days backwards
        var streak = 0
        while visitDates.contains(currentDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = previousDay
        }
        
        return streak
    }
    
    /// Calculates the longest streak of consecutive days with visits ever.
    /// - Parameter visits: Array of visits to analyze
    /// - Returns: Maximum number of consecutive days with visits
    static func calculateLongestStreak(visits: [Visit]) -> Int {
        guard !visits.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        
        // Get unique visit dates sorted ascending
        let visitDates = Set(visits.map { calendar.startOfDay(for: $0.createdAt) })
            .sorted()
        
        guard !visitDates.isEmpty else { return 0 }
        
        var longestStreak = 1
        var currentStreak = 1
        
        for i in 1..<visitDates.count {
            let previousDate = visitDates[i - 1]
            let currentDate = visitDates[i]
            
            // Check if dates are consecutive
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: previousDate),
               calendar.isDate(nextDay, inSameDayAs: currentDate) {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }
        
        return longestStreak
    }
    
    // MARK: - Visit Counts
    
    /// Returns the number of visits in the last 7 days.
    static func visitsInLast7Days(visits: [Visit]) -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return 0 }
        
        return visits.filter { $0.createdAt >= weekAgo }.count
    }
    
    /// Returns the number of visits in the last 30 days.
    static func visitsInLast30Days(visits: [Visit]) -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let monthAgo = calendar.date(byAdding: .day, value: -29, to: startOfToday) else { return 0 }
        
        return visits.filter { $0.createdAt >= monthAgo }.count
    }
    
    // MARK: - Weekly Map
    
    /// Returns a dictionary mapping the last 7 days (Mon-Sun order) to whether a visit occurred.
    /// - Parameter visits: Array of visits to analyze
    /// - Returns: Array of 7 tuples containing (dayLetter, hasVisit) for the last 7 days starting from 6 days ago
    static func weekdayVisitMap(visits: [Visit]) -> [(dayLetter: String, date: Date, hasVisit: Bool)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get unique visit dates
        let visitDates = Set(visits.map { calendar.startOfDay(for: $0.createdAt) })
        
        // Build array for last 7 days (starting 6 days ago)
        var result: [(dayLetter: String, date: Date, hasVisit: Bool)] = []
        
        for daysAgo in (0...6).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            
            let dayOfWeek = calendar.component(.weekday, from: date)
            let dayLetter = dayLetterFor(weekday: dayOfWeek)
            let hasVisit = visitDates.contains(date)
            
            result.append((dayLetter: dayLetter, date: date, hasVisit: hasVisit))
        }
        
        return result
    }
    
    /// Converts a weekday number (1=Sunday, 7=Saturday) to a single letter.
    private static func dayLetterFor(weekday: Int) -> String {
        switch weekday {
        case 1: return "S"  // Sunday
        case 2: return "M"  // Monday
        case 3: return "T"  // Tuesday
        case 4: return "W"  // Wednesday
        case 5: return "T"  // Thursday
        case 6: return "F"  // Friday
        case 7: return "S"  // Saturday
        default: return "?"
        }
    }
    
    // MARK: - Today's Visit
    
    /// Returns the first visit from today, if any.
    static func todaysVisit(from visits: [Visit]) -> Visit? {
        let calendar = Calendar.current
        return visits.first { calendar.isDateInToday($0.createdAt) }
    }
    
    // MARK: - Top Cafes
    
    /// Returns the top cafes by visit count with average ratings.
    /// - Parameters:
    ///   - visits: Array of visits to analyze
    ///   - cafeLookup: Function to look up a cafe by ID
    ///   - limit: Maximum number of cafes to return
    /// - Returns: Array of tuples containing (cafe, visitCount, avgRating)
    static func topCafes(
        from visits: [Visit],
        cafeLookup: (UUID) -> Cafe?,
        limit: Int = 3
    ) -> [(cafe: Cafe, visitCount: Int, avgRating: Double)] {
        // Group visits by cafe
        let visitsByCafe = Dictionary(grouping: visits, by: { $0.cafeId })
        
        var result: [(cafe: Cafe, visitCount: Int, avgRating: Double)] = []
        
        for (cafeId, cafeVisits) in visitsByCafe {
            guard let cafe = cafeLookup(cafeId) else { continue }
            
            let visitCount = cafeVisits.count
            let avgRating = cafeVisits.reduce(0.0) { $0 + $1.overallScore } / Double(visitCount)
            
            result.append((cafe: cafe, visitCount: visitCount, avgRating: avgRating))
        }
        
        // Sort by visit count (descending), then by avg rating (descending)
        return result
            .sorted { 
                if $0.visitCount != $1.visitCount {
                    return $0.visitCount > $1.visitCount
                }
                return $0.avgRating > $1.avgRating
            }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Recent Notes
    
    /// Returns the most recent visits that have notes.
    /// - Parameters:
    ///   - visits: Array of visits to filter
    ///   - limit: Maximum number of notes to return
    /// - Returns: Array of visits with notes, sorted by date descending
    static func recentVisitsWithNotes(from visits: [Visit], limit: Int = 3) -> [Visit] {
        return visits
            .filter { $0.notes != nil && !($0.notes?.isEmpty ?? true) }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Notes Section Helpers
    
    /// Returns all visits that have non-empty notes, sorted by date descending.
    static func allVisitsWithNotes(from visits: [Visit]) -> [Visit] {
        return visits
            .filter { $0.notes != nil && !($0.notes?.isEmpty ?? true) }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Groups visits with notes by month/year.
    /// - Parameter visits: Array of visits to group (should already be filtered to only visits with notes)
    /// - Returns: Array of tuples containing (monthYearKey, displayString, visits) sorted by date descending
    static func groupVisitsByMonth(_ visits: [Visit]) -> [(key: String, displayString: String, visits: [Visit])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy" // e.g., "November 2025"
        
        // Group by year-month key for sorting
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM"
        
        let grouped = Dictionary(grouping: visits) { visit -> String in
            keyFormatter.string(from: visit.createdAt)
        }
        
        // Convert to sorted array of tuples
        return grouped
            .map { (key: $0.key, displayString: formatter.string(from: $0.value.first!.createdAt), visits: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.key > $1.key } // Sort by key descending (newest first)
    }
    
    /// Returns unique cafes that have at least one visit with notes.
    /// - Parameters:
    ///   - visits: Array of all user visits
    ///   - cafeLookup: Function to look up a cafe by ID
    /// - Returns: Array of cafes that have notes, sorted alphabetically by name
    static func cafesWithNotes(
        from visits: [Visit],
        cafeLookup: (UUID) -> Cafe?
    ) -> [Cafe] {
        let visitsWithNotes = allVisitsWithNotes(from: visits)
        let cafeIds = Set(visitsWithNotes.map { $0.cafeId })
        
        return cafeIds
            .compactMap { cafeLookup($0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Filters visits with notes by a specific cafe.
    /// - Parameters:
    ///   - visits: Array of visits with notes
    ///   - cafeId: The cafe ID to filter by
    /// - Returns: Filtered visits for the specified cafe, sorted by date descending
    static func filterNotesByCafe(_ visits: [Visit], cafeId: UUID) -> [Visit] {
        return visits
            .filter { $0.cafeId == cafeId }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Returns the total count of visits with notes.
    static func notesCount(from visits: [Visit]) -> Int {
        return allVisitsWithNotes(from: visits).count
    }
}

