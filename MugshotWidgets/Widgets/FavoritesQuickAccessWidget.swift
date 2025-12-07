//
//  FavoritesQuickAccessWidget.swift
//  MugshotWidgets
//
//  A medium/large widget surfacing the user's top favorite cafes for quick access.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Configuration

struct FavoritesQuickAccessWidget: Widget {
    let kind: String = "FavoritesQuickAccessWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoritesQuickAccessProvider()) { entry in
            FavoritesQuickAccessEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetDS.Colors.widgetBackground
                }
        }
        .configurationDisplayName("Favorite Cafes")
        .description("Quick access to your favorite coffee spots.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Timeline Entry

struct FavoritesQuickAccessEntry: TimelineEntry {
    let date: Date
    let favoriteCafes: [WidgetCafe]
    
    static var placeholder: FavoritesQuickAccessEntry {
        FavoritesQuickAccessEntry(
            date: Date(),
            favoriteCafes: [
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
                    distanceMeters: 450
                ),
                WidgetCafe(
                    id: "cafe-2",
                    name: "Stumptown Coffee",
                    address: "456 Oak Ave",
                    city: "Manhattan",
                    country: "USA",
                    latitude: 40.7589,
                    longitude: -73.9851,
                    isFavorite: true,
                    wantToTry: false,
                    averageRating: 4.5,
                    visitCount: 8,
                    distanceMeters: 1200
                ),
                WidgetCafe(
                    id: "cafe-3",
                    name: "Intelligentsia",
                    address: "789 Pine Ln",
                    city: "Chelsea",
                    country: "USA",
                    latitude: 40.7466,
                    longitude: -73.9972,
                    isFavorite: true,
                    wantToTry: false,
                    averageRating: 4.8,
                    visitCount: 5,
                    distanceMeters: 2300
                )
            ]
        )
    }
    
    static var empty: FavoritesQuickAccessEntry {
        FavoritesQuickAccessEntry(date: Date(), favoriteCafes: [])
    }
}

// MARK: - Timeline Provider

struct FavoritesQuickAccessProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoritesQuickAccessEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (FavoritesQuickAccessEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            let entry = createEntry()
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritesQuickAccessEntry>) -> Void) {
        let entry = createEntry()
        
        // Refresh every 2 hours (favorites don't change often)
        let refreshDate = Date().addingTimeInterval(2 * 60 * 60)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func createEntry() -> FavoritesQuickAccessEntry {
        let data = WidgetDataStore.shared.load()
        return FavoritesQuickAccessEntry(
            date: Date(),
            favoriteCafes: Array(data.favoriteCafes.prefix(6))
        )
    }
}

// MARK: - Widget Views

struct FavoritesQuickAccessEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: FavoritesQuickAccessEntry
    
    var body: some View {
        if entry.favoriteCafes.isEmpty {
            EmptyFavoritesView()
        } else {
            switch family {
            case .systemMedium:
                MediumFavoritesView(cafes: entry.favoriteCafes)
            case .systemLarge:
                LargeFavoritesView(cafes: entry.favoriteCafes)
            default:
                MediumFavoritesView(cafes: entry.favoriteCafes)
            }
        }
    }
}

// MARK: - Medium Widget View

struct MediumFavoritesView: View {
    let cafes: [WidgetCafe]
    
    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.rowSpacing) {
            // Larger title with bigger heart icon (14pt)
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
                    .foregroundColor(WidgetDS.Colors.redAccent)
                Text("Favorites")
                    .font(WidgetDS.Typography.widgetTitle)
                    .foregroundColor(WidgetDS.Colors.textPrimary)
                Spacer()
            }
            
            // Cafe rows with more breathing room (16pt gaps)
            ForEach(cafes.prefix(3)) { cafe in
                Link(destination: WidgetDeepLink.cafeDetail(cafeId: cafe.id) ?? WidgetDeepLink.saved!) {
                    EnhancedFavoriteCafeRow(cafe: cafe)
                }
            }
            
            Spacer()
        }
        .padding(WidgetDS.Spacing.widgetPadding)
    }
}

// MARK: - Large Widget View

struct LargeFavoritesView: View {
    let cafes: [WidgetCafe]
    
    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.contentSpacing) {
            // Header with prominent title
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                        .foregroundColor(WidgetDS.Colors.redAccent)
                    Text("Favorites")
                        .font(WidgetDS.Typography.widgetTitle)
                        .foregroundColor(WidgetDS.Colors.textPrimary)
                }
                Spacer()
                
                Link(destination: WidgetDeepLink.saved!) {
                    HStack(spacing: 4) {
                        Text("See all")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(WidgetDS.Colors.primaryAccent)
                }
            }
            
            // Cafe rows with better spacing
            ForEach(cafes.prefix(6)) { cafe in
                Link(destination: WidgetDeepLink.cafeDetail(cafeId: cafe.id) ?? WidgetDeepLink.saved!) {
                    EnhancedFavoriteCafeRow(cafe: cafe)
                }
            }
            
            Spacer()
        }
        .padding(WidgetDS.Spacing.widgetPadding)
    }
}

