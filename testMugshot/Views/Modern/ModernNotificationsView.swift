//
//  ModernNotificationsView.swift
//  testMugshot
//
//  Modern Dark Mode wrapper for notifications center
//

import SwiftUI

struct ModernNotificationsView: View {
    @ObservedObject var dataManager: DataManager
    
    var body: some View {
        // Use the existing NotificationsCenterView with modern theme
        NotificationsCenterView(dataManager: dataManager)
    }
}

// MARK: - Legacy Implementation (Commented for future enhancement)
/*
struct ModernNotificationsViewFull: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    @EnvironmentObject private var hapticsManager: HapticsManager
    @EnvironmentObject private var tabCoordinator: TabCoordinator
    
    @State private var selectedVisit: Visit?
    
    private var notifications: [MugshotNotification] {
        dataManager.appData.notifications.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.dynamicBackground
                    .ignoresSafeArea()
                
                if notifications.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(notifications) { notification in
                                notificationRow(notification)
                            }
                        }
                        .padding(.bottom, 60)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DS.Colors.dynamicTextPrimary)
                    }
                }
                
                if !notifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: markAllAsRead) {
                            Text("Mark All Read")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DS.Colors.dynamicPrimaryAccent)
                        }
                    }
                }
            }
            .toolbarBackground(DS.Colors.dynamicCardBackgroundAlt, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
        }
    }
    
    // MARK: - Notification Row
    
    private func notificationRow(_ notification: MugshotNotification) -> some View {
        Button(action: {
            handleNotificationTap(notification)
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Unread indicator
                Circle()
                    .fill(notification.isRead ? Color.clear : DS.Colors.dynamicPrimaryAccent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                
                // Icon
                notificationIcon(for: notification.type)
                    .font(.system(size: 20))
                    .foregroundColor(DS.Colors.dynamicPrimaryAccent)
                    .frame(width: 40, height: 40)
                    .background(DS.Colors.dynamicCardBackgroundAlt)
                    .cornerRadius(10)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.message)
                        .font(.system(size: 15, weight: notification.isRead ? .regular : .semibold))
                        .foregroundColor(DS.Colors.dynamicTextPrimary)
                        .lineLimit(3)
                    
                    Text(formatTimeAgo(notification.createdAt))
                        .font(.system(size: 13))
                        .foregroundColor(DS.Colors.dynamicTextTertiary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(notification.isRead ? Color.clear : DS.Colors.dynamicCardBackgroundAlt.opacity(0.3))
        }
        .buttonStyle(.plain)
        .overlay(
            Rectangle()
                .fill(DS.Colors.dynamicDivider)
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell")
                .font(.system(size: 60))
                .foregroundColor(DS.Colors.dynamicTextTertiary)
            
            Text("No notifications yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
            
            Text("You'll see updates about your coffee journey here")
                .font(.system(size: 16))
                .foregroundColor(DS.Colors.dynamicTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Helpers
    
    private func notificationIcon(for type: NotificationType) -> some View {
        Image(systemName: type.displayIcon)
    }
    
    private func handleNotificationTap(_ notification: MugshotNotification) {
        hapticsManager.lightTap()
        
        // Mark as read
        dataManager.markNotificationAsRead(notification.id)
        
        // Navigate based on type
        switch notification.type {
        case .friendRequest, .friendAccept, .follow:
            if let userId = notification.actorUserId {
                profileNavigator.openProfile(
                    handle: .supabase(id: userId),
                    source: .notifications,
                    triggerHaptic: false
                )
            }
            
        case .comment, .reply, .mention, .like:
            if let visitId = notification.visitId,
               let visit = dataManager.getVisit(id: visitId) {
                selectedVisit = visit
            }
            
        case .newVisitFromFriend:
            if let visitId = notification.visitId,
               let visit = dataManager.getVisit(id: visitId) {
                selectedVisit = visit
            }
            
        case .friendJoin, .system:
            // No navigation for these types
            break
        }
        
        dismiss()
    }
    
    private func markAllAsRead() {
        hapticsManager.mediumTap()
        for notification in notifications where !notification.isRead {
            dataManager.markNotificationAsRead(notification.id)
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day, .weekOfYear], from: date, to: now)
        
        if let weeks = components.weekOfYear, weeks > 0 {
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        } else if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
    }
}
*/


