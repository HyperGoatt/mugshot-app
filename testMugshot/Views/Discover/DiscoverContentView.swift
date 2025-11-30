//
//  DiscoverContentView.swift
//  testMugshot
//
//  The main content view for the "Discover" scope in the Feed tab.
//  Features: Social Radar, Mugshot Guides, and the Spin button.
//

import SwiftUI
import CoreLocation

struct DiscoverContentView: View {
    @ObservedObject var dataManager: DataManager
    @StateObject private var locationManager = LocationManager()
    
    // State for Spin feature
    @State private var isSpinning = false
    @State private var showSpinResult = false
    @State private var spinResultCafe: Cafe?
    
    // Callbacks
    var onCafeTap: ((Cafe) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sectionVerticalGap) {
            
            // 1. Greeting Header
            greetingHeader
            
            // 2. Social Radar (Friends are Visiting)
            socialRadarSection
            
            // 3. Mugshot Guides
            guidesSection
            
            // 4. Spin Button (inline CTA)
            spinButtonSection
        }
        .padding(.top, DS.Spacing.md)
        .onAppear {
            locationManager.requestLocationPermission()
        }
        .sheet(isPresented: $showSpinResult) {
            spinResultSheet
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
    
    // MARK: - Guides Section
    
    private var guidesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Mugshot Guides")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            VStack(spacing: DS.Spacing.sm) {
                ForEach(Guide.mockGuides()) { guide in
                    GuideCard(guide: guide) {
                        // TODO: Navigate to guide detail view
                        print("Tapped guide: \(guide.title)")
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
        }
    }
    
    // MARK: - Spin Button Section
    
    private var spinButtonSection: some View {
        Button(action: performSpin) {
            HStack(spacing: DS.Spacing.sm) {
                if isSpinning {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 20))
                }
                
                Text(isSpinning ? "Finding a spot..." : "Spin for a Spot")
                    .font(DS.Typography.buttonLabel)
            }
            .foregroundColor(DS.Colors.textOnMint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.primaryAccent)
            .cornerRadius(DS.Radius.primaryButton)
            .dsCardShadow()
        }
        .disabled(isSpinning)
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.top, DS.Spacing.md)
    }
    
    // MARK: - Spin Logic
    
    private func performSpin() {
        isSpinning = true
        
        // Simulate a brief delay for effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            // Logic: Find a highly-rated cafe the user hasn't visited
            let currentUserId = dataManager.appData.currentUser?.id
            let visitedCafeIds = Set(
                dataManager.appData.visits
                    .filter { $0.userId == currentUserId }
                    .map { $0.cafeId }
            )
            
            // Filter to cafes with good ratings that user hasn't visited
            let candidates = dataManager.appData.cafes.filter { cafe in
                cafe.averageRating >= 4.0 && !visitedCafeIds.contains(cafe.id)
            }
            
            // If no unvisited cafes, fall back to all highly-rated cafes
            let pool = candidates.isEmpty
                ? dataManager.appData.cafes.filter { $0.averageRating >= 4.0 }
                : candidates
            
            if let randomCafe = pool.randomElement() {
                spinResultCafe = randomCafe
                showSpinResult = true
            }
            
            isSpinning = false
        }
    }
    
    // MARK: - Spin Result Sheet
    
    private var spinResultSheet: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Header
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 40))
                    .foregroundColor(DS.Colors.primaryAccent)
                
                Text("THE ORACLE CHOSE")
                    .font(DS.Typography.caption1(.semibold))
                    .foregroundColor(DS.Colors.textSecondary)
                    .tracking(2)
            }
            .padding(.top, DS.Spacing.xl)
            
            // Cafe Info
            if let cafe = spinResultCafe {
                VStack(spacing: DS.Spacing.sm) {
                    Text(cafe.name)
                        .font(DS.Typography.title1())
                        .foregroundColor(DS.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    if let city = cafe.city {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14))
                            Text(city)
                        }
                        .font(DS.Typography.subheadline())
                        .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                    if cafe.averageRating > 0 {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "star.fill")
                                .foregroundColor(DS.Colors.yellowAccent)
                            Text(String(format: "%.1f", cafe.averageRating))
                                .font(DS.Typography.headline())
                        }
                        .foregroundColor(DS.Colors.textPrimary)
                    }
                }
                
                // CTA Buttons
                VStack(spacing: DS.Spacing.sm) {
                    Button(action: {
                        showSpinResult = false
                        onCafeTap?(cafe)
                    }) {
                        Text("View Cafe")
                            .font(DS.Typography.buttonLabel)
                            .foregroundColor(DS.Colors.textOnMint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.md)
                            .background(DS.Colors.primaryAccent)
                            .cornerRadius(DS.Radius.primaryButton)
                    }
                    
                    Button(action: {
                        showSpinResult = false
                        performSpin()
                    }) {
                        Text("Spin Again")
                            .font(DS.Typography.buttonLabel)
                            .foregroundColor(DS.Colors.primaryAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.md)
                            .background(DS.Colors.primaryAccentSoftFill)
                            .cornerRadius(DS.Radius.primaryButton)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
            }
            
            Spacer()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        DiscoverContentView(dataManager: DataManager.shared)
    }
    .background(DS.Colors.screenBackground)
}

