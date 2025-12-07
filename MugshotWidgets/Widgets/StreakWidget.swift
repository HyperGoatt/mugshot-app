//
//  StreakWidget.swift
//  MugshotWidgets
//
//  A small/medium widget highlighting the user's sip logging streak
//  and encouraging consistency with a 7-day activity bar.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Configuration

struct StreakWidget: Widget {
    let kind: String = "StreakWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetDS.Colors.widgetBackground
                }
        }
        .configurationDisplayName("Sip Streak")
        .description("Track your daily sip logging streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Entry

struct StreakEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let longestStreak: Int
    let weekdayMap: [WidgetWeekdayVisit]
    let hasVisitToday: Bool
    
    static var placeholder: StreakEntry {
        StreakEntry(
            date: Date(),
            currentStreak: 5,
            longestStreak: 12,
            weekdayMap: [
                WidgetWeekdayVisit(dayLetter: "S", dateString: "2025-11-26", hasVisit: true),
                WidgetWeekdayVisit(dayLetter: "M", dateString: "2025-11-27", hasVisit: true),
                WidgetWeekdayVisit(dayLetter: "T", dateString: "2025-11-28", hasVisit: false),
                WidgetWeekdayVisit(dayLetter: "W", dateString: "2025-11-29", hasVisit: true),
                WidgetWeekdayVisit(dayLetter: "T", dateString: "2025-11-30", hasVisit: true),
                WidgetWeekdayVisit(dayLetter: "F", dateString: "2025-12-01", hasVisit: true),
                WidgetWeekdayVisit(dayLetter: "S", dateString: "2025-12-02", hasVisit: false)
            ],
            hasVisitToday: false
        )
    }
    
    static var empty: StreakEntry {
        StreakEntry(
            date: Date(),
            currentStreak: 0,
            longestStreak: 0,
            weekdayMap: [],
            hasVisitToday: false
        )
    }
}

// MARK: - Timeline Provider

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            let entry = createEntry()
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = createEntry()
        
        // Refresh at midnight to update the streak
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let midnight = calendar.startOfDay(for: tomorrow)
        
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }
    
    private func createEntry() -> StreakEntry {
        let data = WidgetDataStore.shared.load()
        let calendar = Calendar.current
        
        // Check if there's a visit today
        let hasVisitToday = data.userVisits.contains { calendar.isDateInToday($0.createdAt) }
        
        return StreakEntry(
            date: Date(),
            currentStreak: data.currentStreak,
            longestStreak: data.longestStreak,
            weekdayMap: data.weekdayVisitMap,
            hasVisitToday: hasVisitToday
        )
    }
}

// MARK: - Widget Views

struct StreakEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: StreakEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallStreakView(entry: entry)
        case .systemMedium:
            MediumStreakView(entry: entry)
        default:
            SmallStreakView(entry: entry)
        }
    }
}

// MARK: - Small Widget View

struct SmallStreakView: View {
    let entry: StreakEntry
    
    var body: some View {
        let destination = entry.hasVisitToday ? WidgetDeepLink.journal! : WidgetDeepLink.logVisit!
        
        Link(destination: destination) {
            if entry.currentStreak > 0 {
                // Active streak - CELEBRATORY with huge flame and number
                VStack(spacing: WidgetDS.Spacing.contentSpacing) {
                    Spacer()
                    
                    // HUGE flame icon (40pt) with gradient effect
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [WidgetDS.Colors.yellowAccent, WidgetDS.Colors.orangeGradient],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Streak number - 48pt BOLD
                    Text("\(entry.currentStreak)")
                        .font(WidgetDS.Typography.displayLarge)
                        .foregroundColor(WidgetDS.Colors.textPrimary)
                    
                    // "days" label - much smaller
                    Text(entry.currentStreak == 1 ? "day" : "days")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(WidgetDS.Colors.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    // Best streak with trophy
                    if entry.longestStreak > entry.currentStreak {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 11))
                                .foregroundColor(WidgetDS.Colors.yellowAccent)
                            Text("Best: \(entry.longestStreak)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(WidgetDS.Colors.textTertiary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(WidgetDS.Spacing.widgetPadding)
            } else {
                // No streak - motivational with mint background
                ZStack {
                    // Mint background accent
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(WidgetDS.Gradients.mintSubtle)
                            .frame(height: 90)
                    }
                    
                    VStack(spacing: WidgetDS.Spacing.contentSpacing) {
                        Spacer()
                        
                        // Outlined flame (36pt)
                        Image(systemName: "flame")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(WidgetDS.Colors.textTertiary)
                        
                        Text("Start Your\nStreak")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("Log today")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(WidgetDS.Colors.primaryAccent)
                        
                        Spacer()
                    }
                    .padding(WidgetDS.Spacing.widgetPadding)
                }
            }
        }
    }
}

// MARK: - Medium Widget View

struct MediumStreakView: View {
    let entry: StreakEntry
    
