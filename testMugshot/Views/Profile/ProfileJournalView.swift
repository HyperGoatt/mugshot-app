//
//  ProfileJournalView.swift
//  testMugshot
//
//  Private journal view showing personal coffee stats, streaks, and insights.
//

import SwiftUI

struct ProfileJournalView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject var tabCoordinator: TabCoordinator
    
    // MARK: - Computed Properties
    
    private var userVisits: [Visit] {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return [] }
        return dataManager.appData.visits
            .filter { $0.userId == currentUserId }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private var uniqueCafeCount: Int {
        Set(userVisits.map { $0.cafeId }).count
    }
    
    private var currentStreak: Int {
        JournalStatsHelper.calculateCurrentStreak(visits: userVisits)
    }
    
    private var longestStreak: Int {
        JournalStatsHelper.calculateLongestStreak(visits: userVisits)
    }
    
    private var notesCount: Int {
        JournalStatsHelper.notesCount(from: userVisits)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: DS.Spacing.cardVerticalGap) {
            // Today's Mugshot
            TodaysMugshotCard(
                visit: JournalStatsHelper.todaysVisit(from: userVisits),
                cafeLookup: { dataManager.getCafe(id: $0) },
                onLogVisit: {
                    tabCoordinator.selectedTab = 2 // Switch to Add tab
                }
            )
            
            // Streaks & Consistency
            StreaksCard(
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                weekdayMap: JournalStatsHelper.weekdayVisitMap(visits: userVisits)
            )
            
            // Coffee Stats
            CoffeeStatsCard(
                stats: dataManager.getUserStats(),
                visitsThisWeek: JournalStatsHelper.visitsInLast7Days(visits: userVisits),
                visitsLast30Days: JournalStatsHelper.visitsInLast30Days(visits: userVisits)
            )
            
            // Top Cafés
            TopCafesCard(
                topCafes: JournalStatsHelper.topCafes(
                    from: userVisits,
                    cafeLookup: { dataManager.getCafe(id: $0) }
                ),
                dataManager: dataManager
            )
            
            // Badges
            BadgesCard(
                userVisits: userVisits,
                onLogVisit: {
                    tabCoordinator.selectedTab = 2 // Switch to Add tab
                }
            )
            
            // Notes (full section)
            NotesCard(
                userVisits: userVisits,
                dataManager: dataManager,
                onLogVisit: {
                    tabCoordinator.selectedTab = 2 // Switch to Add tab
                }
            )
            
            // Privacy Footer
            JournalPrivacyFooter()
        }
        .onAppear {
            print("[Journal] Loaded with \(userVisits.count) visits, \(uniqueCafeCount) cafes")
            print("[Journal] Current streak: \(currentStreak), longest: \(longestStreak)")
            
            let visitsWithNotes = JournalStatsHelper.allVisitsWithNotes(from: userVisits)
            let groupedNotes = JournalStatsHelper.groupVisitsByMonth(visitsWithNotes)
            print("[Journal] Notes count: \(visitsWithNotes.count)")
            print("[Journal] Notes grouped into \(groupedNotes.count) month sections")
            
            // Badge logging
            let badgeStates = BadgeEngine.computeBadges(visits: userVisits)
            let unlockedCount = badgeStates.filter { $0.isUnlocked }.count
            let lockedCount = badgeStates.count - unlockedCount
            print("[Journal] Rendering Badges card – visits: \(userVisits.count), unlocked: \(unlockedCount), locked: \(lockedCount)")
        }
    }
}

// MARK: - Today's Mugshot Card

private struct TodaysMugshotCard: View {
    let visit: Visit?
    let cafeLookup: (UUID) -> Cafe?
    let onLogVisit: () -> Void
    
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSSectionHeader("Today's Mugshot")
                
