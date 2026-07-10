//
//  FeedTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI
import UIKit

// Helper view to display the poster image for a visit
struct PosterImageView: View {
    let visit: Visit
    
    var body: some View {
        if let posterPath = visit.posterImagePath {
            PhotoImageView(photoPath: posterPath)
        } else {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .fill(Color.sandBeige.opacity(0.72))
                .overlay(
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(.roastBrown.opacity(0.42))
                )
        }
    }
}

struct FeedTabView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var selectedScope: FeedScope = .friends
    @State private var selectedVisit: Visit?
    @State private var showVisitDetail = false
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    @State private var remoteVisits: [RemoteVisitSummary] = []
    @State private var isLoadingRemoteVisits = false
    @State private var remoteVisitError: String?
    @State private var selectedRemoteVisit: RemoteVisitSummary?
    @State private var pendingSocialVisitIDs: Set<UUID> = []
    @State private var socialRecoveryMessage: String?

    private var feedTaskID: String {
        "\(authModel.authenticatedUser?.id.uuidString ?? "signed-out")-\(selectedScope.displayName)"
    }

    private var feedSubtitle: String {
        switch selectedScope {
        case .friends:
            return "Sips from friends"
        case .everyone:
            return "Fresh public sips"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MugshotScreenHeader("Feed", subtitle: feedSubtitle) {
                    HStack(spacing: 8) {
                        MugshotStatPill(
                            icon: "flame.fill",
                            value: "\(remoteVisits.count)",
                            label: "sips",
                            accent: true
                        )
                        MugshotIconButton(systemName: "magnifyingglass", size: 36) {}
                    }
                }

                MugshotSegmentedControl(
                    options: FeedScope.allCases,
                    selection: $selectedScope,
                    title: { $0.displayName },
                    icon: { scopeIcon(for: $0) }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        feedContent
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 116)
                }
                .background(Color.creamWhite)
            }
            .background(Color.creamWhite)
        }
        .fullScreenCover(isPresented: $showVisitDetail) {
            if let visit = selectedVisit {
                VisitDetailView(visit: visit, dataManager: dataManager)
            }
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                CafeDetailView(cafe: cafe, dataManager: dataManager)
            }
        }
        .fullScreenCover(item: $selectedRemoteVisit, onDismiss: {
            Task {
                await loadRemoteFeedIfNeeded()
            }
        }) { visit in
            RemoteVisitDetailView(
                visitId: visit.id,
                initialSummary: visit,
                currentUserId: authModel.authenticatedUser?.id,
                dataManager: dataManager
            )
        }
        .task(id: feedTaskID) {
            await loadRemoteFeedIfNeeded()
        }
    }
    
    private var visits: [Visit] {
        guard let currentUserId = dataManager.appData.currentUser?.id else {
            return []
        }
        return dataManager.getFeedVisits(scope: selectedScope, currentUserId: currentUserId)
    }

    @ViewBuilder
    private var feedContent: some View {
        if authModel.authenticatedUser != nil {
            remoteFeedContent
        } else {
            localFeedContent
        }
    }

    @ViewBuilder
    private var remoteFeedContent: some View {
        if isLoadingRemoteVisits {
            MugshotLoadingCards(count: 4, cardHeight: 228)
        } else if let remoteVisitError {
            MugshotRecoveryCard(
                title: "Couldn’t load your feed",
                message: remoteVisitError,
                actionTitle: "Retry"
            ) {
                Task { await loadRemoteFeedIfNeeded() }
            }
        } else if remoteVisits.isEmpty {
            MugsyEmptyStateView(
                asset: selectedScope == .friends ? .noFriends : .comingSoon,
                title: selectedScope == .friends ? "No friend-visible visits yet" : "No public visits yet",
                message: selectedScope == .friends ? "Sips from friends will appear here as your circle grows." : "Public sips will appear here as people log them."
            )
        } else {
            ForEach(remoteVisits) { visit in
                RemoteFeedVisitCard(
                    visit: visit,
                    isCafeSaved: isCafeSaved(for: visit),
                    isSocialActionInFlight: pendingSocialVisitIDs.contains(visit.id),
                    onOpen: {
                        selectedRemoteVisit = visit
                    },
                    onLike: {
                        toggleRemoteLike(for: visit)
                    },
                    onSaveCafe: {
                        saveCafe(from: visit)
                    },
                    onComment: {
                        selectedRemoteVisit = visit
                    }
                )
                .accessibilityLabel("\(visit.visit.drinkDisplayName) at \(visit.locationTitle)")
                .accessibilityHint("Opens visit details")
            }

            if let socialRecoveryMessage {
                Text(socialRecoveryMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.espressoBrown)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.sandBeige.opacity(0.58))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var localFeedContent: some View {
        ForEach(visits) { visit in
            VisitCard(
                visit: visit,
                dataManager: dataManager,
                selectedScope: selectedScope,
                onCafeTap: {
                    if let cafe = dataManager.getCafe(id: visit.cafeId) {
                        selectedCafe = cafe
                        showCafeDetail = true
                    }
                }
            )
            .onTapGesture {
                selectedVisit = visit
                showVisitDetail = true
            }
        }
    }

    private func loadRemoteFeedIfNeeded() async {
        guard authModel.authenticatedUser != nil else {
            remoteVisits = []
            remoteVisitError = nil
            isLoadingRemoteVisits = false
            return
        }

        let scope = selectedScope
        isLoadingRemoteVisits = true
        remoteVisitError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            let visits = try await service.fetchFeedVisits(
                scope: scope,
                currentUserId: authModel.authenticatedUser?.id
            )
            guard scope == selectedScope else { return }
            remoteVisits = visits
            isLoadingRemoteVisits = false
        } catch {
            guard scope == selectedScope else { return }
            guard !Task.isCancelled else { return }
            remoteVisits = []
            remoteVisitError = MugshotUserFacingError.message(for: error, context: .loading)
            isLoadingRemoteVisits = false
        }
    }

    private func scopeIcon(for scope: FeedScope) -> String {
        switch scope {
        case .friends:
            return "person.2.fill"
        case .everyone:
            return "globe"
        }
    }

    private func isCafeSaved(for visit: RemoteVisitSummary) -> Bool {
        guard let remoteCafeId = visit.cafe?.id else {
            return false
        }

        return dataManager.appData.cafes.contains { cafe in
            (cafe.remoteCafeId == remoteCafeId || cafe.id == remoteCafeId) && (cafe.isFavorite || cafe.wantToTry)
        }
    }

    private func toggleRemoteLike(for visit: RemoteVisitSummary) {
        guard let userId = authModel.authenticatedUser?.id else {
            return
        }

        guard pendingSocialVisitIDs.insert(visit.id).inserted else { return }
        socialRecoveryMessage = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        updateRemoteVisit(
            id: visit.id,
            socialState: RemoteVisitSocialState(
                likeCount: max(0, visit.socialState.likeCount + (visit.socialState.currentUserHasLiked ? -1 : 1)),
                commentCount: visit.socialState.commentCount,
                currentUserHasLiked: !visit.socialState.currentUserHasLiked
            )
        )

        Task {
            do {
                let client = try SupabaseClientProvider.shared.client()
                let service = VisitService(client: client)
                let state = try await service.toggleLike(
                    visitId: visit.id,
                    userId: userId,
                    currentlyLiked: visit.socialState.currentUserHasLiked
                )
                updateRemoteVisit(id: visit.id, socialState: state)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                updateRemoteVisit(id: visit.id, socialState: visit.socialState)
                socialRecoveryMessage = MugshotUserFacingError.message(for: error, context: .social)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            pendingSocialVisitIDs.remove(visit.id)
        }
    }

    private func saveCafe(from visit: RemoteVisitSummary) {
        guard let remoteCafe = visit.cafe else {
            return
        }

        let existingState = existingCafeState(for: remoteCafe.id)
        let localCafe = dataManager.upsertRemoteCafe(
            remoteCafe,
            isFavorite: true,
            wantToTry: existingState.wantToTry
        )

        guard let userId = authModel.authenticatedUser?.id else {
            return
        }

        guard pendingSocialVisitIDs.insert(visit.id).inserted else { return }
        socialRecoveryMessage = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            do {
                let client = try SupabaseClientProvider.shared.client()
                let service = CafeStateService(client: client)
                let state = existingCafeState(for: remoteCafe.id)
                let summary = try await service.setCafeState(
                    userId: userId,
                    cafe: localCafe,
                    isFavorite: true,
                    wantToTry: state.wantToTry
                )
                dataManager.applyRemoteCafeState(summary)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                dataManager.setCafeState(
                    cafeId: localCafe.id,
                    isFavorite: existingState.isFavorite,
                    wantToTry: existingState.wantToTry
                )
                socialRecoveryMessage = MugshotUserFacingError.message(for: error, context: .social)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            pendingSocialVisitIDs.remove(visit.id)
        }
    }

    private func existingCafeState(for remoteCafeId: UUID) -> (isFavorite: Bool, wantToTry: Bool) {
        guard let cafe = dataManager.appData.cafes.first(where: {
            $0.remoteCafeId == remoteCafeId || $0.id == remoteCafeId
        }) else {
            return (false, false)
        }

        return (cafe.isFavorite, cafe.wantToTry)
    }

    private func updateRemoteVisit(id: UUID, socialState: RemoteVisitSocialState) {
        guard let index = remoteVisits.firstIndex(where: { $0.id == id }) else {
            return
        }

        let visit = remoteVisits[index]
        remoteVisits[index] = RemoteVisitSummary(
            visit: visit.visit,
            cafe: visit.cafe,
            author: visit.author,
            socialState: socialState
        )
    }
}

struct RemoteFeedVisitCard: View {
    let visit: RemoteVisitSummary
    let isCafeSaved: Bool
    let isSocialActionInFlight: Bool
    let onOpen: () -> Void
    let onLike: () -> Void
    let onSaveCafe: () -> Void
    let onComment: () -> Void

    private var hasPhoto: Bool {
        visit.visit.posterPhotoURL != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            authorHeader

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 0) {
                    poster
                    contentBlock
                }
            }
            .buttonStyle(.plain)
            .disabled(isSocialActionInFlight)

            footer
        }
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.foamWhite.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
    }

    private var authorHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            MugshotAvatar(name: visit.authorDisplayName, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(visit.authorDisplayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.espressoBrown)
                    .lineLimit(1)

                Text("@\(visit.authorUsername) · \(timeAgoString(from: visit.visit.createdAtDate))")
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if !hasPhoto, visit.visit.overallScore > 0 {
                scoreBadge
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var poster: some View {
        ZStack(alignment: .bottom) {
            Group {
                if hasPhoto {
                    RemotePhotoImageView(
                        urlString: visit.visit.posterPhotoURL,
                        placeholderSystemName: "photo.on.rectangle"
                    )
                } else {
                    RemoteFeedNoPhotoPoster()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: hasPhoto ? 270 : 178)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            locationOverlay

            if hasPhoto, visit.visit.overallScore > 0 {
                VStack {
                    HStack {
                        Spacer()
                        MugshotRatingBadge(score: visit.visit.overallScore, onPhoto: true)
                            .padding(12)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private var locationOverlay: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Label(visit.locationTitle, systemImage: visit.cafe == nil ? "house.fill" : "mappin.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.creamWhite)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = visit.locationSubtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.creamWhite.opacity(0.75))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.creamWhite.opacity(0.78))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .mugshotGlassSurface(
            radius: 19,
            tint: .espressoBrown,
            stroke: Color.creamWhite.opacity(0.20),
            shadow: DesignSystem.Shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4),
            interactive: true
        )
        .padding(12)
    }

    private var contentBlock: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(visit.visit.drinkDisplayName)
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(.espressoBrown)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let caption = consumerPreviewCaption(visit.visit.caption) {
                Text(caption)
                    .font(.system(size: 15))
                    .foregroundColor(.espressoBrown.opacity(0.74))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("\(visit.visit.contextDisplayName) · \(timeAgoString(from: visit.visit.createdAtDate))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.roastBrown.opacity(0.58))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button(action: onLike) {
                socialActionLabel(
                    value: visit.socialState.likeCount,
                    systemImage: visit.socialState.currentUserHasLiked ? "heart.fill" : "heart",
                    isActive: visit.socialState.currentUserHasLiked
                )
            }
            .buttonStyle(.plain)
            .disabled(isSocialActionInFlight)

            Button(action: onComment) {
                socialActionLabel(
                    value: visit.socialState.commentCount,
                    systemImage: "bubble.right",
                    isActive: false
                )
            }
            .buttonStyle(.plain)
            .disabled(isSocialActionInFlight)

            Button(action: onSaveCafe) {
                socialActionLabel(
                    value: nil,
                    systemImage: isCafeSaved ? "bookmark.fill" : "bookmark",
                    isActive: isCafeSaved
                )
            }
            .buttonStyle(.plain)
            .disabled(isSocialActionInFlight)

            Spacer(minLength: 0)

            Button(action: onOpen) {
                HStack(spacing: 6) {
                    Text("Open")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.espressoBrown)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.sandBeige.opacity(0.44))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.mugshotLine)
                .frame(height: 1)
                .padding(.horizontal, 16)
        }
    }

    private var scoreBadge: some View {
        MugshotRatingBadge(score: visit.visit.overallScore)
    }

    private func socialActionLabel(value: Int?, systemImage: String, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))

            if let value {
                Text("\(value)")
                    .font(.system(size: 13, weight: .bold))
            }
        }
        .foregroundColor(isActive ? .espressoBrown : .roastBrown.opacity(0.78))
        .padding(.horizontal, value == nil ? 9 : 10)
        .frame(minHeight: 44)
        .background(isActive ? Color.mugshotMint.opacity(0.34) : Color.sandBeige.opacity(0.34))
        .clipShape(Capsule())
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct RemoteFeedNoPhotoPoster: View {
    var body: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 20)

            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(.roastBrown.opacity(0.42))

            Text("Taste memory")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondaryText)

            Spacer(minLength: 92)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sandBeige.opacity(0.72))
    }
}

