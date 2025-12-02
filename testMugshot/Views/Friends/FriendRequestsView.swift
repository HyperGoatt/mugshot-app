//
//  FriendRequestsView.swift
//  testMugshot
//
//  Created as part of Friends system implementation.
//

import SwiftUI

struct FriendRequestsView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var incomingRequests: [FriendRequest] = []
    @State private var outgoingRequests: [FriendRequest] = []
    @State private var isLoading = true
    @State private var currentUserId: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.sectionVerticalGap) {
                    // Incoming Requests Section
                    if !incomingRequests.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            DSSectionHeader("Incoming Requests")
                                .padding(.horizontal, DS.Spacing.pagePadding)
                            
                            ForEach(incomingRequests) { request in
                                if let userId = currentUserId {
                                    FriendRequestRow(
                                        request: request,
                                        isIncoming: true,
                                        currentUserId: userId,
                                        dataManager: dataManager,
                                        onRequestAction: {
                                            Task {
                                                await refreshAfterAction()
                                            }
                                        }
                                    )
                                    .padding(.horizontal, DS.Spacing.pagePadding)
                                }
                            }
                        }
                    }
                    
                    // Outgoing Requests Section
                    if !outgoingRequests.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            DSSectionHeader("Outgoing Requests")
                                .padding(.horizontal, DS.Spacing.pagePadding)
                            
                            ForEach(outgoingRequests) { request in
                                if let userId = currentUserId {
                                    FriendRequestRow(
                                        request: request,
                                        isIncoming: false,
                                        currentUserId: userId,
                                        dataManager: dataManager,
                                        onRequestAction: {
                                            Task {
                                                await refreshAfterAction()
                                            }
                                        }
                                    )
                                    .padding(.horizontal, DS.Spacing.pagePadding)
                                }
                            }
                        }
                    }
                    
                    // Empty State
                    if incomingRequests.isEmpty && outgoingRequests.isEmpty && !isLoading {
                        DSBaseCard {
                            VStack(spacing: DS.Spacing.md) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 48))
                                    .foregroundColor(DS.Colors.iconSubtle)
                                
                                Text("No Friend Requests")
                                    .font(DS.Typography.sectionTitle)
                                    .foregroundColor(DS.Colors.textPrimary)
                                
                                Text("You don't have any pending friend requests")
                                    .font(DS.Typography.bodyText)
                                    .foregroundColor(DS.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.xxl)
                        }
                        .padding(.horizontal, DS.Spacing.pagePadding)
                    }
                    
                    // Loading State
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .padding(.vertical, DS.Spacing.md)
            }
            .background(DS.Colors.screenBackground)
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.primaryAccent)
                }
            }
            .task {
                await loadFriendRequests()
            }
            .refreshable {
                await loadFriendRequests()
            }
            .onChange(of: incomingRequests.count) { _, _ in
                // Refresh when requests change
            }
            .onChange(of: outgoingRequests.count) { _, _ in
                // Refresh when requests change
            }
        }
    }
    
    private func loadFriendRequests() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let userId = dataManager.appData.supabaseUserId else {
            return
        }
        
        currentUserId = userId
        
        do {
            let requests = try await dataManager.fetchFriendRequests()
            await MainActor.run {
                incomingRequests = requests.incoming
                outgoingRequests = requests.outgoing
            }
        } catch {
            print("[FriendRequestsView] Error loading friend requests: \(error.localizedDescription)")
        }
    }
    
    private func refreshAfterAction() async {
        // Small delay to allow backend to process
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        await loadFriendRequests()
        // Also refresh friends list if a request was accepted
        await dataManager.refreshFriendsList()
    }
}

