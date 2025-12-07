//
//  NearbyCafeWidget.swift
//  MugshotWidgets
//
//  A utility widget that shows nearby cafes from the user's known cafes
//  (visits + saved favorites/want-to-try).
//

import WidgetKit
import SwiftUI

// MARK: - Widget Configuration

struct NearbyCafeWidget: Widget {
    let kind: String = "NearbyCafeWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NearbyCafeProvider()) { entry in
            NearbyCafeEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetDS.Colors.widgetBackground
                }
        }
        .configurationDisplayName("Nearby Cafes")
        .description("Quick access to nearby coffee spots.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Entry

struct NearbyCafeEntry: TimelineEntry {
    let date: Date
    let nearbyCafes: [WidgetCafe]
    
    static var placeholder: NearbyCafeEntry {
        NearbyCafeEntry(
            date: Date(),
            nearbyCafes: [
                WidgetCafe(
                    id: "cafe-1",
                    name: "Blue Bottle Coffee",
                    address: "123 Main St",
                    city: "Brooklyn",
                    country: "USA",
                    latitude: 40.7128,
                    longitude: -74.0060,
                    isFavorite: true,
                    wantToTry: false,
                    averageRating: 4.7,
                    visitCount: 12,
                    distanceMeters: 150
                ),
                WidgetCafe(
                    id: "cafe-2",
                    name: "Stumptown",
                    address: "456 Oak Ave",
                    city: "Brooklyn",
                    country: "USA",
                    latitude: 40.7158,
                    longitude: -74.0070,
                    isFavorite: false,
                    wantToTry: true,
                    averageRating: 4.5,
                    visitCount: 8,
                    distanceMeters: 450
                ),
                WidgetCafe(
                    id: "cafe-3",
                    name: "Intelligentsia",
                    address: "789 Pine Ln",
                    city: "Brooklyn",
                    country: "USA",
                    latitude: 40.7188,
                    longitude: -74.0080,
                    isFavorite: false,
                    wantToTry: false,
                    averageRating: 4.8,
                    visitCount: 5,
                    distanceMeters: 900
                )
            ]
        )
    }
    
    static var empty: NearbyCafeEntry {
        NearbyCafeEntry(date: Date(), nearbyCafes: [])
    }
}

// MARK: - Timeline Provider

struct NearbyCafeProvider: TimelineProvider {
    func placeholder(in context: Context) -> NearbyCafeEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (NearbyCafeEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            let entry = createEntry()
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<NearbyCafeEntry>) -> Void) {
        let entry = createEntry()
        
        // Refresh every 30 minutes (location-based, more frequent updates)
        let refreshDate = Date().addingTimeInterval(30 * 60)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func createEntry() -> NearbyCafeEntry {
        let data = WidgetDataStore.shared.load()
        
        // Sort by distance and take top 3
        let sorted = data.nearbyCafes
            .filter { $0.distanceMeters != nil }
            .sorted { ($0.distanceMeters ?? .infinity) < ($1.distanceMeters ?? .infinity) }
        
        return NearbyCafeEntry(
            date: Date(),
            nearbyCafes: Array(sorted.prefix(3))
        )
    }
}

// MARK: - Widget Views

struct NearbyCafeEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: NearbyCafeEntry
    
    var body: some View {
        if entry.nearbyCafes.isEmpty {
            EmptyNearbyCafeView()
        } else {
            switch family {
            case .systemSmall:
                SmallNearbyCafeView(cafes: entry.nearbyCafes)
            case .systemMedium:
                MediumNearbyCafeView(cafes: entry.nearbyCafes)
            default:
                SmallNearbyCafeView(cafes: entry.nearbyCafes)
            }
        }
    }
}

// MARK: - Small Widget View

struct SmallNearbyCafeView: View {
    let cafes: [WidgetCafe]
    
