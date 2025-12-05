//
//  CafeSearchResultsPanel.swift
//  testMugshot
//
//  Created by Cursor on 11/29/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct CafeSearchResultsPanel: View {
    @Binding var searchText: String
    @ObservedObject var searchService: MapSearchService
    let recentSearches: [RecentSearchEntry]
    let showRecentSearches: Bool
    var nearbySuggestions: [MKMapItem] = []
    let referenceLocation: CLLocation?
    let onMapItemSelected: (MKMapItem) -> Void
    let onRecentSelected: (RecentSearchEntry) -> Void
    var emptyRecentStateText: String = "Search for a cafe to start building your history."
    
    private var sortedRecentSearches: [RecentSearchEntry] {
        recentSearches.sorted { $0.timestamp > $1.timestamp }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            DS.Colors.cardBackground
            
            Group {
                if showRecentSearches {
                    suggestionsContent
                } else if searchService.isSearching {
                    ProgressView()
                        .padding(DS.Spacing.md)
                } else if let error = searchService.searchError {
                    feedbackView(systemImage: "exclamationmark.triangle", message: error)
                } else if searchService.searchResults.isEmpty &&
                            !searchService.isSearching &&
                            !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    feedbackView(systemImage: "magnifyingglass", message: "No results found.")
                } else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    liveResultsContent
                } else {
                    EmptyView()
                }
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
        .cornerRadius(DS.Radius.card, corners: [.bottomLeft, .bottomRight] as UIRectCorner)
    }
    
    private var suggestionsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.cardVerticalGap) {
                // 1. Nearby Suggestions
                if !nearbySuggestions.isEmpty {
                    DSSectionHeader("Nearby", subtitle: "Quick pick")
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.top, DS.Spacing.md)
                    
                    ForEach(nearbySuggestions, id: \.self) { item in
                        SearchResultRow(
                            title: item.name ?? "Unknown",
                            subtitle: MapSearchClassifier.subtitle(from: item.placemark),
                            distanceText: distanceText(for: item),
                            isCoffeeDestination: true,
                            onTap: {
                                onMapItemSelected(item)
                            }
                        )
                        .padding(.horizontal, DS.Spacing.pagePadding)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // 2. Recent Searches
                if !sortedRecentSearches.isEmpty {
                    DSSectionHeader("Recent Searches", subtitle: "Most recent first")
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.top, nearbySuggestions.isEmpty ? DS.Spacing.md : DS.Spacing.lg)
                    
                    ForEach(sortedRecentSearches) { entry in
                        RecentSearchRow(
                            entry: entry,
                            distanceText: distanceText(for: entry.coordinate),
                            onTap: {
                                onRecentSelected(entry)
                            }
                        )
                        .padding(.horizontal, DS.Spacing.pagePadding)
                    }
                    .padding(.bottom, DS.Spacing.md)
                } else if nearbySuggestions.isEmpty {
                    DSSectionHeader("Recent Searches", subtitle: "Most recent first")
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.top, DS.Spacing.md)
                    
                    Text(emptyRecentStateText)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.bottom, DS.Spacing.lg)
                }
            }
        }
    }
    
    private var liveResultsContent: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.cardVerticalGap) {
                DSSectionHeader("Results", subtitle: "Closest matches first")
                    .padding(.horizontal, DS.Spacing.pagePadding)
                    .padding(.top, DS.Spacing.md)
                
                ForEach(searchService.searchResults, id: \.self) { mapItem in
                    SearchResultRow(
                        title: mapItem.name ?? "Unknown",
                        subtitle: MapSearchClassifier.subtitle(from: mapItem.placemark),
                        distanceText: distanceText(for: mapItem),
                        isCoffeeDestination: MapSearchClassifier.isCoffeeDestination(mapItem: mapItem),
                        onTap: {
                            onMapItemSelected(mapItem)
                        }
                    )
                    .padding(.horizontal, DS.Spacing.pagePadding)
                }
            }
            .padding(.bottom, DS.Spacing.md)
        }
    }
    
    private func feedbackView(systemImage: String, message: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundColor(DS.Colors.iconSubtle)
            
            Text(message)
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
        }
        .padding(DS.Spacing.lg)
    }
    
    private func distanceText(for mapItem: MKMapItem) -> String? {
        guard let referenceLocation else { return nil }
        let meters = MapSearchClassifier.distanceInMeters(from: mapItem, referenceLocation: referenceLocation)
        return MapSearchClassifier.formattedDistance(fromMeters: meters)
    }
    
    private func distanceText(for coordinate: CLLocationCoordinate2D?) -> String? {
        guard let coordinate, let referenceLocation else { return nil }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return MapSearchClassifier.formattedDistance(fromMeters: location.distance(from: referenceLocation))
    }
}

// MARK: - Supporting Rows

private struct SearchResultRow: View {
    let title: String
    let subtitle: String?
    let distanceText: String?
    let isCoffeeDestination: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            DSBaseCard {
                HStack(spacing: DS.Spacing.md) {
                    SearchResultIconBadge(isCoffeeDestination: isCoffeeDestination)
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(title)
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textPrimary)
                            .lineLimit(1)
                        
                        if let subtitle = subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    if let distanceText {
                        Text(distanceText)
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption2())
                        .foregroundColor(DS.Colors.iconSubtle)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RecentSearchRow: View {
    let entry: RecentSearchEntry
    let distanceText: String?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            DSBaseCard {
                HStack(spacing: DS.Spacing.md) {
                    SearchResultIconBadge(isCoffeeDestination: entry.isCoffeeDestination)
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(entry.name)
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textPrimary)
                            .lineLimit(1)
                        
                        if let subtitle = entry.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                                .lineLimit(1)
                        } else if let city = entry.city, !city.isEmpty {
                            Text(city)
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    if let distanceText {
                        Text(distanceText)
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption2())
                        .foregroundColor(DS.Colors.iconSubtle)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SearchResultIconBadge: View {
    let isCoffeeDestination: Bool
    
    var body: some View {
        Circle()
            .fill(isCoffeeDestination ? DS.Colors.primaryAccentSoftFill : DS.Colors.cardBackgroundAlt)
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: isCoffeeDestination ? "cup.and.saucer.fill" : "mappin.and.ellipse")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isCoffeeDestination ? DS.Colors.primaryAccent : DS.Colors.iconDefault)
            )
    }
}