private func consumerPreviewCaption(_ caption: String) -> String? {
    let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let lowercased = trimmed.lowercased()
    let internalMarkers = [
        "smoke",
        "photo-required",
        "ui pass",
        "polish pass"
    ]

    guard !internalMarkers.contains(where: lowercased.contains) else {
        return nil
    }

    return trimmed
}

struct VisitCard: View {
    let visit: Visit
    @ObservedObject var dataManager: DataManager
    let selectedScope: FeedScope
    var onCafeTap: (() -> Void)? = nil
    
    var cafe: Cafe? {
        dataManager.getCafe(id: visit.cafeId)
    }
    
    var user: User? {
        // For now, use current user. Later, fetch by visit.userId
        dataManager.appData.currentUser?.id == visit.userId ? dataManager.appData.currentUser : nil
    }
    
    var isCurrentUser: Bool {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return false }
        return visit.userId == currentUserId
    }
    
    var isLiked: Bool {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return false }
        return visit.isLikedBy(userId: currentUserId)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            localAuthorHeader
            localPoster
            localContent
            localFooter
        }
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.foamWhite.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
    }

    private var localAuthorHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            MugshotAvatar(name: user?.username ?? "User", size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(user?.displayNameOrUsername ?? user?.username ?? "Mugshot User")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .lineLimit(1)

                    if isCurrentUser {
                        Text("You")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.espressoBrown)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.mugshotMint.opacity(0.5))
                            .clipShape(Capsule())
                    }
                }

                Text(formatDate(visit.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.6))
            }

            Spacer(minLength: 8)

            if visit.photos.isEmpty, visit.overallScore > 0 {
                MugshotRatingBadge(score: visit.overallScore)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var localPoster: some View {
        ZStack(alignment: .bottom) {
            Group {
                if !visit.photos.isEmpty {
                    PosterImageView(visit: visit)
                } else {
                    RemoteFeedNoPhotoPoster()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: visit.photos.isEmpty ? 178 : 260)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Label(cafe?.consumerDisplayName ?? "Cafe", systemImage: "mappin.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.creamWhite)
                        .lineLimit(2)

                    if let address = cafe?.address, !address.isEmpty {
                        Text(address)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.creamWhite.opacity(0.75))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.creamWhite.opacity(0.78))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .mugshotGlassSurface(
                radius: 19,
                tint: .espressoBrown,
                stroke: Color.creamWhite.opacity(0.20),
                shadow: DesignSystem.Shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4),
                interactive: true
            )
            .padding(12)

            if !visit.photos.isEmpty, visit.overallScore > 0 {
                VStack {
                    HStack {
                        Spacer()
                        MugshotRatingBadge(score: visit.overallScore, onPhoto: true)
                            .padding(12)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private var localContent: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(localDrinkDisplayName)
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(.espressoBrown)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let caption = consumerPreviewCaption(visit.caption) {
                MentionText(text: caption, mentions: visit.mentions)
                    .font(.system(size: 15))
                    .foregroundColor(.espressoBrown.opacity(0.74))
                    .lineLimit(3)
            }

            Text("\(visit.drinkType.rawValue) · \(formatDate(visit.createdAt))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.roastBrown.opacity(0.58))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private var localFooter: some View {
        HStack(spacing: 14) {
            Button(action: {
                if let userId = dataManager.appData.currentUser?.id {
                    dataManager.toggleVisitLike(visit.id, userId: userId)
                }
            }) {
                localSocialLabel(value: visit.likeCount, systemImage: isLiked ? "heart.fill" : "heart", isActive: isLiked)
            }
            .buttonStyle(.plain)

            localSocialLabel(value: visit.commentCount, systemImage: "bubble.right", isActive: false)

            Spacer(minLength: 0)

            Text("Open")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.espressoBrown)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.sandBeige.opacity(0.44))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.mugshotLine)
                .frame(height: 1)
                .padding(.horizontal, 16)
        }
    }

    private var localDrinkDisplayName: String {
        visit.customDrinkType ?? visit.drinkType.rawValue
    }

    private func localSocialLabel(value: Int, systemImage: String, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
            Text("\(value)")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(isActive ? .espressoBrown : .roastBrown.opacity(0.78))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isActive ? Color.mugshotMint.opacity(0.34) : Color.sandBeige.opacity(0.34))
        .clipShape(Capsule())
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct VisitDetailView: View {
    @ObservedObject var dataManager: DataManager
    @State private var visit: Visit
    @Environment(\.dismiss) var dismiss
    @State private var commentText = ""
    @State private var selectedPhotoIndex = 0
    @FocusState private var isCommentFocused: Bool
    @State private var showEdit = false
    @State private var showDeleteAlert = false
    
    init(visit: Visit, dataManager: DataManager) {
        self._visit = State(initialValue: visit)
        self.dataManager = dataManager
    }
    
    var cafe: Cafe? {
        dataManager.getCafe(id: visit.cafeId)
    }
    
    var user: User? {
        dataManager.appData.currentUser?.id == visit.userId ? dataManager.appData.currentUser : nil
    }
    
    var isLiked: Bool {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return false }
        return visit.isLikedBy(userId: currentUserId)
    }
    
    var comments: [Comment] {
        dataManager.getComments(for: visit.id)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                SipDetailBackground()

                ScrollView {
                    VStack(spacing: 0) {
                        localHeroSection

                        VStack(alignment: .leading, spacing: 18) {
                            localMemoryPanel
                            localActionShelf
                            SipRatingBreakdownPanel(
                                score: visit.overallScore,
                                ratings: visit.ratings,
                                title: "Flavor map",
                                subtitle: isOwnVisit ? "Your saved taste breakdown" : "\(user?.displayNameOrUsername ?? "Mugshot User")'s taste breakdown"
                            )
                            localPrivateNote
                            localCommentsSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                        .padding(.bottom, 34)
                    }
                }

                localTopControls
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                refreshVisit()
            }
            .sheet(isPresented: $showEdit) {
                EditVisitView(visit: visit, dataManager: dataManager) { updated in
                    visit = updated
                }
            }
            .alert("Delete this sip?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    dataManager.deleteVisit(id: visit.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes it from your map, feed, and saved lists.")
            }
        }
    }

    private var isOwnVisit: Bool {
        dataManager.appData.currentUser?.id == visit.userId
    }

    private var localDrinkDisplayName: String {
        if let custom = visit.customDrinkType?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }

        return visit.drinkType.rawValue
    }

    private var localAuthorName: String {
        isOwnVisit ? "Your sip" : (user?.displayNameOrUsername ?? "Mugshot User")
    }

    private var localUsername: String {
        "@\(user?.username ?? "user")"
    }

    private var localTopControls: some View {
        HStack(spacing: 12) {
            SipTopBarButton(systemImage: "xmark") {
                dismiss()
            }
            .accessibilityLabel("Close sip")

            Spacer()

            if isOwnVisit {
                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("Edit Sip", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Sip", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.foamWhite.opacity(0.72), lineWidth: 1))
                        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                }
                .accessibilityLabel("Sip actions")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var localHeroSection: some View {
        ZStack(alignment: .bottomLeading) {
            localPhotoPager

            LinearGradient(
                colors: [
                    .black.opacity(0.02),
                    .black.opacity(0.18),
                    .black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            SipMemoryHeroOverlay(
                authorTitle: localAuthorName,
                avatarName: user?.displayNameOrUsername ?? "User",
                username: localUsername,
                timestamp: SipDetailFormat.relative(visit.createdAt),
                drinkName: localDrinkDisplayName,
                locationTitle: cafe?.consumerDisplayName ?? "Cafe",
                locationSubtitle: cafe?.address.isEmpty == false ? cafe?.address : nil,
                score: visit.overallScore,
                visibilityLabel: localAudienceLabel,
                isOwnSip: isOwnVisit
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 500)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(localDrinkDisplayName) at \(cafe?.consumerDisplayName ?? "Cafe"), rated \(visit.overallScore > 0 ? String(format: "%.1f", visit.overallScore) : "Unrated")")
    }

    @ViewBuilder
    private var localPhotoPager: some View {
        let orderedPhotos = getOrderedPhotos(for: visit)

        if orderedPhotos.isEmpty {
            SipEmptyPhotoBackdrop(
                title: "No photo saved",
                message: "This sip still has its taste memory, notes, and social thread."
            )
        } else {
            TabView(selection: $selectedPhotoIndex) {
                ForEach(Array(orderedPhotos.enumerated()), id: \.offset) { index, photoPath in
                    PhotoImageView(photoPath: photoPath)
                        .tag(index)
                        .overlay(alignment: .topTrailing) {
                            if orderedPhotos.count > 1 {
                                SipPhotoCountBadge(
                                    current: selectedPhotoIndex + 1,
                                    total: orderedPhotos.count
                                )
                                .padding(.top, 64)
                                .padding(.trailing, 18)
                            }
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: orderedPhotos.count > 1 ? .automatic : .never))
        }
    }

    private var localMemoryPanel: some View {
        SipDetailPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    MugshotAvatar(name: user?.displayNameOrUsername ?? "User", size: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isOwnVisit ? "Saved to your journal" : "Posted by \(user?.displayNameOrUsername ?? "Mugshot User")")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.espressoBrown)
                            .lineLimit(2)

                        Text(SipDetailFormat.timestamp(visit.createdAt))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.tertiaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)
                }

                if let caption = consumerPreviewCaption(visit.caption) {
                    MentionText(text: caption, mentions: visit.mentions)
                        .font(.system(size: 17))
                        .foregroundColor(.espressoBrown.opacity(0.82))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(isOwnVisit ? "No public tasting note yet." : "No tasting note was shared with this sip.")
                        .font(.system(size: 15))
                        .foregroundColor(.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SipTagGrid(tags: localTags)
            }
        }
    }

    private var localActionShelf: some View {
        SipDetailPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Sip actions")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.espressoBrown)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 94), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    SipActionButton(
                        title: isLiked ? "Liked" : "Like",
                        value: "\(visit.likeCount)",
                        systemImage: isLiked ? "heart.fill" : "heart",
                        isActive: isLiked,
                        isEnabled: dataManager.appData.currentUser != nil
                    ) {
                        toggleLocalLike()
                    }

                    SipActionButton(
                        title: "Comment",
                        value: "\(visit.commentCount)",
                        systemImage: "bubble.right",
                        isActive: isCommentFocused,
                        isEnabled: dataManager.appData.currentUser != nil
                    ) {
                        isCommentFocused = true
                    }

                    if cafe != nil {
                        SipActionButton(
                            title: cafe?.isFavorite == true ? "Saved" : "Save",
                            value: nil,
                            systemImage: cafe?.isFavorite == true ? "bookmark.fill" : "bookmark",
                            isActive: cafe?.isFavorite == true,
                            isEnabled: true
                        ) {
                            toggleLocalCafeFavorite()
                        }

                        if !isOwnVisit {
                            SipActionButton(
                                title: cafe?.wantToTry == true ? "Wanting" : "Want",
                                value: nil,
                                systemImage: cafe?.wantToTry == true ? "pin.fill" : "pin",
                                isActive: cafe?.wantToTry == true,
                                isEnabled: true
                            ) {
                                toggleLocalCafeWantToTry()
                            }
                        }
                    }

                    SipShareButton(text: localShareText)
                }
            }
        }
    }

    @ViewBuilder
    private var localPrivateNote: some View {
        if isOwnVisit,
           let notes = visit.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
           !notes.isEmpty {
            SipPrivateNotePanel(text: notes)
        }
    }

    private var localCommentsSection: some View {
        SipDetailPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Conversation")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.espressoBrown)

                    Spacer()

                    Text("\(visit.commentCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.espressoBrown.opacity(0.66))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.sandBeige.opacity(0.50))
                        .clipShape(Capsule())
                }

                if comments.isEmpty {
                    Text("No comments yet.")
                        .font(.system(size: 14))
                        .foregroundColor(.tertiaryText)
                        .padding(.vertical, 2)
                } else {
                    VStack(spacing: 10) {
                        ForEach(comments) { comment in
                            CommentRow(comment: comment, dataManager: dataManager)
                        }
                    }
                }

                if dataManager.appData.currentUser != nil {
                    HStack(alignment: .bottom, spacing: 10) {
                        TextField("Add a thought", text: $commentText, axis: .vertical)
                            .mugshotFormField()
                            .focused($isCommentFocused)
                            .lineLimit(1...4)
                            .submitLabel(.send)

                        Button(action: addComment) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 42, height: 42)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Post comment")
                    }
                }
            }
        }
    }

    private var localTags: [SipTag] {
        var tags = [
            SipTag(title: visit.visibility.rawValue, systemImage: visibilityIcon(for: visit.visibility), isActive: true),
            SipTag(title: visit.drinkType.rawValue, systemImage: "tag.fill", isActive: false)
        ]

        if localDrinkDisplayName != visit.drinkType.rawValue {
            tags.append(SipTag(title: localDrinkDisplayName, systemImage: "sparkles", isActive: false))
        }

        tags.append(SipTag(title: SipDetailFormat.relative(visit.createdAt), systemImage: "clock.fill", isActive: false))

        return tags
    }

    private var localAudienceLabel: String {
        if isOwnVisit {
            return visit.visibility.rawValue
        }

        switch visit.visibility {
        case .private:
            return "Private sip"
        case .friends:
            return "Friend sip"
        case .everyone:
            return "Public sip"
        }
    }

    private var localShareText: String {
        "\(user?.displayNameOrUsername ?? "A Mugshot user") rated \(localDrinkDisplayName) \(String(format: "%.1f", visit.overallScore)) at \(cafe?.name ?? "a cafe") on Mugshot."
    }

    private func refreshVisit() {
        if let updatedVisit = dataManager.getVisit(id: visit.id) {
            visit = updatedVisit
            selectedPhotoIndex = min(selectedPhotoIndex, max(0, getOrderedPhotos(for: updatedVisit).count - 1))
        }
    }

    private func toggleLocalLike() {
        guard let userId = dataManager.appData.currentUser?.id else {
            return
        }

        dataManager.toggleVisitLike(visit.id, userId: userId)
        refreshVisit()
    }

    private func toggleLocalCafeFavorite() {
        guard let cafe else {
            return
        }

        dataManager.setCafeState(
            cafeId: cafe.id,
            isFavorite: !cafe.isFavorite,
            wantToTry: cafe.wantToTry
        )
    }

    private func toggleLocalCafeWantToTry() {
        guard let cafe else {
            return
        }

        dataManager.setCafeState(
            cafeId: cafe.id,
            isFavorite: cafe.isFavorite,
            wantToTry: !cafe.wantToTry
        )
    }

    private func visibilityIcon(for visibility: VisitVisibility) -> String {
        switch visibility {
        case .private:
            return "lock.fill"
        case .friends:
            return "person.2.fill"
        case .everyone:
            return "globe"
        }
    }
    
    private func addComment() {
        guard let userId = dataManager.appData.currentUser?.id,
              !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        dataManager.addComment(to: visit.id, userId: userId, text: commentText)
        commentText = ""
        isCommentFocused = false
        
        // Refresh visit to get updated comments
        if let updatedVisit = dataManager.getVisit(id: visit.id) {
            visit = updatedVisit
        }
    }

    private func detailLine(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.espressoBrown)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }
    
    // Simple edit screen for a sip (caption, notes, ratings, visibility)
    struct EditVisitView: View {
        @Environment(\.dismiss) var dismiss
        @ObservedObject var dataManager: DataManager
        @State private var editableVisit: Visit
        var onSave: (Visit) -> Void
        
        init(visit: Visit, dataManager: DataManager, onSave: @escaping (Visit) -> Void) {
            self._editableVisit = State(initialValue: visit)
            self.dataManager = dataManager
            self.onSave = onSave
        }
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Caption
                        VStack(alignment: .leading, spacing: 8) {
                            MugshotSectionTitle(title: "Public note")
                            TextField("What should people remember?", text: $editableVisit.caption, axis: .vertical)
                                .lineLimit(3...6)
                                .mugshotFormField()
                        }
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            MugshotSectionTitle(title: "Private note")
                            TextField("Only visible to you", text: Binding(get: { editableVisit.notes ?? "" }, set: { editableVisit.notes = $0 }), axis: .vertical)
                                .lineLimit(3...8)
                                .mugshotFormField()
                        }
                        
                        // Visibility
                        VStack(alignment: .leading, spacing: 8) {
                            MugshotSectionTitle(title: "Audience")
                            MugshotSegmentedControl(
                                options: [VisitVisibility.private, .friends, .everyone],
                                selection: $editableVisit.visibility,
                                title: { $0.rawValue },
                                icon: { visibilityIcon(for: $0) }
                            )
                        }
                    }
                    .padding()
                    .cardStyle(radius: DesignSystem.Radius.heroCard)
                    .padding()
                }
                .background(Color.creamWhite)
                .navigationTitle("Edit sip")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(.espressoBrown)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            dataManager.updateVisit(editableVisit)
                            onSave(editableVisit)
                            dismiss()
                        }
                        .foregroundColor(.mugshotMint)
                    }
                }
            }
        }

        private func visibilityIcon(for visibility: VisitVisibility) -> String {
            switch visibility {
            case .private:
                return "lock.fill"
            case .friends:
                return "person.2.fill"
            case .everyone:
                return "globe"
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Helper to get ordered photos (poster first, then rest)
    private func getOrderedPhotos(for visit: Visit) -> [String] {
        guard !visit.photos.isEmpty else { return [] }
        
        var ordered = visit.photos
        if let posterPath = visit.posterImagePath,
           let posterIndex = ordered.firstIndex(of: posterPath) {
            // Move poster to front
            ordered.remove(at: posterIndex)
            ordered.insert(posterPath, at: 0)
        }
        return ordered
    }
}

struct CommentRow: View {
    let comment: Comment
    @ObservedObject var dataManager: DataManager
    
    var user: User? {
        // For now, use current user. Later, fetch by comment.userId
        dataManager.appData.currentUser?.id == comment.userId ? dataManager.appData.currentUser : nil
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MugshotAvatar(name: user?.username ?? "User", size: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(user?.username ?? "user")")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                
                MentionText(text: comment.text, mentions: comment.mentions)
                    .font(.system(size: 14))
                    .foregroundColor(.secondaryText)
                
                Text(timeAgoString(from: comment.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.6))
            }
            
            Spacer()
        }
        .padding()
        .background(Color.sandBeige.opacity(0.46))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