                if let visit = visit {
                    // Has a visit today
                    HStack(spacing: DS.Spacing.md) {
                        // Coffee icon
                        ZStack {
                            Circle()
                                .fill(DS.Colors.primaryAccentSoftFill)
                                .frame(width: 48, height: 48)
                            
                            Text("☕️")
                                .font(.system(size: 24))
                        }
                        
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            if let cafe = cafeLookup(visit.cafeId) {
                                Text("Today at \(cafe.name)")
                                    .font(DS.Typography.headline())
                                    .foregroundColor(DS.Colors.textPrimary)
                            }
                            
                            HStack(spacing: DS.Spacing.sm) {
                                Text(visit.drinkType.rawValue)
                                    .font(DS.Typography.caption1())
                                    .foregroundColor(DS.Colors.textSecondary)
                                
                                Text("·")
                                    .foregroundColor(DS.Colors.textTertiary)
                                
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(DS.Colors.yellowAccent)
                                    
                                    Text(String(format: "%.1f", visit.overallScore))
                                        .font(DS.Typography.caption1(.medium))
                                        .foregroundColor(DS.Colors.textSecondary)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                } else {
                    // Empty state
                    VStack(spacing: DS.Spacing.md) {
                        Text("☕️")
                            .font(.system(size: 48))
                        
                        Text("No mugshot yet today")
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textSecondary)
                        
                        Button(action: onLogVisit) {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                Text("Log a visit")
                                    .font(DS.Typography.buttonLabel)
                            }
                            .foregroundColor(DS.Colors.textOnMint)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.md)
                            .background(DS.Colors.primaryAccent)
                            .cornerRadius(DS.Radius.primaryButton)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                }
            }
        }
    }
}

// MARK: - Streaks Card

private struct StreaksCard: View {
    let currentStreak: Int
    let longestStreak: Int
    let weekdayMap: [(dayLetter: String, date: Date, hasVisit: Bool)]
    
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSSectionHeader("Streaks & Consistency")
                
                // Streak numbers
                HStack(spacing: DS.Spacing.xxl) {
                    StreakStat(value: currentStreak, label: "Current streak")
                    StreakStat(value: longestStreak, label: "Longest streak")
                    Spacer()
                }
                
                // 7-day mini row
                HStack(spacing: 0) {
                    ForEach(Array(weekdayMap.enumerated()), id: \.offset) { _, day in
                        WeekdayIndicator(
                            letter: day.dayLetter,
                            hasVisit: day.hasVisit,
                            isToday: Calendar.current.isDateInToday(day.date)
                        )
                    }
                }
                .padding(.top, DS.Spacing.sm)
            }
        }
    }
}

private struct StreakStat: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Text("\(value)")
                    .font(DS.Typography.numericStat)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Text("days")
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
            Text(label)
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textTertiary)
        }
    }
}

private struct WeekdayIndicator: View {
    let letter: String
    let hasVisit: Bool
    let isToday: Bool
    
    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(letter)
                .font(DS.Typography.caption2(.medium))
                .foregroundColor(isToday ? DS.Colors.primaryAccent : DS.Colors.textTertiary)
            
            Circle()
                .fill(hasVisit ? DS.Colors.primaryAccent : DS.Colors.borderSubtle)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(isToday ? DS.Colors.primaryAccent : Color.clear, lineWidth: 2)
                )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Coffee Stats Card

private struct CoffeeStatsCard: View {
    let stats: (totalVisits: Int, totalCafes: Int, averageScore: Double, favoriteDrinkType: DrinkType?)
    let visitsThisWeek: Int
    let visitsLast30Days: Int
    
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSSectionHeader("Coffee Stats")
                
                // Main stats grid
                HStack(spacing: DS.Spacing.lg) {
                    StatItem(value: "\(stats.totalVisits)", label: "Total visits")
                    StatItem(value: "\(stats.totalCafes)", label: "Cafés")
                    StatItem(
                        value: stats.averageScore > 0 ? String(format: "%.1f", stats.averageScore) : "-",
                        label: "Avg rating"
                    )
                }
                
                Divider()
                    .background(DS.Colors.dividerSubtle)
                
                // Recent activity
                HStack(spacing: DS.Spacing.xxl) {
                    RecentActivityStat(value: visitsThisWeek, label: "This week")
                    RecentActivityStat(value: visitsLast30Days, label: "Last 30 days")
                    Spacer()
                }
            }
        }
    }
}

private struct StatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(value)
                .font(DS.Typography.numericStat)
                .foregroundColor(DS.Colors.textPrimary)
            
            Text(label)
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RecentActivityStat: View {
    let value: Int
    let label: String
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text("\(value)")
                .font(DS.Typography.headline())
                .foregroundColor(DS.Colors.primaryAccent)
            
            Text(value == 1 ? "visit" : "visits")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
            
            Text("·")
                .foregroundColor(DS.Colors.textTertiary)
            
            Text(label)
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textTertiary)
        }
    }
}

// MARK: - Top Cafés Card

