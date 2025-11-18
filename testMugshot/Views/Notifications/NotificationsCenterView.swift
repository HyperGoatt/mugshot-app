//
//  NotificationsCenterView.swift
//  testMugshot
//
//  Notifications center screen for viewing all notifications
//

import SwiftUI

struct NotificationsCenterView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedNotification: MugshotNotification?
    
    private var unreadCount: Int {
        dataManager.appData.notifications.filter { !$0.isRead }.count
    }
    
    private var sortedNotifications: [MugshotNotification] {
        dataManager.appData.notifications.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.screenBackground
                    .ignoresSafeArea()
                
                if sortedNotifications.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.sm) {
                            ForEach(sortedNotifications) { notification in
                                NotificationRowView(
                                    notification: notification,
                                    onTap: {
                                        handleNotificationTap(notification)
                                    },
                                    onMarkRead: {
                                        markAsRead(notification)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, DS.Spacing.pagePadding)
                        .padding(.vertical, DS.Spacing.md)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $selectedNotification) { notification in
            if let visitId = notification.targetVisitId,
               let visit = dataManager.appData.visits.first(where: { $0.id == visitId }) {
                NavigationStack {
                    VisitDetailView(dataManager: dataManager, visit: visit, showsDismissButton: true)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "bell.slash")
                .font(.system(size: 64))
                .foregroundColor(DS.Colors.iconSubtle)
            
            Text("No notifications yet")
                .font(DS.Typography.screenTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            Text("When friends interact with your posts, you'll see it here")
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding * 2)
        }
    }
    
    private func handleNotificationTap(_ notification: MugshotNotification) {
        // Mark as read
        markAsRead(notification)
        
        // Navigate to related content if applicable
        if notification.targetVisitId != nil {
            selectedNotification = notification
        }
    }
    
    private func markAsRead(_ notification: MugshotNotification) {
        if let index = dataManager.appData.notifications.firstIndex(where: { $0.id == notification.id }) {
            dataManager.appData.notifications[index].isRead = true
            dataManager.save()
        }
    }
    
    private func markAllAsRead() {
        for index in dataManager.appData.notifications.indices {
            dataManager.appData.notifications[index].isRead = true
        }
        dataManager.save()
    }
}

// MARK: - Notification Row View

struct NotificationRowView: View {
    let notification: MugshotNotification
    let onTap: () -> Void
    let onMarkRead: () -> Void
    
    @State private var actorImage: UIImage?
    
    private var actorDisplayName: String {
        notification.actorDisplayName ?? notification.actorUsername ?? "Someone"
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.createdAt, relativeTo: Date())
    }
    
    var body: some View {
        Button(action: {
            onTap()
            onMarkRead()
        }) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                // Actor avatar
                ZStack {
                    if let image = actorImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Circle()
                            .fill(DS.Colors.cardBackgroundAlt)
                            .overlay(
                                Text(actorDisplayName.prefix(1).uppercased())
                                    .font(DS.Typography.headline())
                                    .foregroundColor(DS.Colors.textPrimary)
                            )
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                )
                
                // Notification content
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(alignment: .top, spacing: DS.Spacing.xs) {
                        // Icon for notification type
                        Image(systemName: notification.type.displayIcon)
                            .font(.system(size: 14))
                            .foregroundColor(DS.Colors.primaryAccent)
                        
                        Text(notification.message)
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Text(timeAgo)
                        .font(DS.Typography.caption1())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                
                Spacer()
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(DS.Colors.primaryAccent)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(notification.isRead ? DS.Colors.cardBackground : DS.Colors.cardBackgroundAlt)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            loadActorImage()
        }
    }
    
    private func loadActorImage() {
        guard let avatarKey = notification.actorAvatarKey else { return }
        if let cachedImage = PhotoCache.shared.retrieve(forKey: avatarKey) {
            actorImage = cachedImage
        }
    }
}

