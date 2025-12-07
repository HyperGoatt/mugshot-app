//
//  TodaysMugshotWidget.swift
//  MugshotWidgets
//
//  A small/medium widget showing the user's most recent visit today,
//  or nudging them to log a new one if they haven't yet.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Configuration

struct TodaysMugshotWidget: Widget {
    let kind: String = "TodaysMugshotWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaysMugshotProvider()) { entry in
            TodaysMugshotEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetDS.Colors.widgetBackground
                }
        }
        .configurationDisplayName("Today's Mugshot")
        .description("See your latest sip visit or log a new one.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Entry

struct TodaysMugshotEntry: TimelineEntry {
    let date: Date
    let visit: WidgetVisit?
    let hasVisitToday: Bool
    
    static var placeholder: TodaysMugshotEntry {
        TodaysMugshotEntry(
            date: Date(),
            visit: WidgetVisit(
                id: "placeholder",
                cafeId: "cafe-1",
                cafeName: "Sample Cafe",
                cafeCity: "Brooklyn",
                drinkType: "Coffee",
                customDrinkType: nil,
                caption: "Great morning coffee!",
                overallScore: 4.5,
                posterPhotoURL: nil,
                createdAt: Date(),
                visibility: "everyone",
                authorId: nil,
                authorDisplayName: nil,
                authorUsername: nil,
                authorAvatarURL: nil
            ),
            hasVisitToday: true
        )
    }
    
    static var empty: TodaysMugshotEntry {
        TodaysMugshotEntry(date: Date(), visit: nil, hasVisitToday: false)
    }
}

// MARK: - Timeline Provider

struct TodaysMugshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaysMugshotEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodaysMugshotEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            let entry = createEntry()
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaysMugshotEntry>) -> Void) {
        let entry = createEntry()
        
        // PERF: Refresh every 2 hours or at midnight (whichever is sooner) to reduce battery usage
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate 2 hours from now
        let twoHoursFromNow = calendar.date(byAdding: .hour, value: 2, to: now)!
        
        // Calculate midnight
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let midnight = calendar.startOfDay(for: tomorrow)
        
        // Use whichever is sooner
        let refreshDate = min(twoHoursFromNow, midnight)
        
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func createEntry() -> TodaysMugshotEntry {
        let data = WidgetDataStore.shared.load()
        let calendar = Calendar.current
        
        // Find today's visit (most recent from today)
        let todaysVisit = data.userVisits.first { visit in
            calendar.isDateInToday(visit.createdAt)
        }
        
        return TodaysMugshotEntry(
            date: Date(),
            visit: todaysVisit,
            hasVisitToday: todaysVisit != nil
        )
    }
}

// MARK: - Widget Views

struct TodaysMugshotEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: TodaysMugshotEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallTodaysMugshotView(entry: entry)
        case .systemMedium:
            MediumTodaysMugshotView(entry: entry)
        default:
            SmallTodaysMugshotView(entry: entry)
        }
    }
}

// MARK: - Small Widget View

struct SmallTodaysMugshotView: View {
    let entry: TodaysMugshotEntry
    
    var body: some View {
        if let visit = entry.visit {
            // Has a visit today - show it with bold design
            Link(destination: WidgetDeepLink.visitDetail(visitId: visit.id) ?? WidgetDeepLink.feed!) {
                VStack(alignment: .leading, spacing: 0) {
                    // Subtle mint accent bar at top
                    Rectangle()
                        .fill(WidgetDS.Colors.primaryAccent)
                        .frame(height: 3)
                    
                    VStack(alignment: .leading, spacing: WidgetDS.Spacing.contentSpacing) {
                        Spacer()
                        
                        // Cafe name - LARGE and BOLD
                        Text(visit.cafeName)
                            .font(WidgetDS.Typography.contentTitle)
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7) // Allow more scaling
                        
                        // Drink type with better spacing
                        Text(visit.drinkDisplayName)
                            .font(WidgetDS.Typography.contentBody)
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        
                        // Prominent rating with larger stars
                        EnhancedRatingDisplay(rating: visit.overallScore, showStars: true, size: 13)
                        
                        Spacer()
                    }
                    .padding(WidgetDS.Spacing.widgetPadding)
                }
            }
        } else {
            // No visit today - bold motivational CTA
            Link(destination: WidgetDeepLink.logVisit!) {
                ZStack {
                    // Mint gradient background for visual interest
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(WidgetDS.Gradients.mintSubtle)
                            .frame(height: 80)
                    }
                    
                    VStack(spacing: WidgetDS.Spacing.contentSpacing) {
                        Spacer()
                        
                        // Large coffee cup icon
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 40, weight: .semibold)) // Reduced from 48
                            .foregroundColor(WidgetDS.Colors.primaryAccent)
                        
                        // Bold CTA text
                        Text("Log Today's Sip")
                            .font(.system(size: 15, weight: .bold)) // Reduced from 16
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8) // Allow scaling
                        