private struct TopCafesCard: View {
    let topCafes: [(cafe: Cafe, visitCount: Int, avgRating: Double)]
    @ObservedObject var dataManager: DataManager
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    
    var body: some View {
        if !topCafes.isEmpty {
            DSBaseCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    DSSectionHeader("Top Cafés")
                    
                    ForEach(Array(topCafes.enumerated()), id: \.element.cafe.id) { index, item in
                        if index > 0 {
                            Divider()
                                .background(DS.Colors.dividerSubtle)
                        }
                        
                        TopCafeRow(
                            cafe: item.cafe,
                            visitCount: item.visitCount,
                            avgRating: item.avgRating,
                            rank: index + 1,
                            onTap: {
                                selectedCafe = item.cafe
                                showCafeDetail = true
                            }
                        )
                    }
                }
            }
            .sheet(isPresented: $showCafeDetail) {
                if let cafe = selectedCafe {
                    CafeDetailView(cafe: cafe, dataManager: dataManager)
                }
            }
        }
    }
}

private struct TopCafeRow: View {
    let cafe: Cafe
    let visitCount: Int
    let avgRating: Double
    let rank: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(rank == 1 ? DS.Colors.primaryAccent : DS.Colors.cardBackgroundAlt)
                        .frame(width: 28, height: 28)
                    
                    Text("\(rank)")
                        .font(DS.Typography.caption1(.semibold))
                        .foregroundColor(rank == 1 ? DS.Colors.textOnMint : DS.Colors.textSecondary)
                }
                
                // Cafe info
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(cafe.name)
                        .font(DS.Typography.headline())
                        .foregroundColor(DS.Colors.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: DS.Spacing.sm) {
                        if let city = cafe.city, !city.isEmpty {
                            Text(city)
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textTertiary)
                        }
                        
                        Text("·")
                            .foregroundColor(DS.Colors.textTertiary)
                        
                        Text("\(visitCount) \(visitCount == 1 ? "visit" : "visits")")
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Rating
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.yellowAccent)
                    
                    Text(String(format: "%.1f", avgRating))
                        .font(DS.Typography.subheadline(.medium))
                        .foregroundColor(DS.Colors.textPrimary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.iconSubtle)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Badges Card

private struct BadgesCard: View {
    let userVisits: [Visit]
    let onLogVisit: () -> Void
    
    @State private var selectedBadge: BadgeState?
    @State private var showBadgeDetail = false
    
    private var badgeStates: [BadgeState] {
        BadgeEngine.computeBadges(visits: userVisits)
    }
    
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    DSSectionHeader("Badges")
                    
                    Text("Collect badges as you log your coffee journey.")
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                
                if userVisits.isEmpty {
                    // Empty state
                    badgesEmptyState
                } else {
                    // Horizontal scrolling badge chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.sm) {
                            ForEach(badgeStates) { badge in
                                BadgeChip(
                                    badge: badge,
                                    onTap: {
                                        selectedBadge = badge
                                        showBadgeDetail = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 1) // Prevent clipping
                    }
                    .padding(.horizontal, -DS.Spacing.cardPadding)
                    .padding(.horizontal, DS.Spacing.cardPadding)
                    
                    // Summary line
                    badgeSummary
                }
            }
        }
        .sheet(isPresented: $showBadgeDetail) {
            if let badge = selectedBadge {
                BadgeDetailSheet(badge: badge)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var badgesEmptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("☕️")
                .font(.system(size: 48))
            
            Text("Start logging visits to unlock your first badge.")
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: onLogVisit) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Log a visit")
                        .font(DS.Typography.buttonLabel)
                }
                .foregroundColor(DS.Colors.textOnMint)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .background(DS.Colors.primaryAccent)
                .cornerRadius(DS.Radius.primaryButton)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
    }
    
    // MARK: - Summary
    
    private var badgeSummary: some View {
        let unlockedCount = badgeStates.filter { $0.isUnlocked }.count
        let totalCount = badgeStates.count
        
        return HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 12))
                .foregroundColor(DS.Colors.yellowAccent)
            
            Text("\(unlockedCount)/\(totalCount) badges unlocked")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
        }
    }
}

// MARK: - Badge Chip