// MARK: - Favorite Cafe Row (Legacy)

struct FavoriteCafeRow: View {
    let cafe: WidgetCafe
    let compact: Bool
    
    var body: some View {
        HStack(spacing: WidgetDS.Spacing.md) {
            // Cafe icon
            ZStack {
                Circle()
                    .fill(WidgetDS.Colors.mintSoftFill)
                    .frame(width: compact ? 28 : 36, height: compact ? 28 : 36)
                
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: compact ? 12 : 14))
                    .foregroundColor(WidgetDS.Colors.primaryAccent)
            }
            
            // Cafe info
            VStack(alignment: .leading, spacing: 2) {
                Text(cafe.name)
                    .font(compact ? WidgetDS.Typography.body : WidgetDS.Typography.headline)
                    .foregroundColor(WidgetDS.Colors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: WidgetDS.Spacing.sm) {
                    if let city = cafe.city {
                        Text(city)
                            .font(WidgetDS.Typography.caption)
                            .foregroundColor(WidgetDS.Colors.textTertiary)
                    }
                    
                    if let distance = cafe.distanceString {
                        Text("•")
                            .font(WidgetDS.Typography.caption)
                            .foregroundColor(WidgetDS.Colors.textTertiary)
                        Text(distance)
                            .font(WidgetDS.Typography.caption)
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // Rating
            if cafe.averageRating > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(WidgetDS.Colors.yellowAccent)
                    Text(String(format: "%.1f", cafe.averageRating))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WidgetDS.Colors.textSecondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(WidgetDS.Colors.textTertiary)
        }
    }
}

// MARK: - Enhanced Favorite Cafe Row (Rounded squares with gradients, larger text)

struct EnhancedFavoriteCafeRow: View {
    let cafe: WidgetCafe
    
    var body: some View {
        HStack(spacing: WidgetDS.Spacing.contentSpacing) {
            // Rounded square icon (40x40) with mint gradient
            ZStack {
                RoundedRectangle(cornerRadius: WidgetDS.Radius.md)
                    .fill(WidgetDS.Gradients.mintSubtle)
                    .frame(width: 44, height: 44)
                
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(WidgetDS.Colors.primaryAccent)
            }
            
            // Cafe info with larger names (16pt semibold)
            VStack(alignment: .leading, spacing: 4) {
                Text(cafe.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(WidgetDS.Colors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let city = cafe.city {
                        Text(city)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                    }
                    
                    if let distance = cafe.distanceString {
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(WidgetDS.Colors.textTertiary)
                        Text(distance)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(WidgetDS.Colors.blueAccent)
                    }
                }
            }
            
            Spacer()
            
            // Prominent rating
            if cafe.averageRating > 0 {
                EnhancedBadge(
                    text: String(format: "%.1f", cafe.averageRating),
                    icon: "star.fill",
                    backgroundColor: WidgetDS.Colors.yellowAccent.opacity(0.15),
                    foregroundColor: WidgetDS.Colors.textPrimary
                )
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Empty State View

struct EmptyFavoritesView: View {
    var body: some View {
        Link(destination: WidgetDeepLink.saved ?? WidgetDeepLink.map!) {
            VStack(spacing: WidgetDS.Spacing.contentSpacing) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundColor(WidgetDS.Colors.redAccent)
                    Text("Favorites")
                        .font(WidgetDS.Typography.widgetTitle)
                        .foregroundColor(WidgetDS.Colors.textPrimary)
                    Spacer()
                }
                
                Spacer()
                
                // Larger heart icon
                Image(systemName: "heart")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(WidgetDS.Colors.redAccent.opacity(0.3))
                
                VStack(spacing: 8) {
                    Text("No favorites yet")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(WidgetDS.Colors.textPrimary)
                    
                    Text("Find cafes you love")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(WidgetDS.Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding(WidgetDS.Spacing.widgetPadding)
        }
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    FavoritesQuickAccessWidget()
} timeline: {
    FavoritesQuickAccessEntry.placeholder
    FavoritesQuickAccessEntry.empty
}

#Preview(as: .systemLarge) {
    FavoritesQuickAccessWidget()
} timeline: {
    FavoritesQuickAccessEntry.placeholder
}

