//
//  SavedTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI
import UIKit

/// Retained temporarily as a compile-safe reference while the production
/// Saved library is supplied by `SavedCafeLibraryView.swift`.
private struct LegacySavedTabView: View {
    @ObservedObject var dataManager: DataManager
    var onLogVisitRequested: ((Cafe) -> Void)? = nil
    var onAuthenticationRequired: ((_ title: String, _ message: String) -> Void)? = nil
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var selectedSection: SavedSection = .cafes
    @State private var selectedTab: SavedTab = .favorites
    @State private var sortOption: SortOption = .score
    @State private var activeSheet: SavedSheet?
    @State private var isLoadingRemoteStates = false
    @State private var remoteStateError: String?
    @State private var remoteCafeCoverURLs: [UUID: String] = [:]
#if DEBUG
    @State private var auditRetrySucceeded = false
#endif
    @AppStorage(RoadmapFeatureFlags.phase4LightweightFriends) private var phase4LightweightFriends = true

    enum SavedSection: String, CaseIterable {
        case cafes = "Cafes"
        case lists = "Lists"
    }
    
    enum SavedTab: String, CaseIterable {
        case favorites = "Favorites"
        case wantToTry = "Want to Try"
        case allCafes = "All Cafes"
    }
    
    enum SortOption: String, CaseIterable {
        case score = "By Sip History"
        case date = "By Date"
        case name = "By Name"

        var iconName: String {
            switch self {
            case .score:
                return "star.fill"
            case .date:
                return "clock.fill"
            case .name:
                return "textformat.abc"
            }
        }
    }

    private var savedSubtitle: String {
        if selectedSection == .lists {
            return "Plan places together"
        }
        switch selectedTab {
        case .favorites:
            return "Your personal cafe library"
        case .wantToTry:
            return "Plan your next sip"
        case .allCafes:
            return "Every cafe in your Mugshot"
        }
    }

    private var emptyTitle: String {
        switch selectedTab {
        case .favorites:
            return "No favorites yet"
        case .wantToTry:
            return "No want-to-try cafes yet"
        case .allCafes:
            return "No cafes yet"
        }
    }