private struct BadgeChip: View {
    let badge: BadgeState
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DS.Spacing.xs) {
                // Icon
                ZStack {
                    Circle()
                        .fill(badge.isUnlocked ? DS.Colors.primaryAccentSoftFill : DS.Colors.cardBackgroundAlt)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: badge.definition.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(badge.isUnlocked ? DS.Colors.primaryAccent : DS.Colors.iconSubtle)
                }
                
                // Name
                Text(badge.definition.name)
                    .font(DS.Typography.caption2(.medium))
                    .foregroundColor(badge.isUnlocked ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                    .lineLimit(1)
                    .frame(width: 72)
                
                // Progress text
                Text(badge.progressText)
                    .font(DS.Typography.caption2())
                    .foregroundColor(badge.isUnlocked ? DS.Colors.primaryAccent : DS.Colors.textTertiary)
            }
            .padding(.vertical, DS.Spacing.sm)
            .opacity(badge.isUnlocked ? 1.0 : 0.7)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Badge Detail Sheet

private struct BadgeDetailSheet: View {
    let badge: BadgeState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    // Large icon
                    ZStack {
                        Circle()
                            .fill(badge.isUnlocked ? DS.Colors.primaryAccentSoftFill : DS.Colors.cardBackgroundAlt)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: badge.definition.iconName)
                            .font(.system(size: 56))
                            .foregroundColor(badge.isUnlocked ? DS.Colors.primaryAccent : DS.Colors.iconSubtle)
                    }
                    .padding(.top, DS.Spacing.xl)
                    
                    // Badge name
                    Text(badge.definition.name)
                        .font(DS.Typography.title1())
                        .foregroundColor(DS.Colors.textPrimary)
                    
                    // Category pill
                    Text(badge.definition.category.displayName)
                        .font(DS.Typography.caption1(.medium))
                        .foregroundColor(DS.Colors.textOnMint)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Colors.primaryAccent)
                        .cornerRadius(DS.Radius.chip)
                    
                    // Description
                    Text(badge.definition.description)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                    
                    // Progress section
                    progressSection
                    
                    // How to unlock / Status
                    statusSection
                    
                    Spacer()
                }
                .padding(DS.Spacing.pagePadding)
            }
            .background(DS.Colors.screenBackground)
            .navigationTitle("Badge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.primaryAccent)
                }
            }
        }
    }
    
    // MARK: - Progress Section
    
    @ViewBuilder
    private var progressSection: some View {
        if let target = badge.targetValue, target > 1 {
            VStack(spacing: DS.Spacing.sm) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(DS.Colors.cardBackgroundAlt)
                            .frame(height: 8)
                        
                        // Fill
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(badge.isUnlocked ? DS.Colors.primaryAccent : DS.Colors.primaryAccent.opacity(0.5))
                            .frame(width: geometry.size.width * badge.progress, height: 8)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, DS.Spacing.xl)
                
                // Progress text
                Text("\(badge.currentValue) / \(target)")
                    .font(DS.Typography.headline())
                    .foregroundColor(DS.Colors.textPrimary)
            }
            .padding(.vertical, DS.Spacing.md)
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        DSBaseCard {
            VStack(spacing: DS.Spacing.sm) {
                if badge.isUnlocked {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(DS.Colors.primaryAccent)
                        
                        Text("Unlocked!")
                            .font(DS.Typography.headline())
                            .foregroundColor(DS.Colors.primaryAccent)
                    }
                } else {
                    Text("How to unlock")
                        .font(DS.Typography.caption1(.medium))
                        .foregroundColor(DS.Colors.textTertiary)
                        .textCase(.uppercase)
                    
                    Text(badge.definition.unlockHint)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
        }
        .padding(.horizontal, DS.Spacing.md)
    }
}

// MARK: - Notes Card (Full Section)

private struct NotesCard: View {
    let userVisits: [Visit]
    @ObservedObject var dataManager: DataManager
    let onLogVisit: () -> Void
    
    @State private var filterMode: NotesFilterMode = .all
    @State private var selectedCafeId: UUID?
    @State private var selectedVisitForEdit: Visit?
    @State private var showEditSheet = false
    
    enum NotesFilterMode: String, CaseIterable {
        case all = "All notes"
        case byCafe = "By café"
    }
    
    private var allNotesVisits: [Visit] {
        JournalStatsHelper.allVisitsWithNotes(from: userVisits)
    }
    
    private var cafesWithNotes: [Cafe] {
        JournalStatsHelper.cafesWithNotes(from: userVisits) { dataManager.getCafe(id: $0) }
    }
    
    private var filteredVisits: [Visit] {
        if filterMode == .byCafe, let cafeId = selectedCafeId {
            return JournalStatsHelper.filterNotesByCafe(allNotesVisits, cafeId: cafeId)
        }
        return allNotesVisits
    }
    
    private var groupedNotes: [(key: String, displayString: String, visits: [Visit])] {
        JournalStatsHelper.groupVisitsByMonth(filteredVisits)
    }
    
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSSectionHeader("Notes")
                
