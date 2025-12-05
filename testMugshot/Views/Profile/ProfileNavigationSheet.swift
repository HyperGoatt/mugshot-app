//
//  ProfileNavigationSheet.swift
//  testMugshot
//
//  Shared container for presenting OtherUserProfileView with Mugshot-polished
//  loading + error states when routed via ProfileNavigator.
//

import SwiftUI

struct ProfileNavigationSheet: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var navigator: ProfileNavigator
    let presentation: ProfileNavigator.Presentation
    
    var body: some View {
        ZStack {
            DS.Colors.screenBackground
                .ignoresSafeArea()
            
            switch presentation.state {
            case .loading:
                ProfileLoadingSkeletonView()
                    .transition(.opacity)
            case .resolved(let userId, let profile):
                OtherUserProfileView(
                    dataManager: dataManager,
                    userId: userId,
                    initialProfile: profile
                )
            case .error(let message):
                errorState(message: message)
            }
        }
    }
    
    @ViewBuilder
    private func errorState(message: String) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(DS.Colors.iconSubtle)
            
            Text("Unable to load profile")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            Text(message)
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            if let username = presentation.handle.username {
                Button(action: {
                    navigator.openProfile(
                        handle: presentation.handle,
                        source: presentation.source,
                        triggerHaptic: false
                    )
                }) {
                    Text("Try Again")
                        .font(DS.Typography.buttonLabel)
                        .foregroundColor(DS.Colors.textOnMint)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.primaryAccent)
                        .cornerRadius(DS.Radius.primaryButton)
                }
                .accessibilityLabel("Retry loading \(username)'s profile")
            }
        }
        .padding(DS.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(DS.Colors.cardBackground)
                .shadow(color: DS.Shadow.cardSoft.color.opacity(0.25),
                        radius: DS.Shadow.cardSoft.radius,
                        x: DS.Shadow.cardSoft.x,
                        y: DS.Shadow.cardSoft.y)
        )
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
}