    var body: some View {
        let destination = entry.hasVisitToday ? WidgetDeepLink.journal! : WidgetDeepLink.logVisit!
        
        Link(destination: destination) {
            HStack(spacing: WidgetDS.Spacing.sectionSpacing) {
                // Left section - GIANT streak number (56pt bold) with gradient background
                ZStack {
                    // Subtle mint-to-white gradient background
                    if entry.currentStreak > 0 {
                        RoundedRectangle(cornerRadius: WidgetDS.Radius.lg)
                            .fill(WidgetDS.Gradients.mintSubtle)
                    }
                    
                    VStack(spacing: WidgetDS.Spacing.md) {
                        if entry.currentStreak > 0 {
                            // Flame with gradient
                            Image(systemName: "flame.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [WidgetDS.Colors.yellowAccent, WidgetDS.Colors.orangeGradient],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            
                            // Giant streak number
                            Text("\(entry.currentStreak)")
                                .font(.system(size: 56, weight: .bold))
                                .foregroundColor(WidgetDS.Colors.textPrimary)
                            
                            // "day streak" below
                            Text("day streak")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(WidgetDS.Colors.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                        } else {
                            // No streak state
                            Image(systemName: "flame")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(WidgetDS.Colors.textTertiary)
                            
                            Text("Start\nStreak")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(WidgetDS.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .frame(width: 130)
                
                // Right section - bigger weekday circles (28pt each)
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.contentSpacing) {
                    Text("THIS WEEK")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(WidgetDS.Colors.textSecondary)
                        .tracking(0.8)
                    
                    // Bigger weekday circles
                    if !entry.weekdayMap.isEmpty {
                        HStack(spacing: WidgetDS.Spacing.md) {
                            ForEach(entry.weekdayMap) { day in
                                EnhancedWeekdayPill(
                                    dayLetter: day.dayLetter,
                                    hasVisit: day.hasVisit,
                                    isToday: isToday(day)
                                )
                            }
                        }
                    } else {
                        HStack(spacing: WidgetDS.Spacing.md) {
                            ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { letter in
                                EnhancedWeekdayPill(dayLetter: letter, hasVisit: false, isToday: false)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Status bar with larger icons and text
                    if !entry.hasVisitToday && entry.currentStreak > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(WidgetDS.Colors.orangeGradient)
                            Text("Keep your streak!")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(WidgetDS.Colors.textPrimary)
                        }
                    } else if entry.hasVisitToday {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(WidgetDS.Colors.primaryAccent)
                            Text("Logged today!")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(WidgetDS.Colors.textPrimary)
                        }
                    }
                    
                    // Best streak if different from current
                    if entry.longestStreak > entry.currentStreak && entry.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 11))
                                .foregroundColor(WidgetDS.Colors.yellowAccent)
                            Text("Best: \(entry.longestStreak) days")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(WidgetDS.Colors.textTertiary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(WidgetDS.Spacing.widgetPadding)
        }
    }
    
    private func isToday(_ day: WidgetWeekdayVisit) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        return day.dateString == todayString
    }
}

// MARK: - Weekday Pill (Legacy - kept for compatibility)

struct WeekdayPill: View {
    let dayLetter: String
    let hasVisit: Bool
    let isToday: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Text(dayLetter)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(hasVisit ? WidgetDS.Colors.textOnMint : WidgetDS.Colors.textTertiary)
            
            Circle()
                .fill(pillColor)
                .frame(width: 20, height: 20)
                .overlay {
                    if hasVisit {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(WidgetDS.Colors.textOnMint)
                    }
                }
                .overlay {
                    if isToday && !hasVisit {
                        Circle()
                            .stroke(WidgetDS.Colors.primaryAccent, lineWidth: 2)
                    }
                }
        }
    }
    
    private var pillColor: Color {
        if hasVisit {
            return WidgetDS.Colors.primaryAccent
        } else if isToday {
            return WidgetDS.Colors.mintSoftFill
        } else {
            return WidgetDS.Colors.neutralBorder.opacity(0.5)
        }
    }
}

// MARK: - Enhanced Weekday Pill (28pt circles, clearer indicators)

struct EnhancedWeekdayPill: View {
    let dayLetter: String
    let hasVisit: Bool
    let isToday: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(dayLetter)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(textColor)
            
            Circle()
                .fill(fillColor)
                .frame(width: 28, height: 28)
                .overlay {
                    if hasVisit {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .overlay {
                    if isToday {
                        Circle()
                            .stroke(strokeColor, lineWidth: 2.5)
                    }
                }
        }
    }
    
    private var fillColor: Color {
        if hasVisit {
            return WidgetDS.Colors.primaryAccent
        } else if isToday {
            return WidgetDS.Colors.mintSoftFill
        } else {
            return WidgetDS.Colors.neutralCardAlt
        }
    }
    
    private var strokeColor: Color {
        hasVisit ? WidgetDS.Colors.mintDark : WidgetDS.Colors.primaryAccent
    }
    
    private var textColor: Color {
        if hasVisit || isToday {
            return WidgetDS.Colors.textPrimary
        } else {
            return WidgetDS.Colors.textTertiary
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    StreakWidget()
} timeline: {
    StreakEntry.placeholder
    StreakEntry.empty
}

#Preview(as: .systemMedium) {
    StreakWidget()
} timeline: {
    StreakEntry.placeholder
    StreakEntry.empty
}