                if allNotesVisits.isEmpty {
                    // Empty state
                    notesEmptyState
                } else {
                    // Summary line
                    notesSummary
                    
                    // Filter controls
                    filterControls
                    
                    // Grouped notes list
                    notesListContent
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let visit = selectedVisitForEdit {
                NoteDetailEditView(
                    visit: visit,
                    cafeName: dataManager.getCafe(id: visit.cafeId)?.name ?? "Unknown Café",
                    dataManager: dataManager,
                    onDismiss: { showEditSheet = false }
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var notesEmptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundColor(DS.Colors.iconSubtle)
            
            Text("No notes yet")
                .font(DS.Typography.headline())
                .foregroundColor(DS.Colors.textPrimary)
            
            Text("Use the Notes field when logging a visit to capture your thoughts.")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.md)
            
            Button(action: onLogVisit) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Log a visit")
                        .font(DS.Typography.buttonLabel)
                }
                .foregroundColor(DS.Colors.textOnMint)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .background(DS.Colors.primaryAccent)
                .cornerRadius(DS.Radius.primaryButton)
            }
            .padding(.top, DS.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
    }
    
    // MARK: - Summary
    
    private var notesSummary: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text("You've logged")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
            
            Text("\(allNotesVisits.count)")
                .font(DS.Typography.caption1(.semibold))
                .foregroundColor(DS.Colors.primaryAccent)
            
            Text(allNotesVisits.count == 1 ? "note" : "notes")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
            