    var body: some View {
        if let closest = cafes.first {
            // Hero layout - closest cafe takes 80% of space
            Link(destination: WidgetDeepLink.mapCafe(cafeId: closest.id) ?? WidgetDeepLink.map!) {
                ZStack {
                    // Subtle blue tint for "nearby" feeling
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(WidgetDS.Gradients.blueSubtle)
                            .frame(height: 90)
                    }
                    
                    VStack(alignment: .leading, spacing: WidgetDS.Spacing.contentSpacing) {
                        Spacer()
                        
                        // Large distance badge with blue gradient (18pt bold)
                        if let distance = closest.distanceString {
                            DistanceBadge(distance: distance, isProminent: true)
                        }
                        
                        // Cafe name - 18pt bold, 2 lines max
                        Text(closest.name)
                            .font(WidgetDS.Typography.contentTitle)
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        
                        // Larger rating
                        if closest.averageRating > 0 {
                            EnhancedRatingDisplay(rating: closest.averageRating, showStars: false, size: 12)
                        }
                        
                        // Other cafes count - more prominent
                        if cafes.count > 1 {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(WidgetDS.Colors.blueAccent)
                                Text("+\(cafes.count - 1) more nearby")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(WidgetDS.Colors.textSecondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(WidgetDS.Spacing.widgetPadding)
                }
            }
        }
    }
}

// MARK: - Medium Widget View

struct MediumNearbyCafeView: View {
    let cafes: [WidgetCafe]
    
    var body: some View {
        ZStack {
            // Subtle blue tint background
            VStack {
                Spacer()
                Rectangle()
                    .fill(WidgetDS.Gradients.blueSubtle)
                    .frame(height: 80)
            }
            
            VStack(alignment: .leading, spacing: WidgetDS.Spacing.contentSpacing) {
                // Header with prominent title
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(WidgetDS.Colors.blueAccent)
                        Text("Nearby")
                            .font(WidgetDS.Typography.widgetTitle)
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                    }
                    Spacer()
                    
                    Link(destination: WidgetDeepLink.map!) {
                        HStack(spacing: 4) {
                            Text("Map")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(WidgetDS.Colors.blueAccent)
                    }
                }
                
                // Larger distance indicators, bigger cafe names
                ForEach(cafes.prefix(3)) { cafe in
                    Link(destination: WidgetDeepLink.mapCafe(cafeId: cafe.id) ?? WidgetDeepLink.map!) {
                        EnhancedNearbyCafeRow(cafe: cafe)
                    }
                }
                
                Spacer()
            }
            .padding(WidgetDS.Spacing.widgetPadding)
        }
    }
}

// MARK: - Nearby Cafe Row (Legacy)

struct NearbyCafeRow: View {
    let cafe: WidgetCafe
    
    var body: some View {
        HStack(spacing: WidgetDS.Spacing.md) {
            // Distance indicator
            VStack(spacing: 2) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 10))
                    .foregroundColor(WidgetDS.Colors.blueAccent)
                
                if let distance = cafe.distanceString {
                    Text(distance)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(WidgetDS.Colors.blueAccent)
                }
            }
            .frame(width: 40)
            
            // Cafe info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(cafe.name)
                        .font(WidgetDS.Typography.body)
                        .foregroundColor(WidgetDS.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Favorite/want-to-try indicator
                    if cafe.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 9))
                            .foregroundColor(WidgetDS.Colors.redAccent)
                    } else if cafe.wantToTry {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 9))
                            .foregroundColor(WidgetDS.Colors.yellowAccent)
                    }
                }
                
                HStack(spacing: WidgetDS.Spacing.sm) {
                    if let city = cafe.city {
                        Text(city)
                            .font(WidgetDS.Typography.caption)
                            .foregroundColor(WidgetDS.Colors.textTertiary)
                    }
                    
                    if cafe.averageRating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(WidgetDS.Colors.yellowAccent)
                            Text(String(format: "%.1f", cafe.averageRating))
                                .font(.system(size: 10))
                                .foregroundColor(WidgetDS.Colors.textSecondary)
                        }
                    }
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(WidgetDS.Colors.textTertiary)
        }
    }
}

// MARK: - Enhanced Nearby Cafe Row (Larger indicators, visual scale/size)

struct EnhancedNearbyCafeRow: View {
    let cafe: WidgetCafe
    
    var body: some View {
        HStack(spacing: WidgetDS.Spacing.contentSpacing) {
            // Prominent distance badge
            if let distance = cafe.distanceString {
                DistanceBadge(distance: distance, isProminent: false)
                    .frame(width: 70)
            }
            
            // Cafe info with bigger names
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(cafe.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(WidgetDS.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Favorite/bookmark indicator
                    if cafe.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundColor(WidgetDS.Colors.redAccent)
                    } else if cafe.wantToTry {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 11))
                            .foregroundColor(WidgetDS.Colors.yellowAccent)
                    }
                }
                
                HStack(spacing: 8) {
                    if let city = cafe.city {
                        Text(city)
                            .font(.system(size: 12))
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                    }
                    
                    if cafe.averageRating > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(WidgetDS.Colors.yellowAccent)
                            Text(String(format: "%.1f", cafe.averageRating))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(WidgetDS.Colors.textPrimary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Empty State View

struct EmptyNearbyCafeView: View {
    var body: some View {
        Link(destination: WidgetDeepLink.map!) {
            ZStack {
                // Blue tint background
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(WidgetDS.Gradients.blueSubtle)
                        .frame(height: 90)
                }
                
                VStack(spacing: WidgetDS.Spacing.contentSpacing) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(WidgetDS.Colors.blueAccent)
                        Text("Nearby")
                            .font(WidgetDS.Typography.widgetTitle)
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Image(systemName: "map.fill")
                        .font(.system(size: 40, weight: .medium)) // Reduced from 48
                        .foregroundColor(WidgetDS.Colors.blueAccent.opacity(0.4))
                    
                    VStack(spacing: 4) { // Reduced spacing
                        Text("Nothing nearby")
                            .font(.system(size: 15, weight: .bold)) // Reduced from 17
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                        
                        Text("Explore the map")
                            .font(.system(size: 13, weight: .medium)) // Reduced from 14
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
    NearbyCafeWidget()
} timeline: {
    NearbyCafeEntry.placeholder
    NearbyCafeEntry.empty
}

#Preview(as: .systemMedium) {
    NearbyCafeWidget()
} timeline: {
    NearbyCafeEntry.placeholder
    NearbyCafeEntry.empty
}