    private var emptyMessage: String {
        switch selectedTab {
        case .favorites:
            return "Favorite cafes from Map or Cafe Detail and they will stay here."
        case .wantToTry:
            return "Mark cafes as Want to Try when you are planning the next stop."
        case .allCafes:
            return "Log a visit or save a cafe to start building your library."
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MugshotScreenHeader("Saved", subtitle: savedSubtitle) {
                    Menu {
                        if selectedSection == .cafes {
                            Picker("View", selection: $selectedTab) {
                                ForEach(SavedTab.allCases, id: \.self) { tab in
                                    Text(tab.rawValue).tag(tab)
                                }
                            }

                            if selectedTab == .allCafes {
                                Picker("Sort All Cafes", selection: $sortOption) {
                                    ForEach(SortOption.allCases, id: \.self) { option in
                                        Label(option.rawValue, systemImage: option.iconName).tag(option)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                            .frame(width: 36, height: 36)
                            .background(Color.foamWhite)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.mugshotLine, lineWidth: 1))
                    }
                    .accessibilityLabel("Saved filters")
                }

                if phase4LightweightFriends, authModel.authenticatedUser != nil {
                    MugshotSegmentedControl(
                        options: SavedSection.allCases,
                        selection: $selectedSection,
                        title: { $0.rawValue },
                        icon: { $0 == .cafes ? "cup.and.saucer.fill" : "rectangle.stack.fill" }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }

                if selectedSection == .cafes {
                    MugshotSegmentedControl(
                        options: SavedTab.allCases,
                        selection: $selectedTab,
                        title: { $0.rawValue }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }

                if selectedSection == .cafes, selectedTab == .allCafes {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                MugshotFilterChip(
                                    title: option.rawValue,
                                    icon: option.iconName,
                                    isSelected: sortOption == option
                                ) {
                                    withAnimation(DesignSystem.Motion.base) {
                                        sortOption = option
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }

                if selectedSection == .cafes, shouldShowRemoteStateStatus {
                    remoteStateStatus
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }
                
                // Cafe list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if selectedSection == .lists,
                           phase4LightweightFriends,
                           let currentUserID = authModel.authenticatedUser?.id {
                            SharedCafeListsView(
                                dataManager: dataManager,
                                currentUserID: currentUserID
                            )
                        } else if filteredAndSortedCafes.isEmpty {
                            SavedEmptyStateView(
                                placement: mugsyPlacement(for: selectedTab),
                                title: emptyTitle,
                                message: emptyMessage
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        } else {
                            ForEach(filteredAndSortedCafes) { cafe in
                                CafeCard(
                                    cafe: cafe,
                                    dataManager: dataManager,
                                    showWantToTryTag: selectedTab == .wantToTry,
                                    communityImageURL: remoteCafeCoverURLs[cafe.remoteCafeId ?? cafe.id],
                                    onLogVisit: {
                                        onLogVisitRequested?(cafe)
                                    },
                                    onShowDetails: {
                                        activeSheet = .cafeDetail(cafe)
                                    }
                                )
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 116)
                    .animation(MugshotMotion.response, value: filteredAndSortedCafes.count)
                }
            }
            .background(Color.creamWhite)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task(id: "\(authModel.authenticatedUser?.id.uuidString ?? "signed-out")-\(dataManager.journalRevision)") {
                if authModel.authenticatedUser == nil { selectedSection = .cafes }
                await loadRemoteCafeStates()
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .cafeDetail(let cafe):
                CafeDetailView(
                    cafe: cafe,
                    dataManager: dataManager,
                    onLogVisitRequested: onLogVisitRequested,
                    onAuthenticationRequired: onAuthenticationRequired
                )
            }
        }
    }

    @ViewBuilder
    private var remoteStateStatus: some View {
#if DEBUG
        if let scenario = MugshotLaunchEnvironment.savedAuditScenario,
           scenario.showsForcedSavedStatus,
           !auditRetrySucceeded {
            if scenario.isForcedLoading {
                remoteLoadingStatus
            } else if let message = scenario.forcedSavedErrorMessage {
                MugshotRecoveryCard(
                    title: "Couldn’t refresh saved cafes",
                    message: message,
                    actionTitle: "Retry"
                ) {
                    auditRetrySucceeded = true
                }
            }
        } else if isLoadingRemoteStates {
            remoteLoadingStatus
        } else if let remoteStateError {
            remoteRecoveryStatus(message: remoteStateError)
        }
#else
        if isLoadingRemoteStates {
            remoteLoadingStatus
        } else if let remoteStateError {
            remoteRecoveryStatus(message: remoteStateError)
        }
#endif
    }

    private var remoteLoadingStatus: some View {
        HStack(spacing: 8) {
            ProgressView().tint(.mugshotSage)
            Text("Refreshing saved cafes…")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondaryText)
        }
    }

    private func remoteRecoveryStatus(message: String) -> some View {
        MugshotRecoveryCard(
            title: "Couldn’t refresh saved cafes",
            message: message,
            actionTitle: "Retry"
        ) {
            Task { await loadRemoteCafeStates() }
        }
    }

    private var shouldShowRemoteStateStatus: Bool {
#if DEBUG
        if MugshotLaunchEnvironment.savedAuditScenario?.showsForcedSavedStatus == true {
            return true
        }
#endif
        return authModel.authenticatedUser != nil
    }

    @MainActor
    private func loadRemoteCafeStates() async {
#if DEBUG
        if MugshotLaunchEnvironment.savedAuditScenario != nil {
            isLoadingRemoteStates = false
            remoteStateError = nil
            remoteCafeCoverURLs = [:]
            return
        }
#endif
        guard let userId = authModel.authenticatedUser?.id else {
            remoteStateError = nil
            remoteCafeCoverURLs = [:]
            return
        }

        isLoadingRemoteStates = true
        remoteStateError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = CafeStateService(client: client)
            let states = try await service.fetchCafeStates(userId: userId)
            dataManager.applyRemoteCafeStates(states)

            let discoveredCafes = (try? await SocialDiscoveryService(client: client).discovery(
                section: .saved,
                location: nil,
                radiusKM: 100,
                limit: 50
            )) ?? []
            for cafe in discoveredCafes {
                dataManager.upsertRemoteCafe(
                    cafe.remoteCafe,
                    averageRating: cafe.averageRating,
                    visitCount: cafe.visibleVisitCount,
                    persist: false
                )
            }
            if !discoveredCafes.isEmpty {
                dataManager.save()
            }
            remoteCafeCoverURLs = Dictionary(
                uniqueKeysWithValues: discoveredCafes.compactMap { cafe in
                    guard let cover = cafe.recentCover?.remoteTrimmedNonEmpty else { return nil }
                    return (cafe.id, cover)
                }
            )
            isLoadingRemoteStates = false
        } catch {
            guard !Task.isCancelled else { return }
            remoteStateError = MugshotUserFacingError.message(for: error, context: .loading)
            isLoadingRemoteStates = false
        }
    }
    
    private var filteredAndSortedCafes: [Cafe] {
        var cafes: [Cafe]
        
        switch selectedTab {
        case .favorites:
            cafes = dataManager.appData.cafes.filter { $0.isFavorite }
        case .wantToTry:
            cafes = dataManager.appData.cafes.filter { $0.wantToTry }
        case .allCafes:
            cafes = dataManager.appData.cafes
        }
        
        // Sort
        switch sortOption {
        case .score:
            return cafes.sorted { $0.averageRating > $1.averageRating }
        case .date:
            // Sort by most recent visit
            return cafes.sorted { cafe1, cafe2 in
                let visits1 = dataManager.getVisitsForCafe(cafe1.id)
                let visits2 = dataManager.getVisitsForCafe(cafe2.id)
                let date1 = visits1.first?.date ?? Date.distantPast
                let date2 = visits2.first?.date ?? Date.distantPast
                return date1 > date2
            }
        case .name:
            return cafes.sorted { $0.name < $1.name }
        }
    }

    private func mugsyPlacement(for tab: SavedTab) -> MugsyPlacement {
        switch tab {
        case .favorites:
            return .savedFavorites
        case .wantToTry:
            return .savedWishlist
        case .allCafes:
            return .savedCafes
        }
    }
}

struct SavedEmptyStateView: View {
    let placement: MugsyPlacement
    let title: String
    let message: String

    var body: some View {
        MugsyEmptyStateView(placement: placement, title: title, message: message)
    }
}

enum SavedSheet: Identifiable {
    case cafeDetail(Cafe)

    var id: String {
        switch self {
        case .cafeDetail(let cafe):
            return "detail-\(cafe.id.uuidString)"
        }
    }
}

struct CafeCard: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    let showWantToTryTag: Bool
    let communityImageURL: String?
    let placeImageURL: String?
    let onLogVisit: () -> Void
    let onShowDetails: () -> Void

    init(
        cafe: Cafe,
        dataManager: DataManager,
        showWantToTryTag: Bool,
        communityImageURL: String? = nil,
        placeImageURL: String? = nil,
        onLogVisit: @escaping () -> Void,
        onShowDetails: @escaping () -> Void
    ) {
        self.cafe = cafe
        self.dataManager = dataManager
        self.showWantToTryTag = showWantToTryTag
        self.communityImageURL = communityImageURL
        self.placeImageURL = placeImageURL
        self.onLogVisit = onLogVisit
        self.onShowDetails = onShowDetails
    }
    
    // Get cafe image from most recent visit, or nil if no visits/photos
    var cafeImagePath: String? {
        let visits = dataManager.getVisitsForCafe(cafe.id)
        let sortedVisits = visits.sorted { $0.createdAt > $1.createdAt }
        return sortedVisits.first?.posterImagePath
    }

    private var displayedVisitCount: Int {
        max(cafe.visitCount, dataManager.getVisitsForCafe(cafe.id).count)
    }

    private var cafeImageSource: CafeCardImageSource {
        CafeCardImageSource.preferred(
            personalJournalPath: cafeImagePath,
            placePhotoURL: placeImageURL,
            communityPhotoURL: communityImageURL
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onShowDetails) {
                HStack(alignment: .top, spacing: 14) {
                    cafeImage

                    VStack(alignment: .leading, spacing: 9) {
                        Text(cafe.consumerDisplayName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.espressoBrown)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)

                        if !cafe.address.isEmpty {
                            Label(cafe.address, systemImage: "mappin.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.espressoBrown.opacity(0.62))
                                .lineLimit(2)
                        }

                        HStack(spacing: 8) {
                            if cafe.isFavorite {
                                cafePill("Favorite", systemImage: "heart.fill")
                            }

                            if cafe.wantToTry || showWantToTryTag {
                                cafePill("Want to Try", systemImage: "bookmark.fill")
                            }
                        }

                        HStack(spacing: 8) {
                            cafePill(
                                "\(displayedVisitCount) \(displayedVisitCount == 1 ? "sip" : "sips")",
                                systemImage: "cup.and.saucer.fill"
                            )

                            if let category = cafe.consumerPlaceCategory {
                                cafePill(category, systemImage: "tag.fill")
                            }
                        }
                    }
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "\(cafe.consumerDisplayName), \(cafe.consumerScoreLabel), \(displayedVisitCount) sips"
            )
            .accessibilityHint("Opens cafe details")

            Divider()
                .padding(.horizontal, 12)

            Button(action: onLogVisit) {
                Label("Log a Sip", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.espressoBrown)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityHint("Opens a new sip with this cafe selected")
            .padding(.vertical, 10)
        }
        .cardStyle(radius: DesignSystem.Radius.card)
    }

    @ViewBuilder
    private var cafeImage: some View {
        Group {
            switch cafeImageSource {
            case .personalJournal(let imagePath):
            PhotoThumbnailView(photoPath: imagePath, size: 112)
            case .place(let url), .community(let url):
                RemotePhotoImageView(
                    urlString: url,
                    placeholderSystemName: "cup.and.saucer.fill",
                    contentMode: .fill
                )
            case .placeholder:
                MugsyPhotoPlaceholderView(
                    scene: MugsySceneResolver.cafePhoto(
                        stableID: cafe.id.uuidString,
                        origin: .library,
                        isFavorite: cafe.isFavorite,
                        wantToTry: cafe.wantToTry,
                        hasVisited: displayedVisitCount > 0
                    ),
                    style: .card,
                    photoDescription: "No cafe photo yet"
                )
            }
        }
        .frame(width: 112, height: 142)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
        .overlay(alignment: .topTrailing) {
            scoreBadge
                .padding(6)
        }
    }

    private var scoreBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(cafe.consumerScoreLabel)
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(.espressoBrown)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.foamWhite.opacity(0.9), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 2)
    }

    private var savedActionDivider: some View {
        Rectangle()
            .fill(Color.sandBeige.opacity(0.9))
            .frame(width: 1, height: 22)
    }

    private func cafePill(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(.roastBrown.opacity(0.78))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.sandBeige.opacity(0.55))
        .clipShape(Capsule())
    }

    private func savedCardAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundColor(.espressoBrown.opacity(0.76))
            .frame(maxWidth: .infinity)
            .frame(height: 26)
        }
        .buttonStyle(.plain)
    }
    
    private func openInMaps() {
        guard let location = cafe.location else { return }
        
        if let mapURLString = cafe.mapItemURL, let url = URL(string: mapURLString) {
            UIApplication.shared.open(url)
        } else {
            let urlString = "http://maps.apple.com/?ll=\(location.latitude),\(location.longitude)&q=\(cafe.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func openWebsite(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct CommunityDrinkCount: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

struct CafeDetailView: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    let initialDetent: PresentationDetent
    var onLogVisitRequested: ((Cafe) -> Void)? = nil
    var onAuthenticationRequired: ((_ title: String, _ message: String) -> Void)? = nil
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showLogVisit = false
    @State private var isSyncingCafeState = false
    @State private var cafeStateError: String?
    @State private var remoteVisits: [RemoteVisitSummary] = []
    @State private var isLoadingRemoteVisits = false
    @State private var remoteVisitError: String?
    @State private var selectedRemoteVisit: RemoteVisitSummary?
    @State private var friendUserIDs: Set<UUID> = []
    @State private var cafeExperienceSummary: RemoteCafeExperienceSummary?
    @State private var isLoadingCafeExperienceSummary = false
    @State private var cafeExperienceSummaryError: String?
    @State private var selectedDetent: PresentationDetent
    @State private var showListMembership = false
    @State private var showReportUnavailable = false

    init(
        cafe: Cafe,
        dataManager: DataManager,
        initialDetent: PresentationDetent = .large,
        onLogVisitRequested: ((Cafe) -> Void)? = nil,
        onAuthenticationRequired: ((_ title: String, _ message: String) -> Void)? = nil
    ) {
        self.cafe = cafe
        self.dataManager = dataManager
        self.initialDetent = initialDetent
        self.onLogVisitRequested = onLogVisitRequested
        self.onAuthenticationRequired = onAuthenticationRequired
        _selectedDetent = State(initialValue: initialDetent)
    }

    var currentCafe: Cafe {
        dataManager.getCafe(id: cafe.id) ?? cafe
    }

    private var signedInRemoteCafeId: UUID? {
        guard authModel.authenticatedUser != nil else {
            return nil
        }

        return currentCafe.remoteCafeId
    }

    private var shouldShowRemoteVisits: Bool {
        signedInRemoteCafeId != nil
    }

    var visits: [Visit] {
        dataManager.getVisitsForCafe(currentCafe.id)
    }
    
    // Get hero image from most recent visit, or nil if no visits/photos
    var heroImagePath: String? {
        if shouldShowRemoteVisits,
           let remotePosterURL = CafePhotoSelection.mostRecentRemotePosterURL(in: remoteVisits) {
            return remotePosterURL
        }

        return CafePhotoSelection.mostRecentLocalPosterPath(in: visits)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if selectedDetent == .height(258) {
                    compactDetail
                } else if selectedDetent == .medium {
                    mediumDetail
                } else {
                    expandedDetail
                }
            }
            .background(Color.creamWhite)
            .navigationTitle("Cafe details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Close cafe card")
                }
            }
            .sheet(isPresented: $showLogVisit, onDismiss: {
                Task {
                    await loadRemoteVisits()
                    await loadCafeExperienceSummary()
                }
            }) {
                LogVisitView(dataManager: dataManager, preselectedCafe: currentCafe)
            }
            .sheet(isPresented: $showListMembership) {
                CafeListMembershipSheet(
                    cafe: currentCafe,
                    dataManager: dataManager,
                    onAuthenticationRequired: onAuthenticationRequired
                )
            }
            .alert("Reporting is coming soon", isPresented: $showReportUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Mugshot does not yet send cafe data reports. No report was submitted.")
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { selectedRemoteVisit != nil },
                    set: { if !$0 { selectedRemoteVisit = nil } }
                )
            ) {
                if let visit = selectedRemoteVisit {
                    RemoteVisitDetailView(
                        visitId: visit.id,
                        initialSummary: visit,
                        currentUserId: authModel.authenticatedUser?.id,
                        dataManager: dataManager,
                        onAuthenticationRequired: onAuthenticationRequired,
                        onCafeRequested: { _ in selectedRemoteVisit = nil }
                    )
                    .onDisappear { Task { await loadRemoteVisits() } }
                }
            }
            .task(id: remoteVisitTaskID) {
                await loadRemoteVisits()
            }
            .task(id: remoteVisitTaskID) {
                await loadCafeExperienceSummary()
            }
        }
        .presentationDetents([.height(258), .medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.creamWhite)
        .accessibilityIdentifier("cafe.detail.sheet")
    }

    private var compactDetail: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                detailIdentityImage(size: 72)
                VStack(alignment: .leading, spacing: 5) {
                    Text(currentCafe.consumerDisplayName)
                        .mugshotDisplay(size: 22)
                        .foregroundColor(.espressoBrown)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let compactMetadataLine {
                        Text(compactMetadataLine)
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }

            detailPrimaryAction

            Button {
                withAnimation(DesignSystem.Motion.base) { selectedDetent = .medium }
            } label: {
                Label("More details", systemImage: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.mugshotSageText)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Expands cafe details")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private var mediumDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 10) {
                            detailIdentityImage(size: 96)
                            Text(currentCafe.consumerDisplayName)
                                .mugshotDisplay(size: 24)
                                .foregroundColor(.espressoBrown)
                                .fixedSize(horizontal: false, vertical: true)
                            if let compactMetadataLine {
                                Text(compactMetadataLine)
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            detailIdentityImage(size: 78)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(currentCafe.consumerDisplayName)
                                    .mugshotDisplay(size: 24)
                                    .foregroundColor(.espressoBrown)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let metadataLine {
                                    Text(metadataLine)
                                        .font(.subheadline)
                                        .foregroundColor(.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }

                detailPrimaryAction
                detailUtilitiesSection
                personalRelationshipSection

                Button {
                    withAnimation(DesignSystem.Motion.base) { selectedDetent = .large }
                } label: {
                    Label("See full cafe details", systemImage: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.mugshotSageText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var expandedDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !dynamicTypeSize.isAccessibilitySize {
                    detailHero
                }

                VStack(alignment: .leading, spacing: 20) {
                    cafeSummarySection
                    detailPrimaryAction
                    detailUtilitiesSection
                    personalRelationshipSection

                    recentVisitsSection

                    if shouldShowRemoteVisits && !communityRemoteVisits.isEmpty {
                        communityHighlightsSection
                    }

                    secondaryActionsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
    }

    @ViewBuilder
    private var detailHero: some View {
        if let imagePath = heroImagePath {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if imagePath.hasPrefix("http") {
                        RemotePhotoImageView(urlString: imagePath, placeholderSystemName: "photo", contentMode: .fill)
                    } else {
                        PhotoImageView(photoPath: imagePath, contentMode: .fill)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()

                Text(heroPhotoProvenance)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.foamWhite)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(.black.opacity(0.58), in: Capsule())
                    .padding(12)
            }
        } else {
            MugsyPhotoPlaceholderView(
                scene: detailPhotoScene,
                style: .hero,
                photoDescription: "No cafe photo yet",
                animatesProminentMugsy: true
            )
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("No cafe photo yet")
        }
    }

    @ViewBuilder
    private func detailIdentityImage(size: CGFloat) -> some View {
        if let imagePath = heroImagePath {
            Group {
                if imagePath.hasPrefix("http") {
                    RemotePhotoImageView(urlString: imagePath, placeholderSystemName: "photo", contentMode: .fill)
                } else {
                    PhotoImageView(photoPath: imagePath, contentMode: .fill)
                }
            }
            .frame(width: size, height: size)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            MugsyPhotoPlaceholderView(
                scene: detailPhotoScene,
                style: .identity,
                photoDescription: "No cafe photo yet"
            )
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityLabel("No cafe photo yet")
        }
    }

    private var detailPhotoScene: MugsyScene {
        MugsySceneResolver.cafePhoto(
            stableID: currentCafe.id.uuidString,
            origin: .library,
            isFavorite: currentCafe.isFavorite,
            wantToTry: currentCafe.wantToTry,
            hasVisited: max(currentCafe.visitCount, visits.count) > 0 || !remoteVisits.isEmpty
        )
    }

    private var metadataLine: String? {
        [currentCafe.consumerPlaceCategory, currentCafe.address.remoteTrimmedNonEmpty]
            .compactMap { $0 }
            .joined(separator: " · ")
            .remoteTrimmedNonEmpty
    }

    private var compactMetadataLine: String? {
        let shortAddress = currentCafe.address.remoteTrimmedNonEmpty?
            .split(separator: ",", maxSplits: 1)
            .first
            .map(String.init)
        return [currentCafe.consumerPlaceCategory, shortAddress]
            .compactMap { $0?.remoteTrimmedNonEmpty }
            .joined(separator: " · ")
            .remoteTrimmedNonEmpty
    }

    private var heroPhotoProvenance: String {
        guard let heroImagePath else { return "No cafe photo yet" }
        if !heroImagePath.hasPrefix("http") { return "Photo from your Mugshot" }
        if ownRemoteVisits.contains(where: { $0.visit.posterPhotoURL == heroImagePath }) {
            return "Photo from your Mugshot"
        }
        return "Photo from a visible Mugshot"
    }

    private var remoteVisitTaskID: String {
        [
            authModel.authenticatedUser?.id.uuidString ?? "signed-out",
            currentCafe.remoteCafeId?.uuidString ?? "local"
        ].joined(separator: "-")
    }

    private var isPresentingCafeExperienceLoading: Bool {
#if DEBUG
        if MugshotLaunchEnvironment.savedAuditScenario == .detailLoading {
            return true
        }
#endif
        return isLoadingCafeExperienceSummary
    }

    private var presentedCafeExperienceError: String? {
#if DEBUG
        if MugshotLaunchEnvironment.savedAuditScenario == .detailError {
            return "Cafe relationship could not refresh."
        }
#endif
        return cafeExperienceSummaryError
    }

    private var cafeSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(currentCafe.name)
                .mugshotDisplay(size: 27)
                .foregroundColor(.espressoBrown)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !currentCafe.address.isEmpty {
                Label(currentCafe.address, systemImage: "mappin.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.tertiaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let category = currentCafe.consumerPlaceCategory {
                HStack(spacing: 5) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(category)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundColor(.roastBrown.opacity(0.78))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.sandBeige.opacity(0.58))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle(radius: DesignSystem.Radius.heroCard)
    }

    private var detailStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        personalSipAverageCard
                        cafeReflectionCard
                    }
                } else {
                    HStack(spacing: 10) {
                        personalSipAverageCard
                        cafeReflectionCard
                    }
                }
            }
            .redacted(
                reason: isPresentingCafeExperienceLoading && cafeExperienceSummary == nil
                    ? .placeholder
                    : []
            )

            if let summary = cafeExperienceSummary {
                cafeRelationshipEvidence(summary)
            }

            Text(personalHistoryLine)
                .font(.system(size: 13))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let favoriteDrinkEvidence {
                Label(favoriteDrinkEvidence, systemImage: "cup.and.saucer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.mugshotSageText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let presentedCafeExperienceError {
                Label(presentedCafeExperienceError, systemImage: "exclamationmark.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

        }
    }

    private var personalSipAverageCard: some View {
        detailStatCard(
            title: "Personal sip average",
            value: personalAverageRating.map { String(format: "%.1f", $0) } ?? "—",
            systemImage: "cup.and.saucer.fill"
        )
    }

    private var cafeReflectionCard: some View {
        detailStatCard(
            title: "Cafe reflection",
            value: cafeAverageDisplayValue,
            systemImage: "storefront.fill"
        )
    }

    private var detailPrimaryAction: some View {
        Button {
            if let onLogVisitRequested {
                onLogVisitRequested(currentCafe)
                return
            }
            guard authModel.authenticatedUser != nil else {
                onAuthenticationRequired?(
                    "Keep this sip in your journal",
                    "Sign in to log this cafe. You can still favorite it or save it to try while browsing as a guest."
                )
                return
            }
            showLogVisit = true
        } label: {
            Label("Log a Sip", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var personalRelationshipSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            MugshotSectionTitle(
                title: "Your Mugshot",
                subtitle: personalRelationshipSubtitle
            )

            detailStatsSection

            if currentCafe.isFavorite || currentCafe.wantToTry {
                HStack(spacing: 8) {
                    if currentCafe.isFavorite {
                        relationshipPill("Favorite", systemImage: "heart.fill")
                    }
                    if currentCafe.wantToTry {
                        relationshipPill("Want to Try", systemImage: "bookmark.fill")
                    }
                }
            }
        }
        .padding(16)
        .background(Color.mugshotMint.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotSage.opacity(0.28))
        )
    }

    private var ownRemoteVisits: [RemoteVisitSummary] {
        guard let userID = authModel.authenticatedUser?.id else { return [] }
        return remoteVisits.filter { $0.visit.userId == userID }
    }

    private var communityRemoteVisits: [RemoteVisitSummary] {
        guard let userID = authModel.authenticatedUser?.id else { return remoteVisits }
        return remoteVisits.filter { $0.visit.userId != userID }
    }

    private var personalSipCount: Int {
        max(visits.count, ownRemoteVisits.count)
    }

    private var cafeAverageDisplayValue: String {
        if isPresentingCafeExperienceLoading, cafeExperienceSummary == nil {
            return "—"
        }
        if presentedCafeExperienceError != nil, cafeExperienceSummary == nil {
            return "Unavailable"
        }
        guard let summary = cafeExperienceSummary,
              summary.ratedSessionCount > 0,
              let average = summary.averageCafeRating else {
            return "Cafe not rated yet"
        }
        return String(format: "%.1f", average)
    }

    private var cafePhysicalVisitDisplayValue: String {
        if isPresentingCafeExperienceLoading, cafeExperienceSummary == nil {
            return "—"
        }
        return cafeExperienceSummary.map { "\($0.physicalSessionCount)" } ?? "—"
    }

    private var personalAverageRating: Double? {
        let remoteScores = ownRemoteVisits.map(\.visit.overallScore).filter { $0 > 0 }
        if !remoteScores.isEmpty {
            return remoteScores.reduce(0, +) / Double(remoteScores.count)
        }
        let localScores = visits.map(\.overallScore).filter { $0 > 0 }
        guard !localScores.isEmpty else { return nil }
        return localScores.reduce(0, +) / Double(localScores.count)
    }

    private var personalRelationshipSubtitle: String {
        let remoteDate = ownRemoteVisits.map(\.visit.createdAtDate).max()
        let localDate = visits.map(\.createdAt).max()
        if let latest = [remoteDate, localDate].compactMap({ $0 }).max() {
            return "Last remembered \(latest.formatted(date: .abbreviated, time: .omitted))"
        }
        if currentCafe.wantToTry {
            return "Saved for a future coffee run"
        }
        if currentCafe.isFavorite {
            return "One of your favorite cafes"
        }
        return "New to you — log a sip or save it for later"
    }

    private var personalHistoryLine: String {
        let remoteDate = ownRemoteVisits.map(\.visit.createdAtDate).max()
        let localDate = visits.map(\.createdAt).max()
        let lastDate = [remoteDate, localDate].compactMap { $0 }.max()
        let count = personalSipCount
        let visitText = "\(count) \(count == 1 ? "sip" : "sips")"
        if let lastDate {
            return "\(visitText) · Last sip \(lastDate.formatted(date: .abbreviated, time: .omitted))"
        }
        return "No personal sips yet"
    }

    private var favoriteDrinkEvidence: String? {
        let names = ownRemoteVisits.map(\.visit.drinkDisplayName)
            + visits.map(\.journalDrinkName)
        guard !names.isEmpty else { return nil }
        let counts = Dictionary(grouping: names, by: { $0 }).mapValues(\.count)
        guard let favorite = counts.max(by: { lhs, rhs in
            lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
        }) else { return nil }
        return favorite.value > 1
            ? "\(favorite.key) · ordered \(favorite.value) times"
            : favorite.key
    }

    private func relationshipTruthHeader(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.espressoBrown)
    }

    @ViewBuilder
    private func cafeRelationshipEvidence(_ summary: RemoteCafeExperienceSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if summary.relationshipStage != .unrated {
                relationshipPill(
                    summary.relationshipStage.title,
                    systemImage: "chart.line.uptrend.xyaxis"
                )
            }

            if let nextMove = summary.nextMove {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.up.right")
                    Text("Next move")
                        .foregroundColor(.tertiaryText)
                    Text(nextMove.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.espressoBrown)
                }
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func relationshipPill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.roastBrown)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.sandBeige.opacity(0.7), in: Capsule())
    }

    private var detailUtilitiesSection: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 8),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 4
        )

        return VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                detailActionButton(
                    title: currentCafe.isFavorite ? "Favorited" : "Favorite",
                    systemImage: currentCafe.isFavorite ? "heart.fill" : "heart",
                    isSelected: currentCafe.isFavorite,
                    action: toggleFavorite
                )
                .disabled(isSyncingCafeState)

                detailActionButton(
                    title: "Want to Try",
                    systemImage: currentCafe.wantToTry ? "bookmark.fill" : "bookmark",
                    isSelected: currentCafe.wantToTry,
                    action: toggleWantToTry
                )
                .disabled(isSyncingCafeState)

                detailActionButton(
                    title: "Lists",
                    systemImage: "rectangle.stack.fill",
                    isSelected: false,
                    action: presentListMembership
                )

                detailActionButton(
                    title: "Directions",
                    systemImage: "location.north.fill",
                    isSelected: false,
                    action: openInMaps
                )
                .disabled(currentCafe.location == nil)
            }

            if let cafeStateError {
                Text(cafeStateError)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.82))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var communityHighlightsSection: some View {
        let friendVisits = Set(communityRemoteVisits.filter { friendUserIDs.contains($0.visit.userId) }.map(\.visit.userId)).count

        return VStack(alignment: .leading, spacing: 10) {
            MugshotSectionTitle(
                title: friendVisits == 0 ? "Community at this cafe" : "Friends at this cafe",
                subtitle: friendVisits == 0 ? "From visible community Mugshots" : "\(friendVisits) friends have shared visible Mugshots here"
            )
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(communityDrinkCounts.prefix(5)) { drink in
                        MugshotTagChip(title: "\(drink.name) · \(drink.count)")
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var communityDrinkCounts: [CommunityDrinkCount] {
        var counts: [String: Int] = [:]
        for visit in communityRemoteVisits {
            counts[visit.visit.drinkDisplayName, default: 0] += 1
        }
        return counts
            .map { CommunityDrinkCount(name: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }
    }

    private func detailStatCard(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 20 : 12, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.58))

            Text(value)
                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 28 : 22, weight: .bold))
                .foregroundColor(.espressoBrown)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.foamWhite.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.card).stroke(Color.mugshotLine))
    }

    private func detailActionButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    HStack(spacing: 12) {
                        Image(systemName: systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 28)
                        Text(title)
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                } else {
                    VStack(spacing: 7) {
                        Image(systemName: systemImage)
                            .font(.system(size: 20, weight: .semibold))
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
            }
                .foregroundColor(isSelected ? .mugshotSageText : .espressoBrown)
                .frame(maxWidth: .infinity, minHeight: 78)
                .background(isSelected ? Color.mugshotSage.opacity(0.34) : Color.sandBeige.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                        .stroke(isSelected ? Color.mugshotSage : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var recentVisitsSection: some View {
        if shouldShowRemoteVisits {
            remoteRecentVisitsSection
        } else if !visits.isEmpty {
            localRecentVisitsSection
        }
    }

    private var localRecentVisitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent sips")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.espressoBrown)
                .padding(.horizontal)
                .padding(.top, 8)

            ForEach(visits.prefix(5)) { visit in
                VisitRow(visit: visit, dataManager: dataManager)
                    .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    private var remoteRecentVisitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent sips")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.espressoBrown)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if isLoadingRemoteVisits && ownRemoteVisits.isEmpty && visits.isEmpty {
                MugshotLoadingState(layout: .journal, count: 2)
                    .padding(.horizontal)
            } else if let remoteVisitError {
                Text(remoteVisitError)
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            } else if ownRemoteVisits.isEmpty && !isLoadingRemoteVisits {
                if !visits.isEmpty {
                    ForEach(visits.prefix(5)) { visit in
                        VisitRow(visit: visit, dataManager: dataManager)
                            .padding(.horizontal)
                    }
                } else {
                    Text("No visits here yet.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondaryText)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                }
            } else {
                ForEach(ownRemoteVisits.prefix(5)) { visit in
                    RemoteCafeVisitRow(visit: visit) {
                        selectedRemoteVisit = visit
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top, 8)
    }

    private var secondaryActionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let websiteURL = currentCafe.websiteURL?.remoteTrimmedNonEmpty {
                Button {
                    openWebsite(urlString: websiteURL)
                } label: {
                    secondaryActionRow("Website", systemImage: "safari")
                }
                .buttonStyle(.plain)
            }

            ShareLink(
                item: [currentCafe.consumerDisplayName, currentCafe.address.remoteTrimmedNonEmpty]
                    .compactMap { $0 }
                    .joined(separator: " — ")
            ) {
                secondaryActionRow("Share cafe", systemImage: "square.and.arrow.up")
            }

            if let address = currentCafe.address.remoteTrimmedNonEmpty {
                Button {
                    UIPasteboard.general.string = address
                } label: {
                    secondaryActionRow("Copy address", systemImage: "doc.on.doc")
                }
                .buttonStyle(.plain)
            }

            Button {
                showReportUnavailable = true
            } label: {
                secondaryActionRow("Report a data issue", systemImage: "exclamationmark.bubble")
            }
            .buttonStyle(.plain)
        }
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mugshotLine))
    }

    private func secondaryActionRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.mugshotSageText)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.espressoBrown)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private func presentListMembership() {
        guard authModel.authenticatedUser != nil else {
            onAuthenticationRequired?(
                "Keep cafe lists in sync",
                "Sign in to add this cafe to a private or shared list."
            )
            return
        }
        showListMembership = true
    }
    
    private func openInMaps() {
        guard let location = currentCafe.location else { return }
        
        // Use mapItemURL if available, otherwise construct Maps URL from coordinates
        if let mapURLString = currentCafe.mapItemURL, let url = URL(string: mapURLString) {
            UIApplication.shared.open(url)
        } else {
            // Fallback: open Maps with coordinates
            let urlString = "http://maps.apple.com/?ll=\(location.latitude),\(location.longitude)&q=\(currentCafe.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func openWebsite(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    @MainActor
    private func loadRemoteVisits() async {
        guard let remoteCafeId = signedInRemoteCafeId,
              let userId = authModel.authenticatedUser?.id else {
            remoteVisits = []
            friendUserIDs = []
            remoteVisitError = nil
            isLoadingRemoteVisits = false
            return
        }

        isLoadingRemoteVisits = true
        remoteVisitError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            async let visitsRequest = service.fetchVisibleCafeVisits(
                cafeId: remoteCafeId,
                currentUserId: userId,
                limit: 20
            )
            async let friendsRequest = SocialDiscoveryService(client: client).connections(kind: "friends")
            let (visits, friends) = try await (visitsRequest, friendsRequest)
            remoteVisits = visits
            friendUserIDs = Set(friends.map(\.userID))
            dataManager.upsertRemoteCafe(
                SupabaseCafeSummary(
                    id: remoteCafeId,
                    name: currentCafe.name,
                    address: currentCafe.address.remoteTrimmedNonEmpty,
                    city: nil,
                    latitude: currentCafe.location?.latitude,
                    longitude: currentCafe.location?.longitude,
                    applePlaceId: currentCafe.mapItemURL,
                    websiteURL: currentCafe.websiteURL
                ),
                averageRating: visits.isEmpty ? nil : RemoteCafeVisitStats.calculate(from: visits).averageScore,
                visitCount: visits.isEmpty ? nil : visits.count
            )
            isLoadingRemoteVisits = false
        } catch {
            guard !Task.isCancelled else { return }
            remoteVisitError = MugshotUserFacingError.message(for: error, context: .loading)
            isLoadingRemoteVisits = false
        }
    }

    @MainActor
    private func loadCafeExperienceSummary() async {
        guard let remoteCafeID = signedInRemoteCafeId else {
            cafeExperienceSummary = nil
            cafeExperienceSummaryError = nil
            isLoadingCafeExperienceSummary = false
            return
        }

        if cafeExperienceSummary?.cafeID != remoteCafeID {
            cafeExperienceSummary = nil
        }
        cafeExperienceSummaryError = nil
        isLoadingCafeExperienceSummary = true

        do {
            let client = try SupabaseClientProvider.shared.client()
            let summary = try await CafeSessionService(client: client).fetchCafeSummary(
                cafeID: remoteCafeID,
                scope: .personal
            )
            guard !Task.isCancelled else { return }
            cafeExperienceSummary = summary
            isLoadingCafeExperienceSummary = false
        } catch {
            guard !Task.isCancelled else { return }
            cafeExperienceSummaryError = "Cafe relationship could not refresh."
            isLoadingCafeExperienceSummary = false
        }
    }

    private func toggleFavorite() {
        updateCafeState(
            isFavorite: !currentCafe.isFavorite,
            wantToTry: currentCafe.wantToTry
        )
    }

    private func toggleWantToTry() {
        updateCafeState(
            isFavorite: currentCafe.isFavorite,
            wantToTry: !currentCafe.wantToTry
        )
    }

    private func updateCafeState(isFavorite: Bool, wantToTry: Bool) {
        let previousCafe = currentCafe
        dataManager.setCafeState(
            cafeId: previousCafe.id,
            isFavorite: isFavorite,
            wantToTry: wantToTry
        )
        if previousCafe.isFavorite != isFavorite {
            MugshotAnalytics.shared.capture(
                .cafeStateChanged(
                    state: .favorite,
                    action: isFavorite ? .added : .removed,
                    surface: .saved
                )
            )
        }
        if previousCafe.wantToTry != wantToTry {
            MugshotAnalytics.shared.capture(
                .cafeStateChanged(
                    state: .wantToTry,
                    action: wantToTry ? .added : .removed,
                    surface: .saved
                )
            )
        }

#if DEBUG
        if MugshotLaunchEnvironment.savedAuditScenario == .saveFailure {
            isSyncingCafeState = true
            cafeStateError = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                dataManager.setCafeState(
                    cafeId: previousCafe.id,
                    isFavorite: previousCafe.isFavorite,
                    wantToTry: previousCafe.wantToTry
                )
                cafeStateError = "Could not save cafe state."
                isSyncingCafeState = false
            }
            return
        }
#endif

        guard let userId = authModel.authenticatedUser?.id else {
            return
        }

        isSyncingCafeState = true
        cafeStateError = nil
        Task {
            await saveRemoteCafeState(
                previousCafe: previousCafe,
                isFavorite: isFavorite,
                wantToTry: wantToTry,
                userId: userId
            )
        }
    }

    @MainActor
    private func saveRemoteCafeState(
        previousCafe: Cafe,
        isFavorite: Bool,
        wantToTry: Bool,
        userId: UUID
    ) async {
        isSyncingCafeState = true
        cafeStateError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = CafeStateService(client: client)
            let summary = try await service.setCafeState(
                userId: userId,
                cafe: previousCafe,
                isFavorite: isFavorite,
                wantToTry: wantToTry
            )
            dataManager.applyRemoteCafeState(summary)
            isSyncingCafeState = false
        } catch {
            dataManager.setCafeState(
                cafeId: previousCafe.id,
                isFavorite: previousCafe.isFavorite,
                wantToTry: previousCafe.wantToTry
            )
            cafeStateError = "Could not save cafe state."
            isSyncingCafeState = false
        }
    }
}