            Text("so far.")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
        }
    }
    
    // MARK: - Filter Controls
    
    private var filterControls: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Segmented control for filter mode
            HStack(spacing: 0) {
                ForEach(NotesFilterMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            filterMode = mode
                            if mode == .all {
                                selectedCafeId = nil
                            } else if selectedCafeId == nil, let firstCafe = cafesWithNotes.first {
                                selectedCafeId = firstCafe.id
                            }
                        }
                    }) {
                        Text(mode.rawValue)
                            .font(DS.Typography.caption1(.medium))
                            .foregroundColor(filterMode == mode ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(
                                filterMode == mode
                                    ? DS.Colors.cardBackground
                                    : Color.clear
                            )
                            .cornerRadius(DS.Radius.md)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(DS.Colors.cardBackgroundAlt)
            .cornerRadius(DS.Radius.lg)
            
            // Café picker when "By café" is selected
            if filterMode == .byCafe && !cafesWithNotes.isEmpty {
                Menu {
                    ForEach(cafesWithNotes) { cafe in
                        Button(action: {
                            selectedCafeId = cafe.id
                        }) {
                            HStack {
                                Text(cafe.name)
                                if selectedCafeId == cafe.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCafeName)
                            .font(DS.Typography.subheadline())
                            .foregroundColor(DS.Colors.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DS.Colors.iconSubtle)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.cardBackgroundAlt)
                    .cornerRadius(DS.Radius.md)
                }
            }
        }
    }
    
    private var selectedCafeName: String {
        if let cafeId = selectedCafeId,
           let cafe = dataManager.getCafe(id: cafeId) {
            return cafe.name
        }
        return "Select a café"
    }
    
    // MARK: - Notes List Content
    
    private var notesListContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ForEach(groupedNotes, id: \.key) { group in
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    // Month header
                    Text(group.displayString)
                        .font(DS.Typography.caption1(.semibold))
                        .foregroundColor(DS.Colors.textTertiary)
                        .textCase(.uppercase)
                    
                    // Notes in this month
                    ForEach(group.visits) { visit in
                        NoteRowInteractive(
                            visit: visit,
                            cafe: dataManager.getCafe(id: visit.cafeId),
                            onTap: {
                                selectedVisitForEdit = visit
                                showEditSheet = true
                            }
                        )
                        
                        if visit.id != group.visits.last?.id {
                            Divider()
                                .background(DS.Colors.dividerSubtle)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Interactive Note Row

private struct NoteRowInteractive: View {
    let visit: Visit
    let cafe: Cafe?
    let onTap: () -> Void
    
    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d" // e.g., "Nov 24"
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Header: date, cafe, city
                HStack {
                    Text(shortDateFormatter.string(from: visit.createdAt))
                        .font(DS.Typography.caption1(.medium))
                        .foregroundColor(DS.Colors.textSecondary)
                    
                    if let cafe = cafe {
                        Text("·")
                            .foregroundColor(DS.Colors.textTertiary)
                        
                        Text(cafe.name)
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textTertiary)
                            .lineLimit(1)
                        
                        if let city = cafe.city, !city.isEmpty {
                            Text("·")
                                .foregroundColor(DS.Colors.textTertiary)
                            
                            Text(city)
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                }
                
                // Drink / rating hint
                HStack(spacing: DS.Spacing.sm) {
                    Text(visit.drinkType.rawValue)
                        .font(DS.Typography.caption2())
                        .foregroundColor(DS.Colors.textTertiary)
                    
                    if visit.overallScore > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(DS.Colors.yellowAccent)
                            
                            Text(String(format: "%.1f", visit.overallScore))
                                .font(DS.Typography.caption2())
                                .foregroundColor(DS.Colors.textTertiary)
                        }
                    }
                }
                
                // Note preview (1-3 lines)
                if let notes = visit.notes {
                    Text(notes)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                
                // Edit hint
                HStack {
                    Spacer()
                    Text("Tap to edit")
                        .font(DS.Typography.caption2())
                        .foregroundColor(DS.Colors.textTertiary)
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(DS.Colors.textTertiary)
                }
                .padding(.top, DS.Spacing.xs)
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Note Detail Edit View

struct NoteDetailEditView: View {
    let visit: Visit
    let cafeName: String
    @ObservedObject var dataManager: DataManager
    let onDismiss: () -> Void
    
    @State private var editedNotes: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isTextEditorFocused: Bool
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    
    init(visit: Visit, cafeName: String, dataManager: DataManager, onDismiss: @escaping () -> Void) {
        self.visit = visit
        self.cafeName = cafeName
        self.dataManager = dataManager
        self.onDismiss = onDismiss
        self._editedNotes = State(initialValue: visit.notes ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // Visit info header
                    visitInfoHeader
                    
                    // Error message if any
                    if let error = errorMessage {
                        errorBanner(error)
                    }
                    
                    // Text editor
                    notesEditor
                }
                .padding(DS.Spacing.pagePadding)
            }
            .background(DS.Colors.screenBackground)
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(DS.Colors.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNotes()
                    }
                    .font(.headline)
                    .foregroundColor(DS.Colors.primaryAccent)
                    .disabled(isSaving)
                }
            }
            .interactiveDismissDisabled(editedNotes != (visit.notes ?? ""))
        }
    }
    
    // MARK: - Visit Info Header
    
    private var visitInfoHeader: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Cafe name
                Text(cafeName)
                    .font(DS.Typography.headline())
                    .foregroundColor(DS.Colors.textPrimary)
                
                // Date
                Text(dateFormatter.string(from: visit.createdAt))
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
                
                // Drink and rating
                HStack(spacing: DS.Spacing.md) {
                    // Drink type
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DS.Colors.iconSubtle)
                        
                        Text(visit.drinkType.rawValue)
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                    // Rating
                    if visit.overallScore > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(DS.Colors.yellowAccent)
                            
                            Text(String(format: "%.1f", visit.overallScore))
                                .font(DS.Typography.caption1(.medium))
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(DS.Colors.redAccent)
            
            Text(message)
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.redAccent)
            
            Spacer()
            
            Button(action: { errorMessage = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.redAccent.opacity(0.1))
        .cornerRadius(DS.Radius.md)
    }
    
    // MARK: - Notes Editor
    
    private var notesEditor: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Your notes")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            TextEditor(text: $editedNotes)
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($isTextEditorFocused)
                .frame(minHeight: 200)
                .padding(DS.Spacing.md)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(
                            isTextEditorFocused ? DS.Colors.primaryAccent : DS.Colors.borderSubtle,
                            lineWidth: isTextEditorFocused ? 2 : 1
                        )
                )
            
            // Character count hint
            Text("\(editedNotes.count) characters")
                .font(DS.Typography.caption2())
                .foregroundColor(DS.Colors.textTertiary)
        }
    }
    
    // MARK: - Save Action
    
    private func saveNotes() {
        guard !isSaving else { return }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                let notesToSave = editedNotes.isEmpty ? nil : editedNotes
                try await dataManager.updateVisitNotes(visitId: visit.id, notes: notesToSave)
                
                await MainActor.run {
                    isSaving = false
                    HapticsManager.shared.playSuccess()
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    HapticsManager.shared.playError()
                    print("[NoteDetailEditView] Save error: \(error)")
                }
            }
        }
    }
}

// MARK: - Privacy Footer

private struct JournalPrivacyFooter: View {
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(DS.Colors.iconSubtle)
            
            Text("Journal and notes are private – only visible to you.")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.lg)
    }
}

