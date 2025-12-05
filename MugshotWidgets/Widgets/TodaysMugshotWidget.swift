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
            // Has a visit today - show it
            Link(destination: WidgetDeepLink.visitDetail(visitId: visit.id) ?? WidgetDeepLink.feed!) {
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.sm) {
                    // Header
                    HStack {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 12))
                            .foregroundColor(WidgetDS.Colors.primaryAccent)
                        Text("Today's Mugshot")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Cafe name
                    Text(visit.cafeName)
                        .font(WidgetDS.Typography.headline)
                        .foregroundColor(WidgetDS.Colors.textPrimary)
                        .lineLimit(2)
                    
                    // Drink type
                    Text(visit.drinkDisplayName)
                        .font(WidgetDS.Typography.caption)
                        .foregroundColor(WidgetDS.Colors.textSecondary)
                        .lineLimit(1)
                    
                    // Rating
                    HStack(spacing: WidgetDS.Spacing.sm) {
                        WidgetStarRating(rating: visit.overallScore, size: 10)
                        Text(String(format: "%.1f", visit.overallScore))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                    }
                }
                .padding(WidgetDS.Spacing.lg)
            }
        } else {
            // No visit today - show CTA
            Link(destination: WidgetDeepLink.logVisit!) {
                VStack(spacing: WidgetDS.Spacing.md) {
                    Spacer()
                    
                    WidgetMugsyIcon(size: 32)
                    
                    Text("No mugshot yet today")
                        .font(WidgetDS.Typography.caption)
                        .foregroundColor(WidgetDS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Log a visit")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(WidgetDS.Colors.primaryAccent)
                    
                    Spacer()
                }
                .padding(WidgetDS.Spacing.lg)
            }
        }
    }
}

// MARK: - Medium Widget View

struct MediumTodaysMugshotView: View {
    let entry: TodaysMugshotEntry
    
    var body: some View {
        if let visit = entry.visit {
            // Has a visit today - show detailed view
            Link(destination: WidgetDeepLink.visitDetail(visitId: visit.id) ?? WidgetDeepLink.feed!) {
                HStack(spacing: WidgetDS.Spacing.lg) {
                    // Left side - photo placeholder or icon
                    ZStack {
                        RoundedRectangle(cornerRadius: WidgetDS.Radius.md)
                            .fill(WidgetDS.Colors.mintSoftFill)
                        
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
                            .clipShape(RoundedRectangle(cornerRadius: WidgetDS.Radius.md))
                        } else {
                            visitPhotoPlaceholder
                        }
                    }
                    .frame(width: 80, height: 80)
                    
                    // Right side - visit info
                    VStack(alignment: .leading, spacing: WidgetDS.Spacing.sm) {
                        // Header
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 10))
                                .foregroundColor(WidgetDS.Colors.primaryAccent)
                            Text("Today's Mugshot")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(WidgetDS.Colors.textSecondary)
                            Spacer()
                            Text(formattedTime(visit.createdAt))
                                .font(.system(size: 10))
                                .foregroundColor(WidgetDS.Colors.textTertiary)
                        }
                        
                        // Cafe name
                        Text(visit.cafeName)
                            .font(WidgetDS.Typography.title)
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                            .lineLimit(1)
                        
                        // Drink type
                        Text(visit.drinkDisplayName)
                            .font(WidgetDS.Typography.body)
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                            .lineLimit(1)
                        
                        // Rating and caption
                        HStack(spacing: WidgetDS.Spacing.md) {
                            HStack(spacing: WidgetDS.Spacing.sm) {
                                WidgetStarRating(rating: visit.overallScore, size: 11)
                                Text(String(format: "%.1f", visit.overallScore))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(WidgetDS.Colors.textSecondary)
                            }
                            
                            if !visit.caption.isEmpty {
                                Text(visit.caption)
                                    .font(WidgetDS.Typography.caption)
                                    .foregroundColor(WidgetDS.Colors.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(WidgetDS.Spacing.lg)
            }
        } else {
            // No visit today - show CTA with more space
            Link(destination: WidgetDeepLink.logVisit!) {
                HStack(spacing: WidgetDS.Spacing.xl) {
                    // Left side - Mugsy icon
                    ZStack {
                        Circle()
                            .fill(WidgetDS.Colors.mintSoftFill)
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 28))
                            .foregroundColor(WidgetDS.Colors.primaryAccent)
                    }
                    
                    // Right side - message and CTA
                    VStack(alignment: .leading, spacing: WidgetDS.Spacing.md) {
                        Text("No mugshot yet today")
                            .font(WidgetDS.Typography.title)
                            .foregroundColor(WidgetDS.Colors.textPrimary)
                        
                        Text("Tap to log your first sip of the day")
                            .font(WidgetDS.Typography.body)
                            .foregroundColor(WidgetDS.Colors.textSecondary)
                        
                        HStack {
                            Text("Log a visit")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(WidgetDS.Colors.textOnMint)
                                .padding(.horizontal, WidgetDS.Spacing.lg)
                                .padding(.vertical, WidgetDS.Spacing.md)
                                .background(WidgetDS.Colors.primaryAccent)
                                .cornerRadius(WidgetDS.Radius.md)
                        }
                    }
                    
                    Spacer()
                }
                .padding(WidgetDS.Spacing.lg)
            }
        }
    }
    
    private var visitPhotoPlaceholder: some View {
        Image(systemName: "cup.and.saucer.fill")
            .font(.system(size: 28))
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

