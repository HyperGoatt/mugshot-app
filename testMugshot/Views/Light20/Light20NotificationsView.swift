//
//  Light20NotificationsView.swift
//  testMugshot
//
//  Light 2.0 notifications with clean cards
//  Read/unread states with mint accents
//

import SwiftUI

struct Light20NotificationsView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    private var notifications: [MugshotNotification] {
        dataManager.appData.notifications.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DS.Colors.light20Background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        if notifications.isEmpty {
                            emptyState
                        } else {
                            ForEach(notifications) { notification in
                                NotificationCard(
                                    notification: notification,
                                    onTap: {
                                        hapticsManager.lightTap()
                                        markAsRead(notification)
                                        handleNotificationTap(notification)
                                    }
                                )
                                .padding(.horizontal, DS.Spacing.pagePadding)
                            }
                        }
                    }
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(DS.Colors.light20CharcoalBlack)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: markAllAsRead) {
                        Text("Mark all read")
                            .light20Label()
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(DS.Colors.light20TextTertiary)
            
            Text("No notifications")
                .light20Subheading()
            
            Text("You're all caught up!")
                .light20Label()
        }
        .padding(.top, 80)
    }
    
    private func markAsRead(_ notification: MugshotNotification) {
        Task {
            await dataManager.markNotificationRead(notification)
        }
    }
    
    private func markAllAsRead() {
        Task {
            for notification in notifications where !notification.isRead {
                await dataManager.markNotificationRead(notification)
            }
        }
    }
    
    private func handleNotificationTap(_ notification: MugshotNotification) {
        // TODO: Navigate based on notification type
        dismiss()
    }
}

private struct NotificationCard: View {
    let notification: MugshotNotification
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                iconForNotification
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.message)
                        .light20Subheading()
                        .lineLimit(2)
                    
                    Text(notification.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .light20Label()
                        .lineLimit(2)
                    
                    Text(timeAgoString(from: notification.createdAt))
                        .light20Caption()
                }
                
                if !notification.isRead {
                    Circle()
                        .fill(DS.Colors.light20MintPrimary)
                        .frame(width: 8, height: 8)
                }
            }
            .padding()
        }
        .light20FloatingCard()
        .opacity(notification.isRead ? 0.7 : 1.0)
    }
    
    private var iconForNotification: some View {
        Circle()
            .fill(DS.Colors.light20MintSoftFill)
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: iconName)
                    .foregroundColor(DS.Colors.light20MintPrimary)
            )
    }
    
    private var iconName: String {
        return notification.type.displayIcon
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}


