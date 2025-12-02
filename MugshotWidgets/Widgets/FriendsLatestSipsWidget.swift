//
//  FriendsLatestSipsWidget.swift
//  MugshotWidgets
//
//  A medium widget that cycles through friends' latest public visits,
//  showing one friend's recent visit at a time.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Configuration

struct FriendsLatestSipsWidget: Widget {
    let kind: String = "FriendsLatestSipsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FriendsLatestSipsProvider()) { entry in
            FriendsLatestSipsEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetDS.Colors.widgetBackground
                }
        }
        .configurationDisplayName("Friends' Latest Sips")
        .description("See what your friends are drinking.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Timeline Entry

struct FriendsLatestSipsEntry: TimelineEntry {
    let date: Date
    let visit: WidgetVisit?
    let hasFriends: Bool
    let totalFriendsVisits: Int
    
    static var placeholder: FriendsLatestSipsEntry {
        FriendsLatestSipsEntry(
            date: Date(),
            visit: WidgetVisit(
                id: "friend-visit-1",
                cafeId: "cafe-1",
                cafeName: "Blue Bottle Coffee",
                cafeCity: "Manhattan",
                drinkType: "Matcha",
                customDrinkType: nil,
                caption: "Perfect afternoon pick-me-up",
                overallScore: 4.8,
                posterPhotoURL: nil,
                createdAt: Date().addingTimeInterval(-7200),
                visibility: "everyone",
                authorId: "friend-1",
                authorDisplayName: "Alex Chen",
                authorUsername: "alexc",
                authorAvatarURL: nil
            ),
            hasFriends: true,
            totalFriendsVisits: 5
        )
    }
    
    static var noFriends: FriendsLatestSipsEntry {
        FriendsLatestSipsEntry(date: Date(), visit: nil, hasFriends: false, totalFriendsVisits: 0)
    }
    
    static var noRecentVisits: FriendsLatestSipsEntry {
        FriendsLatestSipsEntry(date: Date(), visit: nil, hasFriends: true, totalFriendsVisits: 0)
    }
}

// MARK: - Timeline Provider

struct FriendsLatestSipsProvider: TimelineProvider {
    func placeholder(in context: Context) -> FriendsLatestSipsEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (FriendsLatestSipsEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            let entries = createEntries()
            completion(entries.first ?? .noFriends)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<FriendsLatestSipsEntry>) -> Void) {
        let entries = createEntries()
        
        // If we have multiple visits, show a new one every 30 minutes
        // Otherwise, refresh in an hour
        let refreshDate: Date
        if entries.count > 1 {
            refreshDate = Date().addingTimeInterval(30 * 60) // 30 minutes
        } else {
            refreshDate = Date().addingTimeInterval(60 * 60) // 1 hour
        }
        
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func createEntries() -> [FriendsLatestSipsEntry] {
        let data = WidgetDataStore.shared.load()
        
        // Filter to recent friend visits (last 48 hours)
        let cutoffDate = Date().addingTimeInterval(-48 * 60 * 60)
        let recentFriendsVisits = data.friendsVisits.filter { $0.createdAt > cutoffDate }
        
        // Check if user has friends
        let hasFriends = !data.friendsVisits.isEmpty || data.currentUserId != nil
        
        if recentFriendsVisits.isEmpty {
            if hasFriends {
                return [FriendsLatestSipsEntry.noRecentVisits]
            } else {
                return [FriendsLatestSipsEntry.noFriends]
            }
        }
        
        // Create timeline entries - rotate through visits
        // Show each visit for about 30 minutes
        var entries: [FriendsLatestSipsEntry] = []
        let now = Date()
        
        for (index, visit) in recentFriendsVisits.prefix(5).enumerated() {
            let entryDate = now.addingTimeInterval(Double(index) * 30 * 60)
            entries.append(FriendsLatestSipsEntry(
                date: entryDate,
                visit: visit,
                hasFriends: true,
                totalFriendsVisits: recentFriendsVisits.count
            ))
        }
        
        return entries
    }
}

// MARK: - Widget View

struct FriendsLatestSipsEntryView: View {
    var entry: FriendsLatestSipsEntry
    
    var body: some View {
        if let visit = entry.visit {
            // Has a friend's visit to show
            FriendVisitView(visit: visit, totalVisits: entry.totalFriendsVisits)
        } else if !entry.hasFriends {
            // No friends - prompt to find friends
            NoFriendsView()
        } else {
            // Has friends but no recent visits
            NoRecentVisitsView()
        }
    }
}

// MARK: - Friend Visit View

struct FriendVisitView: View {
    let visit: WidgetVisit
    let totalVisits: Int
    
    var body: some View {
        Link(destination: WidgetDeepLink.visitDetail(visitId: visit.id) ?? WidgetDeepLink.feed!) {
            HStack(spacing: WidgetDS.Spacing.lg) {
                // Left side - friend avatar and photo
                VStack(spacing: WidgetDS.Spacing.md) {
                    // Friend avatar
                    WidgetAvatar(
                        imageURL: visit.authorAvatarURL,
                        initials: String(visit.authorDisplayNameOrUsername.prefix(1)).uppercased(),
                        size: 40
                    )
                    
                    // Visit photo placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: WidgetDS.Radius.sm)
                            .fill(WidgetDS.Colors.mintSoftFill)
                        
                        if let photoURL = visit.posterPhotoURL, let url = URL(string: photoURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure, .empty:
                                    photoPlaceholder
                                @unknown default:
                                    photoPlaceholder
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: WidgetDS.Radius.sm))
                        } else {
                            photoPlaceholder
                        }
                    }
                    .frame(width: 48, height: 48)
                }
                
                // Right side - visit details
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.sm) {
                    // Header - friend name and time
                    HStack {
                        Text(visit.authorDisplayNameOrUsername)
                            .font(WidgetDS.Typography.headline)
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                        
                        Spacer()
                        
                        Text(visit.relativeTimeString)
                            .font(WidgetDS.Typography.caption)
                            .foregroundColor(WidgetDS.Colors.textTertiary)
                    }
                    
                    // Cafe name
                    Text(visit.cafeName)
                        .font(WidgetDS.Typography.body)
                        .foregroundColor(WidgetDS.Colors.textSecondary)
                        .lineLimit(1)
                    
                    // Drink type
                    Text(visit.drinkDisplayName)
                        .font(WidgetDS.Typography.caption)
                        .foregroundColor(WidgetDS.Colors.textTertiary)
                        .lineLimit(1)
                    
                    // Rating
                    HStack(spacing: WidgetDS.Spacing.sm) {
                        WidgetStarRating(rating: visit.overallScore, size: 11)
                        Text(String(format: "%.1f", visit.overallScore))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                        
                        Spacer()
                        
                        // Indicator if there are more visits
                        if totalVisits > 1 {
                            HStack(spacing: 2) {
                                ForEach(0..<min(totalVisits, 5), id: \.self) { index in
                                    Circle()
                                        .fill(index == 0 ? WidgetDS.Colors.primaryAccent : WidgetDS.Colors.textTertiary.opacity(0.4))
                                        .frame(width: 4, height: 4)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(WidgetDS.Spacing.lg)
        }
    }
    
    private var photoPlaceholder: some View {
        Image(systemName: "cup.and.saucer.fill")
            .font(.system(size: 18))
            .foregroundColor(WidgetDS.Colors.primaryAccent.opacity(0.6))
    }
}

// MARK: - No Friends View

struct NoFriendsView: View {
    var body: some View {
        Link(destination: WidgetDeepLink.friendsHub!) {
            VStack(spacing: WidgetDS.Spacing.lg) {
                HStack {
                    Image(systemName: "person.2")
                        .font(.system(size: 10))
                        .foregroundColor(WidgetDS.Colors.primaryAccent)
                    Text("Friends' Latest Sips")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(WidgetDS.Colors.textSecondary)
                    Spacer()
                }
                
                Spacer()
                
                Image(systemName: "person.2.fill")
                    .font(.system(size: 28))
                    .foregroundColor(WidgetDS.Colors.primaryAccent)
                
                Text("No sips from friends yet")
                    .font(WidgetDS.Typography.body)
                    .foregroundColor(WidgetDS.Colors.textSecondary)
                
                Text("Find friends on Mugshot")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WidgetDS.Colors.primaryAccent)
                
                Spacer()
            }
            .padding(WidgetDS.Spacing.lg)
        }
    }
}

// MARK: - No Recent Visits View

struct NoRecentVisitsView: View {
    var body: some View {
        Link(destination: WidgetDeepLink.feed!) {
            VStack(spacing: WidgetDS.Spacing.lg) {
                HStack {
                    Image(systemName: "person.2")
                        .font(.system(size: 10))
                        .foregroundColor(WidgetDS.Colors.primaryAccent)
                    Text("Friends' Latest Sips")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(WidgetDS.Colors.textSecondary)
                    Spacer()
                }
                
                Spacer()
                
                Image(systemName: "cup.and.saucer")
                    .font(.system(size: 28))
                    .foregroundColor(WidgetDS.Colors.textTertiary)
                
                Text("No recent activity")
                    .font(WidgetDS.Typography.body)
                    .foregroundColor(WidgetDS.Colors.textSecondary)
                
                Text("Your friends haven't logged visits lately")
                    .font(WidgetDS.Typography.caption)
                    .foregroundColor(WidgetDS.Colors.textTertiary)
                
                Spacer()
            }
            .padding(WidgetDS.Spacing.lg)
        }
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    FriendsLatestSipsWidget()
} timeline: {
    FriendsLatestSipsEntry.placeholder
    FriendsLatestSipsEntry.noFriends
    FriendsLatestSipsEntry.noRecentVisits
}

