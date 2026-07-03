//
//  FeedTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

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
                    .padding(.bottom, 24)
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
        .sheet(item: $selectedRemoteVisit, onDismiss: {
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
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.mugshotSage)

                    Text("Loading feed...")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else if let remoteVisitError {
            VStack(spacing: 10) {
                Text("Could not load feed")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.espressoBrown)

                Text(remoteVisitError)
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.65))
                    .multilineTextAlignment(.center)

                Button("Retry") {
                    Task {
                        await loadRemoteFeedIfNeeded()
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.mugshotSage)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            )
        } else if remoteVisits.isEmpty {
            MugsyEmptyStateView(
                asset: selectedScope == .friends ? .noFriends : .comingSoon,
                title: selectedScope == .friends ? "No friend-visible visits yet" : "No public visits yet",
                message: selectedScope == .friends ? "Friend-visible sips will appear here as the beta loop grows." : "Public sips will appear here as people log them."
            )
        } else {
            ForEach(remoteVisits) { visit in
                RemoteFeedVisitCard(
                    visit: visit,
                    isCafeSaved: isCafeSaved(for: visit),
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
            remoteVisits = []
            remoteVisitError = error.localizedDescription
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
            } catch {
                updateRemoteVisit(id: visit.id, socialState: visit.socialState)
            }
        }
    }

    private func saveCafe(from visit: RemoteVisitSummary) {
        guard let remoteCafe = visit.cafe else {
            return
        }

        let localCafe = dataManager.upsertRemoteCafe(
            remoteCafe,
            isFavorite: true,
            wantToTry: existingCafeState(for: remoteCafe.id).wantToTry
        )

        guard let userId = authModel.authenticatedUser?.id else {
            return
        }

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
            } catch {
                // The optimistic local save is harmless and can be reconciled by Saved sync.
            }
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
            footer
        }
        .cardStyle(radius: DesignSystem.Radius.heroCard)
    }

    private var authorHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            MugshotAvatar(name: visit.authorDisplayName, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(visit.authorDisplayName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.espressoBrown)
                    .lineLimit(1)

                Text("@\(visit.authorUsername) · \(timeAgoString(from: visit.visit.createdAtDate))")
                    .font(.system(size: 13))
                    .foregroundColor(.espressoBrown.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            scoreBadge
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
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
            .frame(height: hasPhoto ? 290 : 220)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))

            locationOverlay
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
        .background(Color.espressoBrown.opacity(0.72))
        .clipShape(Capsule())
        .padding(12)
    }

    private var contentBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(visit.visit.drinkDisplayName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.espressoBrown)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !visit.visit.caption.isEmpty {
                Text(visit.visit.caption)
                    .font(.system(size: 15))
                    .foregroundColor(.espressoBrown.opacity(0.74))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if let category = visit.visit.drinkCategoryDisplayName,
                   category != visit.visit.drinkDisplayName {
                    feedMetaPill(category, systemImage: "tag.fill")
                }

                feedMetaPill(visit.visit.contextDisplayName, systemImage: "cup.and.saucer.fill")
                feedMetaPill(visit.visit.backendVisibilityLabel, systemImage: visibilityIcon)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        HStack(spacing: 22) {
            Button(action: onLike) {
                Label("\(visit.socialState.likeCount)", systemImage: visit.socialState.currentUserHasLiked ? "heart.fill" : "heart")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)

            Button(action: onComment) {
                Label("\(visit.socialState.commentCount)", systemImage: "bubble.right")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)

            Button(action: onSaveCafe) {
                Image(systemName: isCafeSaved ? "bookmark.fill" : "bookmark")
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button(action: onOpen) {
                HStack(spacing: 6) {
                Text("Details")
                Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
        }
        .font(.system(size: 19, weight: .medium))
        .foregroundColor(.roastBrown.opacity(0.82))
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
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

    private var visibilityIcon: String {
        switch visit.visit.backendVisibilityLabel.lowercased() {
        case "private":
            return "lock.fill"
        case "friends":
            return "person.2.fill"
        default:
            return "globe"
        }
    }

    private func feedMetaPill(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(.roastBrown.opacity(0.78))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.sandBeige.opacity(0.55))
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

            Text("No photo yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondaryText)

            Spacer(minLength: 92)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sandBeige.opacity(0.72))
    }
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
            // Top author bar
            HStack(alignment: .top, spacing: 12) {
                // Avatar - 32pt diameter
                MugshotAvatar(name: user?.username ?? "User", size: 32)
                
                // Name and date
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(user?.displayNameOrUsername ?? user?.username ?? "user")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.espressoBrown)
                        
                        if isCurrentUser {
                            Text("You")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                    .background(Color.mugshotSage)
                                .cornerRadius(10)
                        }
                    }
                    
                    Text(formatDate(visit.createdAt))
                        .font(.system(size: 13))
                        .foregroundColor(.espressoBrown.opacity(0.6))
                }
                
                Spacer()
                
                // Rating badge
                MugshotRatingBadge(score: visit.overallScore)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)
            
            // Main hero image - fixed 4:3 aspect ratio
            if !visit.photos.isEmpty {
                PosterImageView(visit: visit)
                    .aspectRatio(4/3, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                // Placeholder when no photo
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(Color.sandBeige.opacity(0.72))
                    .aspectRatio(4/3, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(.roastBrown.opacity(0.42))
                    )
            }
            
            VStack(alignment: .leading, spacing: 10) {
                // Cafe + drink info row
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                    .foregroundColor(.mugshotSage)
                        Button(action: {
                            onCafeTap?()
                        }) {
                            Text(cafe?.name ?? "Unknown Café")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.espressoBrown)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(visit.drinkType.rawValue + (visit.customDrinkType.map { " • \($0)" } ?? ""))
                        .font(.system(size: 14))
                        .foregroundColor(.espressoBrown.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                // Caption
                if !visit.caption.isEmpty {
                    MentionText(text: visit.caption, mentions: visit.mentions)
                        .font(.system(size: 14))
                        .foregroundColor(.espressoBrown)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                }
                
                // Social row
                HStack(spacing: 16) {
                    Button(action: {
                        if let userId = dataManager.appData.currentUser?.id {
                            dataManager.toggleVisitLike(visit.id, userId: userId)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 15))
                            .foregroundColor(isLiked ? .mugshotSage : .roastBrown.opacity(0.7))
                            Text("\(visit.likeCount)")
                                .font(.system(size: 14))
                                .foregroundColor(.espressoBrown.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 15))
                            .foregroundColor(.espressoBrown.opacity(0.7))
                        Text("\(visit.commentCount)")
                            .font(.system(size: 14))
                            .foregroundColor(.espressoBrown.opacity(0.7))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .cardStyle(radius: DesignSystem.Radius.heroCard)
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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Photo carousel
                        if !visit.photos.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    // Show poster image first, then rest
                                    let orderedPhotos = getOrderedPhotos(for: visit)
                                    ForEach(orderedPhotos, id: \.self) { photoPath in
                                        PhotoImageView(photoPath: photoPath)
                                            .frame(width: 310, height: 310)
                                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous))
                                    }
                                }
                                .padding()
                            }
                        } else {
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous)
                                .fill(Color.sandBeige.opacity(0.72))
                                .frame(height: 200)
                                .overlay(
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 34, weight: .semibold))
                                        .foregroundColor(.roastBrown.opacity(0.42))
                                )
                                .padding(.horizontal)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // Header: Cafe + Author
                            VStack(alignment: .leading, spacing: 8) {
                                Text(cafe?.name ?? "Unknown Café")
                                    .mugshotDisplay(size: 29)
                                    .foregroundColor(.espressoBrown)
                                
                                if let address = cafe?.address, !address.isEmpty {
                                    Text(address)
                                        .font(.system(size: 14))
                                        .foregroundColor(.tertiaryText)
                                }
                                
                                HStack(spacing: 8) {
                                    MugshotAvatar(name: user?.username ?? "User", size: 40)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("@\(user?.username ?? "user")")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.espressoBrown)
                                        
                                        Text(timeAgoString(from: visit.createdAt))
                                            .font(.system(size: 12))
                                            .foregroundColor(.espressoBrown.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.top, 8)
                            }
                            
                            // Drink type
                            detailLine(
                                title: "Drink",
                                value: visit.drinkType.rawValue + (visit.customDrinkType.map { " • \($0)" } ?? "")
                            )
                            
                            // Overall score
                            HStack {
                                MugshotSectionTitle(title: "Overall Score")
                                
                                Spacer()
                                
                                MugshotRatingBadge(score: visit.overallScore)
                            }
                            
                            // Rating breakdown
                            VStack(alignment: .leading, spacing: 12) {
                                MugshotSectionTitle(title: "Rating Breakdown")
                                
                                ForEach(Array(visit.ratings.keys.sorted()), id: \.self) { category in
                                    if let rating = visit.ratings[category] {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(category)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.espressoBrown)
                                                Spacer()
                                                Text(String(format: "%.1f", rating))
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.mugshotSage)
                                            }
                                            
                                            ProgressView(value: rating, total: 5.0)
                                                .tint(.mugshotSage)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .mugshotSunkenPanel()
                            
                            // Caption with mentions
                            if !visit.caption.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    MugshotSectionTitle(title: "Caption")
                                    
                                    MentionText(text: visit.caption, mentions: visit.mentions)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondaryText)
                                }
                            }
                            
                            // Notes (private)
                            if let notes = visit.notes, !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    MugshotSectionTitle(title: "Private Notes")
                                    
                                    Text(notes)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondaryText)
                                }
                            }
                            
                            Divider()
                            
                            // Social actions
                            HStack(spacing: 32) {
                                Button(action: {
                                    if let userId = dataManager.appData.currentUser?.id {
                                        dataManager.toggleVisitLike(visit.id, userId: userId)
                                        // Update local visit state
                                        if let updatedVisit = dataManager.getVisit(id: visit.id) {
                                            visit = updatedVisit
                                        }
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: isLiked ? "heart.fill" : "heart")
                                            .font(.system(size: 18))
                                            .foregroundColor(isLiked ? .mugshotSage : .roastBrown.opacity(0.7))
                                        Text("\(visit.likeCount)")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.espressoBrown)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "bubble.right")
                                        .font(.system(size: 18))
                                        .foregroundColor(.espressoBrown.opacity(0.7))
                                    Text("\(visit.commentCount)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.espressoBrown)
                                }
                            }
                            .padding(.vertical, 8)
                            
                            // Comments section
                            VStack(alignment: .leading, spacing: 12) {
                                MugshotSectionTitle(title: "Comments")
                                
                                if comments.isEmpty {
                                    Text("No comments yet")
                                        .font(.system(size: 14))
                                        .foregroundColor(.tertiaryText)
                                        .padding(.vertical, 8)
                                } else {
                                    ForEach(comments) { comment in
                                        CommentRow(comment: comment, dataManager: dataManager)
                                    }
                                }
                            }
                        }
                        .padding()
                        .cardStyle(radius: DesignSystem.Radius.heroCard)
                        .padding(.horizontal)
                    }
                }
                
                // Comment composer
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        TextField("Add a comment…", text: $commentText, axis: .vertical)
                            .mugshotFormField()
                            .focused($isCommentFocused)
                            .lineLimit(1...4)
                        
                        Button(action: {
                            addComment()
                        }) {
                            Text("Send")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.mugshotSage)
                        }
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    .background(Color.creamWhite)
                }
            }
            .background(Color.creamWhite)
            .navigationTitle("Visit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                    // Menu for edit/delete if this is the current user's visit
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if let currentUserId = dataManager.appData.currentUser?.id, currentUserId == visit.userId {
                            Menu {
                                Button("Edit") { showEdit = true }
                                Button(role: .destructive) {
                                    showDeleteAlert = true
                                } label: {
                                    Text("Delete")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.espressoBrown)
                            }
                        }
                    }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Refresh visit data
                if let updatedVisit = dataManager.getVisit(id: visit.id) {
                    visit = updatedVisit
                }
            }
                .sheet(isPresented: $showEdit) {
                    EditVisitView(visit: visit, dataManager: dataManager) { updated in
                        visit = updated
                    }
                }
                .alert("Delete this visit?", isPresented: $showDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        dataManager.deleteVisit(id: visit.id)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will remove it from your map, feed, and saved lists.")
                }
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
    
    // Simple edit screen for a visit (caption, notes, ratings, visibility)
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
                            MugshotSectionTitle(title: "Caption")
                            TextField("Caption", text: $editableVisit.caption, axis: .vertical)
                                .lineLimit(3...6)
                                .mugshotFormField()
                        }
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            MugshotSectionTitle(title: "Notes")
                            TextField("Notes", text: Binding(get: { editableVisit.notes ?? "" }, set: { editableVisit.notes = $0 }), axis: .vertical)
                                .lineLimit(3...8)
                                .mugshotFormField()
                        }
                        
                        // Visibility
                        VStack(alignment: .leading, spacing: 8) {
                            MugshotSectionTitle(title: "Visibility")
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
                .navigationTitle("Edit Visit")
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