struct RemoteCafeVisitRow: View {
    let visit: RemoteVisitSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RemotePhotoImageView(
                    urlString: visit.visit.posterPhotoURL,
                    placeholderSystemName: "cup.and.saucer.fill"
                )
                .frame(width: 74, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))

                VStack(alignment: .leading, spacing: 6) {
                    Text(visit.visit.drinkDisplayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .lineLimit(1)

                    Text(visit.visit.createdAtDate, style: .date)
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                        .lineLimit(1)

                    if let caption = visit.visit.caption.remoteTrimmedNonEmpty {
                        Text(caption)
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                            .lineLimit(2)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(visit.visit.overallScore > 0 ? String(format: "%.1f", visit.visit.overallScore) : "Unrated")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.espressoBrown)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.mugshotSage.opacity(0.38))
                    .clipShape(Capsule())

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.tertiaryText)
                }
            }
            .padding(12)
            .cardStyle(radius: DesignSystem.Radius.card, shadow: DesignSystem.subtleShadow)
        }
        .buttonStyle(.plain)
    }
}

struct VisitRow: View {
    let visit: Visit
    @ObservedObject var dataManager: DataManager
    @State private var showVisitDetail = false
    
    var body: some View {
        Button(action: {
            showVisitDetail = true
        }) {
            HStack(spacing: 12) {
                // Thumbnail
                PhotoThumbnailView(photoPath: visit.posterImagePath, size: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(visit.date, style: .date)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    
                    Text(visit.journalDrinkName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.mugshotSage)
                        .font(.system(size: 12))
                    Text(String(format: "%.1f", visit.overallScore))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                }
            }
            .padding(12)
            .background(Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .navigationDestination(isPresented: $showVisitDetail) {
            VisitDetailView(
                visit: visit,
                dataManager: dataManager,
                onCafeRequested: { _ in showVisitDetail = false }
            )
        }
    }
}