                        Spacer()
                    }
                    .padding(WidgetDS.Spacing.widgetPadding)
                }
            }
        }
    }
}

// MARK: - Medium Widget View

struct MediumTodaysMugshotView: View {
    let entry: TodaysMugshotEntry
    
    var body: some View {
        if let visit = entry.visit {
            // Has a visit today - larger, more visual layout
            Link(destination: WidgetDeepLink.visitDetail(visitId: visit.id) ?? WidgetDeepLink.feed!) {
                HStack(spacing: WidgetDS.Spacing.contentSpacing) {
                    // Left side - LARGER photo (100x100)
                    ZStack {
                        RoundedRectangle(cornerRadius: WidgetDS.Radius.lg)
                            .fill(WidgetDS.Gradients.mintSubtle)
                        
                        if let photoURL = visit.posterPhotoURL, let url = URL(string: photoURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure, .empty:
                                    visitPhotoPlaceholder
                                @unknown default:
                                    visitPhotoPlaceholder
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: WidgetDS.Radius.lg))
                        } else {
                            visitPhotoPlaceholder
                        }
                    }
                    .frame(width: 100, height: 100)
                    
                    // Right side - visit info with bold typography
                    VStack(alignment: .leading, spacing: WidgetDS.Spacing.md) {
                        // Time in subtle text
                        Text(formattedTime(visit.createdAt))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(WidgetDS.Colors.textTertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        // Cafe name - LARGE 22pt bold
                        Text(visit.cafeName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        
                        // City with location icon
                        if let city = visit.cafeCity {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(WidgetDS.Colors.textTertiary)
                                Text(city)
                                    .font(WidgetDS.Typography.contentBody)
                                    .foregroundColor(WidgetDS.Colors.textSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Rating as prominent pill badge
                        EnhancedBadge(
                            text: String(format: "%.1f", visit.overallScore),
                            icon: "star.fill",
                            backgroundColor: WidgetDS.Colors.yellowAccent.opacity(0.15),
                            foregroundColor: WidgetDS.Colors.textPrimary
                        )
                    }
                    
                    Spacer()
                }
                .padding(WidgetDS.Spacing.widgetPadding)
            }
        } else {
            // No visit today - horizontally split bold design
            Link(destination: WidgetDeepLink.logVisit!) {
                HStack(spacing: 0) {
                    // Left side - large cup with mint gradient
                    ZStack {
                        Rectangle()
                            .fill(WidgetDS.Gradients.mintBold)
                        
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(WidgetDS.Colors.neutralCard)
                            .opacity(0.9)
                    }
                    .frame(width: 120)
                    
                    // Right side - bold CTA messaging
                    VStack(alignment: .leading, spacing: WidgetDS.Spacing.contentSpacing) {
                        Spacer()
                        
                        Text("Start Your Day")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.8)
                        
                        Text("Log Your\nFirst Sip")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                            .lineLimit(2)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Log Visit")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(WidgetDS.Colors.primaryAccent)
                        
                        Spacer()
                    }
                    .padding(.horizontal, WidgetDS.Spacing.widgetPadding)
                    
                    Spacer()
                }
            }
        }
    }
    
    private var visitPhotoPlaceholder: some View {
        Image(systemName: "cup.and.saucer.fill")
            .font(.system(size: 36))
            .foregroundColor(WidgetDS.Colors.primaryAccent)
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    TodaysMugshotWidget()
} timeline: {
    TodaysMugshotEntry.placeholder
    TodaysMugshotEntry.empty
}

#Preview(as: .systemMedium) {
    TodaysMugshotWidget()
} timeline: {
    TodaysMugshotEntry.placeholder
    TodaysMugshotEntry.empty
}

