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
            VStack(spacing: WidgetDS.Spacing.md) {
                // Header
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(entry.currentStreak > 0 ? .orange : WidgetDS.Colors.textTertiary)
                    Text("Streak")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(WidgetDS.Colors.textSecondary)
                    Spacer()
                }
                
                Spacer()
                
                if entry.currentStreak > 0 {
                    // Has a streak
                    VStack(spacing: WidgetDS.Spacing.xs) {
                        Text("\(entry.currentStreak)")
                            .font(WidgetDS.Typography.statNumber)
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                        
                        Text(entry.currentStreak == 1 ? "day" : "days")
                            .font(WidgetDS.Typography.caption)
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                    }
                    
                    // Best streak
                    HStack(spacing: WidgetDS.Spacing.xs) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 10))
                            .foregroundColor(WidgetDS.Colors.yellowAccent)
                        Text("Best: \(entry.longestStreak)")
                            .font(.system(size: 11))
                            .foregroundColor(WidgetDS.Colors.textTertiary)
                    }
                } else {
                    // No streak
                    VStack(spacing: WidgetDS.Spacing.sm) {
                        Image(systemName: "flame")
                            .font(.system(size: 24))
                            .foregroundColor(WidgetDS.Colors.textTertiary)
                        
                        Text("Start your streak")
                            .font(WidgetDS.Typography.caption)
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Log a visit")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(WidgetDS.Colors.primaryAccent)
                    }
                }
                
                Spacer()
            }
            .padding(WidgetDS.Spacing.lg)
        }
    }
}

// MARK: - Medium Widget View

struct MediumStreakView: View {
    let entry: StreakEntry
    
    var body: some View {
        let destination = entry.hasVisitToday ? WidgetDeepLink.journal! : WidgetDeepLink.logVisit!
        
        Link(destination: destination) {
            HStack(spacing: WidgetDS.Spacing.xl) {
                // Left side - streak number
                VStack(spacing: WidgetDS.Spacing.sm) {
                    // Streak icon and number
                    HStack(spacing: WidgetDS.Spacing.sm) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20))
                            .foregroundColor(entry.currentStreak > 0 ? .orange : WidgetDS.Colors.textTertiary)
                        
                        if entry.currentStreak > 0 {
                            Text("\(entry.currentStreak)")
                                .font(WidgetDS.Typography.statNumber)
                                .foregroundColor(WidgetDS.Colors.textPrimary)
                        }
                    }
                    
                    if entry.currentStreak > 0 {
                        Text(entry.currentStreak == 1 ? "day streak" : "day streak")
                            .font(WidgetDS.Typography.caption)
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                        
                        // Best streak
                        HStack(spacing: WidgetDS.Spacing.xs) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10))
                                .foregroundColor(WidgetDS.Colors.yellowAccent)
                            Text("Best: \(entry.longestStreak) days")
                                .font(.system(size: 11))
                                .foregroundColor(WidgetDS.Colors.textTertiary)
                        }
                    } else {
                        Text("No active streak")
                            .font(WidgetDS.Typography.caption)
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                        
                        Text("Log a visit to start")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(WidgetDS.Colors.primaryAccent)
                    }
                }
                .frame(minWidth: 80)
                
                // Divider
                Rectangle()
                    .fill(WidgetDS.Colors.neutralDivider)
                    .frame(width: 1)
                    .padding(.vertical, WidgetDS.Spacing.md)
                
                // Right side - weekly view
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.md) {
                    Text("This Week")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WidgetDS.Colors.textSecondary)
                    
                    // Weekly pill row
                    if !entry.weekdayMap.isEmpty {
                        HStack(spacing: WidgetDS.Spacing.sm) {
                            ForEach(entry.weekdayMap) { day in
                                WeekdayPill(
                                    dayLetter: day.dayLetter,
                                    hasVisit: day.hasVisit,
                                    isToday: isToday(day)
                                )
                            }
                        }
                    } else {
                        // Fallback empty state
                        HStack(spacing: WidgetDS.Spacing.sm) {
                            ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { letter in
                                WeekdayPill(dayLetter: letter, hasVisit: false, isToday: false)
                            }
                        }
                    }
                    
                    // Status message
                    if !entry.hasVisitToday && entry.currentStreak > 0 {
                        HStack(spacing: WidgetDS.Spacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(WidgetDS.Colors.yellowAccent)
                            Text("Keep your streak! Log today")
                                .font(.system(size: 10))
                                .foregroundColor(WidgetDS.Colors.textSecondary)
                        }
                    } else if entry.hasVisitToday {
                        HStack(spacing: WidgetDS.Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(WidgetDS.Colors.primaryAccent)
                            Text("Today's mugshot logged!")
                                .font(.system(size: 10))
                                .foregroundColor(WidgetDS.Colors.textSecondary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(WidgetDS.Spacing.lg)
        }
    }
    
    private func isToday(_ day: WidgetWeekdayVisit) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        return day.dateString == todayString
    }
}

// MARK: - Weekday Pill

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

