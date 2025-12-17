//
//  ModernSocialHubView.swift
//  testMugshot
//
//  Modern Dark Mode wrapper for friends management
//

import SwiftUI

struct ModernSocialHubView: View {
    @ObservedObject var dataManager: DataManager
    
    var body: some View {
        // Use the existing FriendsHubView with modern theme
        FriendsHubView(dataManager: dataManager)
    }
}

// MARK: - Legacy Implementation (Commented for future enhancement)
/*
enum SocialHubTab: String, CaseIterable {
    case friends = "Friends"
    case requests = "Requests"
    case search = "Search"
}

struct ModernSocialHubViewFull: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileNavigator: ProfileNavigator
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    @State private var selectedTab: SocialHubTab = .friends
    @State private var searchText = ""
    @State private var searchResults: [RemoteUserProfile] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.dynamicBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab selector
                    tabSelector
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    // Search bar (for search tab)
                    if selectedTab == .search {
                        searchBar
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }
                    
                    // Content
                    ScrollView {
                        contentView
                            .padding(.top, 20)
                            .padding(.bottom, 60)
                    }
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.dynamicPrimaryAccent)
                }
            }
            .toolbarBackground(DS.Colors.dynamicCardBackgroundAlt, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(SocialHubTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hapticsManager.lightTap()
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                            
                            if tab == .requests && !friendRequests.isEmpty {
                                Text("\(friendRequests.count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(DS.Colors.dynamicPrimaryAccent)
                                    .cornerRadius(10)
                            }
                        }
                        .foregroundColor(selectedTab == tab ? DS.Colors.dynamicTextPrimary : DS.Colors.dynamicTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? DS.Colors.dynamicPrimaryAccent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(DS.Colors.dynamicCardBackgroundAlt)
        .cornerRadius(12)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DS.Colors.dynamicTextSecondary)
            
            TextField("Search by username...", text: $searchText)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
                .tint(DS.Colors.dynamicPrimaryAccent)
                .autocapitalization(.none)
                .onSubmit {
                    performSearch()
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DS.Colors.dynamicTextTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DS.Colors.dynamicCardBackgroundAlt)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DS.Colors.modernGlassBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .friends:
            friendsList
        case .requests:
            requestsList
        case .search:
            searchResultsList
        }
    }
    
    // MARK: - Friends List
    
    private var friendsList: some View {
        LazyVStack(spacing: 1) {
            ForEach(dataManager.appData.remoteFriends) { friend in
                friendRow(friend)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func friendRow(_ friend: RemoteFriend) -> some View {
        Button(action: {
            hapticsManager.lightTap()
            profileNavigator.openProfile(
                handle: .supabase(id: friend.id),
                source: .friendsList,
                triggerHaptic: false
            )
        }) {
            HStack(spacing: 12) {
                // Avatar placeholder
                Circle()
                    .fill(DS.Colors.dynamicCardBackgroundAlt)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 22))
                            .foregroundColor(DS.Colors.dynamicTextTertiary)
                    )
                
                // Name and handle
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DS.Colors.dynamicTextPrimary)
                    
                    Text("@\(friend.username)")
                        .font(.system(size: 14))
                        .foregroundColor(DS.Colors.dynamicTextSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Colors.dynamicTextTertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(DS.Colors.dynamicCardBackgroundAlt)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Requests List
    
    private var requestsList: some View {
        Group {
            if friendRequests.isEmpty {
                emptyState(
                    icon: "person.2",
                    title: "No pending requests",
                    subtitle: "Friend requests will appear here"
                )
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(friendRequests) { request in
                        requestRow(request)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func requestRow(_ request: FriendRequest) -> some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(DS.Colors.dynamicCardBackgroundAlt)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 22))
                        .foregroundColor(DS.Colors.dynamicTextTertiary)
                )
            
            // Name and handle
            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DS.Colors.dynamicTextPrimary)
                
                Text("@\(request.username)")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.dynamicTextSecondary)
            }
            
            Spacer()
            
            // Accept button
            Button(action: {
                acceptRequest(request)
            }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(DS.Colors.dynamicPrimaryAccent)
                    .cornerRadius(18)
            }
            
            // Decline button
            Button(action: {
                declineRequest(request)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Colors.dynamicTextPrimary)
                    .frame(width: 36, height: 36)
                    .background(DS.Colors.dynamicCardBackgroundAlt)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(DS.Colors.modernGlassBorder, lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(DS.Colors.dynamicCardBackgroundAlt)
        .cornerRadius(12)
    }
    
    // MARK: - Search Results
    
    private var searchResultsList: some View {
        Group {
            if searchText.isEmpty {
                emptyState(
                    icon: "magnifyingglass",
                    title: "Search for friends",
                    subtitle: "Enter a username to find people"
                )
            } else if isSearching {
                ProgressView()
                    .tint(DS.Colors.dynamicPrimaryAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if searchResults.isEmpty {
                emptyState(
                    icon: "person.slash",
                    title: "No results found",
                    subtitle: "Try a different username"
                )
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(searchResults) { profile in
                        searchResultRow(profile)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func searchResultRow(_ profile: RemoteUserProfile) -> some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(DS.Colors.dynamicCardBackgroundAlt)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 22))
                        .foregroundColor(DS.Colors.dynamicTextTertiary)
                )
            
            // Name and handle
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName ?? profile.username)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DS.Colors.dynamicTextPrimary)
                
                Text("@\(profile.username)")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.dynamicTextSecondary)
            }
            
            Spacer()
            
            // View profile button
            Button(action: {
                hapticsManager.lightTap()
                profileNavigator.openProfile(
                    handle: .supabase(id: profile.id),
                    source: .friendSearch,
                    triggerHaptic: false
                )
            }) {
                Text("View")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Colors.dynamicPrimaryAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(DS.Colors.dynamicCardBackgroundAlt)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(DS.Colors.dynamicPrimaryAccent.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(DS.Colors.dynamicCardBackgroundAlt)
        .cornerRadius(12)
    }
    
    // MARK: - Empty State
    
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 60)
            
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(DS.Colors.dynamicTextTertiary)
            
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
            
            Text(subtitle)
                .font(.system(size: 16))
                .foregroundColor(DS.Colors.dynamicTextSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Actions
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        hapticsManager.lightTap()
        
        Task {
            do {
                searchResults = try await dataManager.searchUsersByUsername(searchText)
                isSearching = false
            } catch {
                print("[ModernSocialHub] Search error: \(error)")
                searchResults = []
                isSearching = false
            }
        }
    }
    
    private func acceptRequest(_ request: FriendRequest) {
        hapticsManager.mediumTap()
        Task {
            do {
                try await dataManager.acceptFriendRequest(requestId: request.id)
            } catch {
                print("[ModernSocialHub] Accept error: \(error)")
            }
        }
    }
    
    private func declineRequest(_ request: FriendRequest) {
        hapticsManager.lightTap()
        Task {
            do {
                try await dataManager.rejectFriendRequest(requestId: request.id)
            } catch {
                print("[ModernSocialHub] Decline error: \(error)")
            }
        }
    }
}
*/


