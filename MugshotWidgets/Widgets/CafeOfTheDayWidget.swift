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
            ZStack {
                // Subtle warm gradient background for special feel
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(WidgetDS.Gradients.featured)
                        .frame(height: 100)
                }
                
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.contentSpacing) {
                    // Prominent "Featured" badge at top
                    HStack {
                        EnhancedBadge(
                            text: "FEATURED",
                            icon: "sparkles",
                            backgroundColor: WidgetDS.Colors.yellowAccent.opacity(0.2),
                            foregroundColor: WidgetDS.Colors.yellowGradient
                        )
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Large coffee cup icon (48pt) with sparkle
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        WidgetDS.Colors.yellowAccent.opacity(0.2),
                                        WidgetDS.Colors.yellowAccent.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(WidgetDS.Colors.yellowGradient)
                    }
                    
                    // Cafe name - 18pt bold
                    Text(cafe.name)
                        .font(WidgetDS.Typography.contentTitle)
                        .foregroundColor(WidgetDS.Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    
                    // Location with icon
                    if let city = cafe.city {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                                .foregroundColor(WidgetDS.Colors.textTertiary)
                            Text(city)
                                .font(WidgetDS.Typography.contentBody)
                                .foregroundColor(WidgetDS.Colors.textSecondary)
                        }
                    }
                    
                    // Prominent rating
                    if cafe.averageRating > 0 {
                        EnhancedRatingDisplay(rating: cafe.averageRating, showStars: false, size: 12)
                    }
                    
                    Spacer()
                }
                .padding(WidgetDS.Spacing.widgetPadding)
            }
        }
    }
}

// MARK: - Medium Widget View

struct MediumCafeOfTheDayView: View {
    let cafe: WidgetCafe
    
    var body: some View {
        Link(destination: WidgetDeepLink.cafeDetail(cafeId: cafe.id) ?? WidgetDeepLink.map!) {
            HStack(spacing: 0) {
                // Left side - large graphic/illustration (100x100) with warm gradient
                ZStack {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(
                            LinearGradient(
                                colors: [
                                    WidgetDS.Colors.yellowAccent.opacity(0.3),
                                    WidgetDS.Colors.yellowGradient.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(spacing: WidgetDS.Spacing.md) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundColor(WidgetDS.Colors.yellowGradient)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(WidgetDS.Colors.yellowAccent)
                    }
                }
                .frame(width: 110)
                
                // Right side - featured content with gold accent
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.md) {
                    // "Today's Pick" in large bold type (20pt)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TODAY'S PICK")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(WidgetDS.Colors.yellowGradient)
                            .tracking(0.8)
                        
                        Text(formattedDate)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(WidgetDS.Colors.textTertiary)
                    }
                    
                    // Cafe name - bold and prominent
                    Text(cafe.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(WidgetDS.Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    
                    Spacer()
                    
                    // Location and stats
                    HStack(spacing: WidgetDS.Spacing.contentSpacing) {
                        if let city = cafe.city {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("LOCATION")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(WidgetDS.Colors.textTertiary)
                                    .tracking(0.5)
                                Text(city)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(WidgetDS.Colors.textPrimary)
                            }
                        }
                        
                        if cafe.averageRating > 0 {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("RATING")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(WidgetDS.Colors.textTertiary)
                                    .tracking(0.5)
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(WidgetDS.Colors.yellowAccent)
                                    Text(String(format: "%.1f", cafe.averageRating))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(WidgetDS.Colors.textPrimary)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Prominent "Explore" CTA
                    HStack(spacing: 4) {
                        Text("Explore")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(WidgetDS.Colors.yellowGradient)
                }
                .padding(WidgetDS.Spacing.widgetPadding)
                
                Spacer()
            }
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
            ZStack {
                // Warm gradient background
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(WidgetDS.Gradients.featured)
                        .frame(height: 90)
                }
                
                VStack(spacing: WidgetDS.Spacing.contentSpacing) {
                    HStack {
                        EnhancedBadge(
                            text: "FEATURED",
                            icon: "sparkles",
                            backgroundColor: WidgetDS.Colors.yellowAccent.opacity(0.2),
                            foregroundColor: WidgetDS.Colors.yellowGradient
                        )
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Image(systemName: "cup.and.saucer")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundColor(WidgetDS.Colors.yellowGradient.opacity(0.6))
                    
                    VStack(spacing: 8) {
                        Text("Coming Soon")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                        
                        Text("Log visits to unlock")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(WidgetDS.Spacing.widgetPadding)
            }
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

