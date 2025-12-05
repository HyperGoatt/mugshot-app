//
//  SavedCafeCard.swift
//  testMugshot
//
//  Rich cafe card with contextual information for the Saved tab.
//

import SwiftUI

enum SavedTab: String, CaseIterable, Identifiable {
    case favorites = "favorites"
    case wishlist = "wishlist"
    case library = "library"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .favorites: return "heart"
        case .wishlist: return "bookmark"
        case .library: return "cup.and.saucer"
        }
    }
    
    var selectedIcon: String {
        switch self {
        case .favorites: return "heart.fill"
        case .wishlist: return "bookmark.fill"
        case .library: return "cup.and.saucer.fill"
        }
    }
    
    var label: String {
        switch self {
        case .favorites: return "Favorites"
        case .wishlist: return "Wishlist"
        case .library: return "My Cafes"
        }
    }
    
    var sortOptions: [SavedSortOption] {
        switch self {
        case .favorites:
            return [.bestRated, .worstRated, .mostVisited, .recentlyVisited, .alphabetical]
        case .wishlist:
            return [.recentlyAdded, .closestToMe, .alphabetical]
        case .library:
            return [.bestRated, .worstRated, .mostVisited, .recentlyVisited, .alphabetical]
        }
    }
    
    var defaultSort: SavedSortOption {
        switch self {
        case .favorites: return .bestRated
        case .wishlist: return .recentlyAdded
        case .library: return .bestRated
        }
    }
}

struct SavedCafeCard: View {
    let cafe: Cafe
    let mode: SavedTab
    let lastVisitDate: Date?
    let visitCount: Int
    let favoriteDrink: String?
    let cafeImagePath: String?
    let cafeImageRemoteURL: String?
    
    @ObservedObject var dataManager: DataManager
    
    var onLogVisit: () -> Void
    var onShowDetails: () -> Void
    
    @EnvironmentObject private var hapticsManager: HapticsManager
    @State private var isPressed = false
    
    // Computed: is this a cafe that hasn't been visited yet?
    private var isUnvisited: Bool {
        visitCount == 0
    }
    
    // CTA text based on mode and visit status
    private var ctaText: String {
        if isUnvisited {
            return "Log Your First Visit"
        }
        return "Log a Visit"
    }
    
    // Format relative date
    private var lastVisitText: String? {
        guard let date = lastVisitDate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Last: \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
    
    // Show address in shortened form
    private var shortAddress: String {
        if cafe.address.isEmpty { return "" }
        // Take first line or first 30 chars
        let firstLine = cafe.address.components(separatedBy: ",").first ?? cafe.address
        if firstLine.count > 35 {
            return String(firstLine.prefix(32)) + "..."
        }
        return firstLine
    }
    
    var body: some View {
        DSBaseCard(padding: DS.Spacing.cardPadding) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Main row: thumbnail + info + actions
                HStack(alignment: .top, spacing: DS.Spacing.lg) {
                    // Larger thumbnail (88pt)
                    thumbnailView
                    
                    // Info stack
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        // Name
                        Text(cafe.name)
                            .font(DS.Typography.cardTitle)
                            .foregroundColor(DS.Colors.textPrimary)
                            .lineLimit(2)
                        
                        // Address
                        if !shortAddress.isEmpty {
                            Text(shortAddress)
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        
                        // Stats row: score + visits + last visit
                        HStack(spacing: DS.Spacing.sm) {
                            if visitCount > 0 {
                                DSScoreBadge(score: cafe.averageRating)
                                    .fixedSize()
                            }
                            
                            Text("\(visitCount) visit\(visitCount == 1 ? "" : "s")")
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                                .fixedSize()
                            
                            if let lastText = lastVisitText {
                                Text("·")
                                    .font(DS.Typography.caption1())
                                    .foregroundColor(DS.Colors.textTertiary)
                                Text(lastText)
                                    .font(DS.Typography.caption1())
                                    .foregroundColor(DS.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .lineLimit(1)
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Action buttons
                    actionButtons
                }
                
                // Favorite drink row (if applicable)
                if let drink = favoriteDrink, mode == .favorites {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "mug.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DS.Colors.primaryAccent)
                        
                        Text("Your go-to:")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                        
                        Text(drink)
                            .font(DS.Typography.caption1(.medium))
                            .foregroundColor(DS.Colors.textPrimary)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.mintSoftFill)
                    .cornerRadius(DS.Radius.sm)
                }
                
                // CTA button for Favorites and Wishlist
                if mode == .favorites || mode == .wishlist {
                    Button {
                        hapticsManager.lightTap()
                        onLogVisit()
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "cup.and.saucer")
                                .font(.system(size: 14, weight: .medium))
                            Text(ctaText)
                                .font(DS.Typography.buttonLabel)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                }
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isPressed)
        .onTapGesture {
            hapticsManager.lightTap()
            onShowDetails()
        }
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var thumbnailView: some View {
        Group {
            if let imagePath = cafeImagePath {
                PhotoThumbnailView(
                    photoPath: imagePath,
                    remoteURL: cafeImageRemoteURL,
                    size: 88
                )
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(DS.Colors.cardBackgroundAlt)
                    .frame(width: 88, height: 88)
                    .overlay(
                        Image(systemName: "cup.and.saucer")
                            .font(.system(size: 28))
                            .foregroundColor(DS.Colors.iconSubtle)
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.borderSubtle.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: DS.Spacing.md) {
            // Favorite toggle
            Button {
                hapticsManager.lightTap()
                dataManager.toggleCafeFavorite(cafe.id)
            } label: {
                Image(systemName: cafe.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundColor(cafe.isFavorite ? DS.Colors.redAccent : DS.Colors.iconDefault)
                    .scaleEffect(cafe.isFavorite ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: cafe.isFavorite)
            }
            .buttonStyle(.plain)
            
            // Bookmark toggle
            Button {
                hapticsManager.lightTap()
                dataManager.toggleCafeWantToTry(cafe.id)
            } label: {
                Image(systemName: cafe.wantToTry ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 20))
                    .foregroundColor(cafe.wantToTry ? DS.Colors.primaryAccent : DS.Colors.iconDefault)
                    .scaleEffect(cafe.wantToTry ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: cafe.wantToTry)
            }
            .buttonStyle(.plain)
        }
    }
}

