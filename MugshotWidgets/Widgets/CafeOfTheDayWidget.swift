//
//  CafeOfTheDayWidget.swift
//  MugshotWidgets
//
//  A daily "suggested sip" widget that features one cafe per day,
//  making Mugshot feel curated and delightful.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Configuration

struct CafeOfTheDayWidget: Widget {
    let kind: String = "CafeOfTheDayWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CafeOfTheDayProvider()) { entry in
            CafeOfTheDayEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetDS.Colors.widgetBackground
                }
        }
        .configurationDisplayName("Cafe of the Day")
        .description("A daily suggestion for your next coffee adventure.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Entry

struct CafeOfTheDayEntry: TimelineEntry {
    let date: Date
    let cafe: WidgetCafe?
    
    static var placeholder: CafeOfTheDayEntry {
        CafeOfTheDayEntry(
            date: Date(),
            cafe: WidgetCafe(
                id: "cafe-1",
                name: "La Colombe",
                address: "319 Lafayette St",
                city: "Manhattan",
                country: "USA",
                latitude: 40.7274,
                longitude: -73.9955,
                isFavorite: true,
                wantToTry: false,
                averageRating: 4.6,
                visitCount: 3,
                distanceMeters: 800
            )
        )
    }
    
    static var empty: CafeOfTheDayEntry {
        CafeOfTheDayEntry(date: Date(), cafe: nil)
    }
}

// MARK: - Timeline Provider

struct CafeOfTheDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> CafeOfTheDayEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CafeOfTheDayEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            let entry = createEntry()
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CafeOfTheDayEntry>) -> Void) {
        let entry = createEntry()
        
        // Refresh at midnight to get a new cafe of the day
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let midnight = calendar.startOfDay(for: tomorrow)
        
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }
    
    private func createEntry() -> CafeOfTheDayEntry {
        let data = WidgetDataStore.shared.load()
        
        // Check if we already have a cafe of the day for today
        if let savedCafe = data.cafeOfTheDay,
           let savedDate = data.cafeOfTheDayDate,
           Calendar.current.isDateInToday(savedDate) {
            return CafeOfTheDayEntry(date: Date(), cafe: savedCafe)
        }
        
        // Otherwise, select a new cafe
        // Priority: favorites > high-rated visited cafes > any cafe
        let cafe = selectCafeOfTheDay(from: data)
        return CafeOfTheDayEntry(date: Date(), cafe: cafe)
    }
    
    /// Deterministically selects a cafe for today based on the date
    private func selectCafeOfTheDay(from data: WidgetDataContainer) -> WidgetCafe? {
        // Get all candidate cafes
        var candidates: [WidgetCafe] = []
        
        // Add favorites first (highest priority)
        candidates.append(contentsOf: data.favoriteCafes)
        
        // Add nearby cafes
        candidates.append(contentsOf: data.nearbyCafes)
        
        // Remove duplicates based on ID
        var seenIds = Set<String>()
        candidates = candidates.filter { cafe in
            if seenIds.contains(cafe.id) {
                return false
            }
            seenIds.insert(cafe.id)
            return true
        }
        
        guard !candidates.isEmpty else { return nil }
        
        // Use the day of year as a seed for deterministic selection
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let index = dayOfYear % candidates.count
        
        return candidates[index]
    }
}

// MARK: - Widget Views

struct CafeOfTheDayEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: CafeOfTheDayEntry
    
    var body: some View {
        if let cafe = entry.cafe {
            switch family {
            case .systemSmall:
                SmallCafeOfTheDayView(cafe: cafe)
            case .systemMedium:
                MediumCafeOfTheDayView(cafe: cafe)
            default:
                SmallCafeOfTheDayView(cafe: cafe)
            }
        } else {
            EmptyCafeOfTheDayView()
        }
    }
}

// MARK: - Small Widget View

struct SmallCafeOfTheDayView: View {
    let cafe: WidgetCafe
    
    var body: some View {
        Link(destination: WidgetDeepLink.cafeDetail(cafeId: cafe.id) ?? WidgetDeepLink.map!) {
            VStack(alignment: .leading, spacing: WidgetDS.Spacing.sm) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(WidgetDS.Colors.yellowAccent)
                    Text("Cafe of the Day")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(WidgetDS.Colors.textSecondary)
                    Spacer()
                }
                
                Spacer()
                
                // Cafe icon
                ZStack {
                    Circle()
                        .fill(WidgetDS.Colors.mintSoftFill)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 16))
                        .foregroundColor(WidgetDS.Colors.primaryAccent)
                }
                
                // Cafe name
                Text(cafe.name)
                    .font(WidgetDS.Typography.headline)
                    .foregroundColor(WidgetDS.Colors.textPrimary)
                    .lineLimit(2)
                
                // Location
                if let city = cafe.city {
                    Text(city)
                        .font(WidgetDS.Typography.caption)
                        .foregroundColor(WidgetDS.Colors.textTertiary)
                        .lineLimit(1)
                }
                
                // Rating
                if cafe.averageRating > 0 {
                    HStack(spacing: 2) {
                        WidgetStarRating(rating: cafe.averageRating, size: 9)
                        Text(String(format: "%.1f", cafe.averageRating))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                    }
                }
            }
            .padding(WidgetDS.Spacing.lg)
        }
    }
}

