//
//  DiscoverContentView.swift
//  testMugshot
//
//  The main content view for the "Discover" scope in the Feed tab.
//  Features: Social Radar (Friends are Visiting), Spin for a Spot.
//

import SwiftUI
import CoreLocation

struct DiscoverContentView: View {
    @ObservedObject var dataManager: DataManager
    @StateObject private var locationManager = LocationManager()
    
    // State for Spin feature
    @State private var showSpinResult = false
    
    // Callbacks
    var onCafeTap: ((Cafe) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sectionVerticalGap) {
            
            // 1. Greeting Header
            greetingHeader
            
            // 2. Social Radar (Friends are Visiting)
            socialRadarSection
            
            // 3. Spin Button (inline CTA)
            spinButtonSection
            
            // 4. Coming Soon Placeholder
            comingSoonSection
        }
        .padding(.top, DS.Spacing.md)
        .onAppear {
            locationManager.requestLocationPermission()
        }
        .fullScreenCover(isPresented: $showSpinResult) {
            SpinForASpotView(
                isPresented: $showSpinResult,
                locationManager: locationManager,
                dataManager: dataManager,
                onCafeSelected: { cafe in
                    onCafeTap?(cafe)
                }
            )
        }
    }
    
    // MARK: - Greeting Header
    
    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(greeting)
                .font(DS.Typography.title1())
                .foregroundColor(DS.Colors.textPrimary)
            
            Text(formattedDate)
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = dataManager.appData.currentUser?.displayNameOrUsername
            .split(separator: " ")
            .first
            .map(String.init) ?? "Friend"
        
        switch hour {
        case 5..<12: return "Good Morning, \(name)"
        case 12..<17: return "Good Afternoon, \(name)"
        default: return "Good Evening, \(name)"
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date()).uppercased()
    }
    
    // MARK: - Social Radar Section
    
    private var socialRadarSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section Header
            HStack {
                Text("Friends are Visiting")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "person.2.fill")
                    .foregroundColor(DS.Colors.primaryAccent)
                    .font(.system(size: 16))
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Horizontal Scroll of Social Cafe Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    let cafesWithFriendActivity = getCafesWithFriendActivity()
                    
                    if cafesWithFriendActivity.isEmpty {
                        emptyFriendsPlaceholder
                    } else {
                        ForEach(cafesWithFriendActivity, id: \.cafe.id) { item in
                            SocialCafeCard(
                                cafe: item.cafe,
                                friendVisitors: item.visitors,
                                onTap: { onCafeTap?(item.cafe) }
                            )
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
        }
    }
    
    private var emptyFriendsPlaceholder: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 32))
                .foregroundColor(DS.Colors.textTertiary)
            
            Text("No recent friend activity")
                .font(DS.Typography.subheadline())
                .foregroundColor(DS.Colors.textSecondary)
            
            Text("Be the trendsetter!")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textTertiary)
        }
        .frame(width: 260, height: 120)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Radius.lg)
    }
    
    /// Returns cafes visited by friends with their visitor info
    private func getCafesWithFriendActivity() -> [(cafe: Cafe, visitors: [SocialCafeCard.FriendVisitor])] {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return [] }
        
        let friendIds = dataManager.appData.friendsSupabaseUserIds
        
        // Get visits from friends in the last 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentFriendVisits = dataManager.appData.visits.filter { visit in
            guard let authorId = visit.supabaseUserId else { return false }
            return friendIds.contains(authorId) &&
                   visit.userId != currentUserId &&
                   visit.createdAt >= sevenDaysAgo
        }
        
        // Group by cafe
        let visitsByCafe = Dictionary(grouping: recentFriendVisits) { $0.cafeId }
        
        // Build result with visitor info
        var results: [(cafe: Cafe, visitors: [SocialCafeCard.FriendVisitor])] = []
        
        for (cafeId, visits) in visitsByCafe {
            guard let cafe = dataManager.getCafe(id: cafeId) else { continue }
            
            // Build unique visitors list
            var seenIds = Set<String>()
            var visitors: [SocialCafeCard.FriendVisitor] = []
            
            for visit in visits {
                guard let visitorId = visit.supabaseUserId,
                      !seenIds.contains(visitorId) else { continue }
                seenIds.insert(visitorId)
                
                visitors.append(SocialCafeCard.FriendVisitor(
                    id: visitorId,
                    displayName: visit.authorDisplayNameOrUsername,
                    avatarURL: visit.authorAvatarURL,
                    rating: visit.overallScore
                ))
            }
            
            results.append((cafe: cafe, visitors: visitors))
        }
        
        // Sort by number of visitors (most popular first)
        return results.sorted { $0.visitors.count > $1.visitors.count }
    }
    
    // MARK: - Coming Soon Section
    
    private var comingSoonSection: some View {
        VStack(spacing: 0) {
            // Decorative icon - same size as EmptyStateView images
            Image("MugsyComingSoon")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .padding(.bottom, DS.Spacing.xs)
            
            VStack(spacing: DS.Spacing.xs) {
                Text("More features coming soon")
                    .font(DS.Typography.headline())
                    .foregroundColor(DS.Colors.textPrimary)
                
                Text("We're cooking up something special")
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    // MARK: - Spin Button Section
    
    private var spinButtonSection: some View {
        Button(action: {
            HapticsManager.shared.lightTap()
            showSpinResult = true
        }) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 20))
                
                Text("Spin for a Spot")
                    .font(DS.Typography.buttonLabel)
            }
            .foregroundColor(DS.Colors.textOnMint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.primaryAccent)
            .cornerRadius(DS.Radius.primaryButton)
            .dsCardShadow()
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.top, DS.Spacing.md)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        DiscoverContentView(dataManager: DataManager.shared)
    }
    .background(DS.Colors.screenBackground)
}

