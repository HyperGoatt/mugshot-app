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
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundColor(WidgetDS.Colors.blueAccent)
                Text("Nearby")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(WidgetDS.Colors.textSecondary)
                Spacer()
            }
            
            // Show closest cafe prominently
            if let closest = cafes.first {
                Link(destination: WidgetDeepLink.mapCafe(cafeId: closest.id) ?? WidgetDeepLink.map!) {
                    VStack(alignment: .leading, spacing: WidgetDS.Spacing.xs) {
                        Spacer()
                        
                        // Distance badge
                        if let distance = closest.distanceString {
                            HStack(spacing: 2) {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 10))
                                Text(distance)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(WidgetDS.Colors.blueAccent)
                        }
                        
                        // Cafe name
                        Text(closest.name)
                            .font(WidgetDS.Typography.headline)
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                            .lineLimit(2)
                        
                        // Rating
                        if closest.averageRating > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(WidgetDS.Colors.yellowAccent)
                                Text(String(format: "%.1f", closest.averageRating))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(WidgetDS.Colors.textSecondary)
                            }
                        }
                        
                        // Other cafes count
                        if cafes.count > 1 {
                            Text("+\(cafes.count - 1) more nearby")
                                .font(.system(size: 9))
                                .foregroundColor(WidgetDS.Colors.textTertiary)
                        }
                    }
                }
            }
        }
        .padding(WidgetDS.Spacing.lg)
    }
}

// MARK: - Medium Widget View

struct MediumNearbyCafeView: View {
    let cafes: [WidgetCafe]
    
    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundColor(WidgetDS.Colors.blueAccent)
                Text("Nearby Cafes")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(WidgetDS.Colors.textSecondary)
                Spacer()
                
                Link(destination: WidgetDeepLink.map!) {
                    Text("Open Map")
                        .font(.system(size: 10))
                        .foregroundColor(WidgetDS.Colors.primaryAccent)
                }
            }
            
            // Cafe list
            ForEach(cafes.prefix(3)) { cafe in
                Link(destination: WidgetDeepLink.mapCafe(cafeId: cafe.id) ?? WidgetDeepLink.map!) {
                    NearbyCafeRow(cafe: cafe)
                }
            }
            
            Spacer()
        }
        .padding(WidgetDS.Spacing.lg)
    }
}

// MARK: - Nearby Cafe Row

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

// MARK: - Empty State View

struct EmptyNearbyCafeView: View {
    var body: some View {
        Link(destination: WidgetDeepLink.map!) {
            VStack(spacing: WidgetDS.Spacing.lg) {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundColor(WidgetDS.Colors.blueAccent)
                    Text("Nearby")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(WidgetDS.Colors.textSecondary)
                    Spacer()
                }
                
                Spacer()
                
                Image(systemName: "map")
                    .font(.system(size: 28))
                    .foregroundColor(WidgetDS.Colors.textTertiary)
                
                Text("No nearby cafes yet")
                    .font(WidgetDS.Typography.body)
                    .foregroundColor(WidgetDS.Colors.textSecondary)
                
                Text("Explore the map in Mugshot")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(WidgetDS.Colors.primaryAccent)
                
                Spacer()
            }
            .padding(WidgetDS.Spacing.lg)
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