// MARK: - Medium Widget View

struct MediumCafeOfTheDayView: View {
    let cafe: WidgetCafe
    
    var body: some View {
        Link(destination: WidgetDeepLink.cafeDetail(cafeId: cafe.id) ?? WidgetDeepLink.map!) {
            HStack(spacing: WidgetDS.Spacing.xl) {
                // Left side - Cafe visual
                ZStack {
                    RoundedRectangle(cornerRadius: WidgetDS.Radius.md)
                        .fill(
                            LinearGradient(
                                colors: [
                                    WidgetDS.Colors.mintSoftFill,
                                    WidgetDS.Colors.primaryAccent.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(spacing: WidgetDS.Spacing.sm) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 28))
                            .foregroundColor(WidgetDS.Colors.primaryAccent)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundColor(WidgetDS.Colors.yellowAccent)
                    }
                }
                .frame(width: 80, height: 80)
                
                // Right side - Cafe details
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.sm) {
                    // Header
                    HStack {
                        Text("Cafe of the Day")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text(formattedDate)
                            .font(.system(size: 10))
                            .foregroundColor(WidgetDS.Colors.textTertiary)
                    }
                    
                    // Cafe name
                    Text(cafe.name)
                        .font(WidgetDS.Typography.title)
                        .foregroundColor(WidgetDS.Colors.textPrimary)
                        .lineLimit(1)
                    
                    // Location
                    if let city = cafe.city {
                        HStack(spacing: WidgetDS.Spacing.xs) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                                .foregroundColor(WidgetDS.Colors.textTertiary)
                            Text(city)
                                .font(WidgetDS.Typography.body)
                                .foregroundColor(WidgetDS.Colors.textSecondary)
                            
                            if let distance = cafe.distanceString {
                                Text("• \(distance)")
                                    .font(WidgetDS.Typography.body)
                                    .foregroundColor(WidgetDS.Colors.textTertiary)
                            }
                        }
                    }
                    
                    // Rating and visits
                    HStack(spacing: WidgetDS.Spacing.lg) {
                        if cafe.averageRating > 0 {
                            HStack(spacing: WidgetDS.Spacing.xs) {
                                WidgetStarRating(rating: cafe.averageRating, size: 11)
                                Text(String(format: "%.1f", cafe.averageRating))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(WidgetDS.Colors.textSecondary)
                            }
                        }
                        
                        if cafe.visitCount > 0 {
                            HStack(spacing: WidgetDS.Spacing.xs) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(WidgetDS.Colors.textTertiary)
                                Text("\(cafe.visitCount) visits")
                                    .font(.system(size: 11))
                                    .foregroundColor(WidgetDS.Colors.textTertiary)
                            }
                        }
                        
                        Spacer()
                        
                        Text("Tap to view")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(WidgetDS.Colors.primaryAccent)
                    }
                }
                
                Spacer()
            }
            .padding(WidgetDS.Spacing.lg)
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Empty State View

struct EmptyCafeOfTheDayView: View {
    var body: some View {
        Link(destination: WidgetDeepLink.logVisit!) {
            VStack(spacing: WidgetDS.Spacing.lg) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(WidgetDS.Colors.yellowAccent)
                    Text("Cafe of the Day")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(WidgetDS.Colors.textSecondary)
                    Spacer()
                }
                
                Spacer()
                
                Image(systemName: "cup.and.saucer")
                    .font(.system(size: 28))
                    .foregroundColor(WidgetDS.Colors.textTertiary)
                
                Text("Log a visit to start")
                    .font(WidgetDS.Typography.body)
                    .foregroundColor(WidgetDS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Text("getting recommendations")
                    .font(WidgetDS.Typography.caption)
                    .foregroundColor(WidgetDS.Colors.textTertiary)
                
                Spacer()
            }
            .padding(WidgetDS.Spacing.lg)
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    CafeOfTheDayWidget()
} timeline: {
    CafeOfTheDayEntry.placeholder
    CafeOfTheDayEntry.empty
}

#Preview(as: .systemMedium) {
    CafeOfTheDayWidget()
} timeline: {
    CafeOfTheDayEntry.placeholder
    CafeOfTheDayEntry.empty
}

