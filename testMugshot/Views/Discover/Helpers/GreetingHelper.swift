//
//  GreetingHelper.swift
//  testMugshot
//
//  Dynamic greeting generator for Discover tab personalization.
//  60+ unique greetings based on time of day.
//

import Foundation

struct GreetingHelper {
    
    /// Returns a personalized greeting based on current time and user's first name
    static func getGreeting(userName: String) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greetings = greetingsForTimeOfDay(hour: hour)
        
        // Seed random with day of year to ensure consistent greeting throughout the day
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        var generator = SeededRandomNumberGenerator(seed: UInt64(dayOfYear))
        let selectedGreeting = greetings.randomElement(using: &generator) ?? greetings.first!
        
        return selectedGreeting.replacingOccurrences(of: "{name}", with: userName)
    }
    
    // MARK: - Private Helpers
    
    private static func greetingsForTimeOfDay(hour: Int) -> [String] {
        switch hour {
        case 5..<12:
            return morningGreetings
        case 12..<17:
            return afternoonGreetings
        case 17..<21:
            return eveningGreetings
        default:
            return nightGreetings
        }
    }
    
    // MARK: - Morning Greetings (5am - 12pm) - 18 options
    
    private static let morningGreetings = [
        "Good morning, {name} ☀️",
        "Rise and grind, {name} ☕",
        "Morning, {name}! Time to caffeinate",
        "Wakey wakey, {name} 🌅",
        "Fresh brew energy, {name}!",
        "Morning vibes, {name} ☀️",
        "Hello sunshine, {name}!",
        "New day, new coffee, {name} ☕",
        "Morning ritual time, {name}",
        "Sunrise sips await, {name} 🌄",
        "Bright and early, {name}!",
        "Morning magic, {name} ✨",
        "Coffee o'clock, {name} ☕",
        "Top of the morning, {name}!",
        "Ready to brew, {name}? ☕",
        "Let's get this coffee, {name}!",
        "Morning fuel loading, {name} ⚡",
        "First sip of the day, {name} ☀️"
    ]
    
    // MARK: - Afternoon Greetings (12pm - 5pm) - 18 options
    
    private static let afternoonGreetings = [
        "Good afternoon, {name} ☕",
        "Afternoon pick-me-up, {name}!",
        "Midday fuel time, {name} ⚡",
        "Afternoon delight, {name} ☕",
        "Recharge mode, {name}!",
        "Coffee break calling, {name} 📞",
        "Afternoon ritual, {name}",
        "Post-lunch energy, {name} ☕",
        "Afternoon adventure, {name} 🌤️",
        "Sip into the afternoon, {name}!",
        "Midday vibes, {name} ☀️",
        "Second wind time, {name}!",
        "Afternoon boost, {name} ⚡",
        "Beating the slump, {name}? ☕",
        "Midday motivation, {name}!",
        "Power hour, {name} 💪",
        "Afternoon escape, {name} ☕",
        "Keep going, {name}! ⚡"
    ]
    
    // MARK: - Evening Greetings (5pm - 9pm) - 18 options
    
    private static let eveningGreetings = [
        "Good evening, {name} 🌅",
        "Evening sips, {name}!",
        "Golden hour coffee, {name} 🌇",
        "Evening vibes, {name} ✨",
        "Winding down, {name}?",
        "Evening ritual, {name} ☕",
        "Sunset sips, {name} 🌆",
        "Evening delight, {name}!",
        "Twilight brew, {name} 🌅",
        "Evening energy, {name} ⚡",
        "Dusk delights, {name}!",
        "Evening escape, {name} 🌇",
        "After hours, {name} ☕",
        "Evening wind-down, {name}",
        "Sunset state of mind, {name} 🌅",
        "End of day treat, {name}!",
        "Evening calm, {name} ✨",
        "Peaceful evening, {name} 🌆"
    ]
    
    // MARK: - Night Greetings (9pm - 5am) - 18 options
    
    private static let nightGreetings = [
        "Good evening, {name} 🌙",
        "Night owl mode, {name}! 🦉",
        "Late night sips, {name} ☕",
        "Moonlight cafe, {name} 🌙",
        "Nighttime ritual, {name}",
        "Under the stars, {name} ✨",
        "Night vibes, {name} 🌃",
        "Midnight musings, {name}",
        "Starlit sips, {name} 🌟",
        "Night time magic, {name} ✨",
        "After dark, {name} 🌙",
        "Burning the midnight oil, {name}? ☕",
        "Night cap time, {name}!",
        "Quiet hours, {name} 🌙",
        "Late night fuel, {name} ⚡",
        "Night shift vibes, {name} 🦉",
        "Sleepless sips, {name} ☕",
        "Night wanderer, {name} 🌃"
    ]
}

// MARK: - Seeded Random Number Generator

/// Custom random number generator that uses a seed for reproducibility
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}



