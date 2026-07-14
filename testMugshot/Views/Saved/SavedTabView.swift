//
//  SavedTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

struct SavedTabView: View {
    @ObservedObject var dataManager: DataManager
    var onAuthenticationRequired: ((_ title: String, _ message: String) -> Void)? = nil
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var selectedSection: SavedSection = .cafes
    @State private var selectedTab: SavedTab = .favorites
    @State private var sortOption: SortOption = .score
    @State private var activeSheet: SavedSheet?
    @State private var isLoadingRemoteStates = false
    @State private var remoteStateError: String?
    @State private var remoteCafeCoverURLs: [UUID: String] = [:]
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
        case score = "By Score"
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

                if selectedSection == .cafes, authModel.authenticatedUser != nil {
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
                                asset: mugsyAsset(for: selectedTab),
                                title: emptyTitle,
                                message: emptyMessage
                            )
                        } else {
                            ForEach(filteredAndSortedCafes) { cafe in
                                CafeCard(
                                    cafe: cafe,
                                    dataManager: dataManager,
                                    showWantToTryTag: selectedTab == .wantToTry,
                                    communityImageURL: remoteCafeCoverURLs[cafe.remoteCafeId ?? cafe.id],
                                    onLogVisit: {
                                        guard authModel.authenticatedUser != nil else {
                                            onAuthenticationRequired?(
                                                "Keep this sip in your journal",
                                                "Sign in to log this saved cafe. Your guest saves will remain on this device."
                                            )
                                            return
                                        }
                                        activeSheet = .logVisit(cafe)
                                    },
                                    onShowDetails: {
                                        activeSheet = .cafeDetail(cafe)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 116)
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
            case .logVisit(let cafe):
                LogVisitView(dataManager: dataManager, preselectedCafe: cafe)
            case .cafeDetail(let cafe):
                CafeDetailView(
                    cafe: cafe,
                    dataManager: dataManager,
                    onAuthenticationRequired: onAuthenticationRequired
                )
            }
        }
    }

    @ViewBuilder
    private var remoteStateStatus: some View {
        if isLoadingRemoteStates {
            HStack(spacing: 8) {
                ProgressView().tint(.mugshotSage)
                Text("Refreshing saved cafes…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondaryText)
            }
        } else if let remoteStateError {
            MugshotRecoveryCard(
                title: "Couldn’t refresh saved cafes",
                message: remoteStateError,
                actionTitle: "Retry"
            ) {
                Task { await loadRemoteCafeStates() }
            }
        }
    }

    @MainActor
    private func loadRemoteCafeStates() async {
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

    private func mugsyAsset(for tab: SavedTab) -> MugsyEmptyStateAsset {
        switch tab {
        case .favorites:
            return .noFavorites
        case .wantToTry:
            return .noWishlist
        case .allCafes:
            return .noCafes
        }
    }
}

struct SavedEmptyStateView: View {
    let asset: MugsyEmptyStateAsset
    let title: String
    let message: String

    var body: some View {
        MugsyEmptyStateView(asset: asset, title: title, message: message)
    }
}

enum SavedSheet: Identifiable {
    case logVisit(Cafe)
    case cafeDetail(Cafe)

    var id: String {
        switch self {
        case .logVisit(let cafe):
            return "log-\(cafe.id.uuidString)"
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
                                "\(displayedVisitCount) \(displayedVisitCount == 1 ? "visit" : "visits")",
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
                "\(cafe.consumerDisplayName), \(cafe.consumerScoreLabel), \(displayedVisitCount) visits"
            )
            .accessibilityHint("Opens cafe details")

            Divider()
                .padding(.horizontal, 12)

            Button(action: onLogVisit) {
                Label("Log a visit", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.espressoBrown)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityHint("Opens a new visit with this cafe selected")
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
                VStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.espressoBrown.opacity(0.34))

                    Text("Cafe")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.espressoBrown.opacity(0.52))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.sandBeige.opacity(0.66))
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
    var onAuthenticationRequired: ((_ title: String, _ message: String) -> Void)? = nil
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) var dismiss
    @State private var showLogVisit = false
    @State private var isSyncingCafeState = false
    @State private var cafeStateError: String?
    @State private var remoteVisits: [RemoteVisitSummary] = []
    @State private var isLoadingRemoteVisits = false
    @State private var remoteVisitError: String?
    @State private var selectedRemoteVisit: RemoteVisitSummary?
    @State private var friendUserIDs: Set<UUID> = []

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

    private var displayedAverageRating: Double {
        guard shouldShowRemoteVisits else {
            return currentCafe.averageRating
        }

        let stats = RemoteCafeVisitStats.calculate(from: remoteVisits)
        return stats.visitCount == 0 ? currentCafe.averageRating : stats.averageScore
    }

    private var displayedVisitCount: Int {
        guard shouldShowRemoteVisits else {
            return currentCafe.visitCount
        }

        let stats = RemoteCafeVisitStats.calculate(from: remoteVisits)
        return stats.visitCount == 0 ? max(currentCafe.visitCount, visits.count) : stats.visitCount
    }
    
    var visits: [Visit] {
        dataManager.getVisitsForCafe(currentCafe.id)
    }
    
    // Get hero image from most recent visit, or nil if no visits/photos
    var heroImagePath: String? {
        if shouldShowRemoteVisits,
           let remotePosterURL = remoteVisits.first?.visit.posterPhotoURL?.remoteTrimmedNonEmpty {
            return remotePosterURL
        }

        let sortedVisits = visits.sorted { $0.createdAt > $1.createdAt }
        return sortedVisits.first?.posterImagePath
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero image - user photos > placeholder
                    if let imagePath = heroImagePath {
                        if imagePath.hasPrefix("http") {
                            RemotePhotoImageView(
                                urlString: imagePath,
                                placeholderSystemName: "photo",
                                contentMode: .fit
                            )
                                .frame(maxWidth: .infinity)
                                .frame(height: 250)
                                .background(Color.sandBeige.opacity(0.7))
                                .clipped()
                        } else {
                            PhotoImageView(photoPath: imagePath, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .frame(height: 250)
                                .background(Color.sandBeige.opacity(0.7))
                                .clipped()
                        }
                    } else {
                        Rectangle()
                            .fill(Color.sandBeige.opacity(0.7))
                            .frame(height: 250)
                            .overlay(
                                VStack(spacing: 10) {
                                    Image(systemName: "cup.and.saucer.fill")
                                        .font(.system(size: 44, weight: .semibold))
                                    Text("No cafe photo yet")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.roastBrown.opacity(0.46))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        cafeSummarySection
                            .padding(.horizontal)
                        .padding(.top, 20)
                        
                        detailStatsSection
                            .padding(.horizontal)

                        if shouldShowRemoteVisits && !remoteVisits.isEmpty {
                            communityHighlightsSection
                                .padding(.horizontal)
                        }

                        detailActionsSection
                            .padding(.horizontal)
                        
                        recentVisitsSection
                    }
                    .padding(.bottom, 20)
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
                }
            }
            .sheet(isPresented: $showLogVisit) {
                LogVisitView(dataManager: dataManager, preselectedCafe: currentCafe)
            }
            .fullScreenCover(item: $selectedRemoteVisit, onDismiss: {
                Task { await loadRemoteVisits() }
            }) { visit in
                RemoteVisitDetailView(
                    visitId: visit.id,
                    initialSummary: visit,
                    currentUserId: authModel.authenticatedUser?.id,
                    dataManager: dataManager
                )
            }
            .task(id: remoteVisitTaskID) {
                await loadRemoteVisits()
            }
        }
    }

    private var remoteVisitTaskID: String {
        [
            authModel.authenticatedUser?.id.uuidString ?? "signed-out",
            currentCafe.remoteCafeId?.uuidString ?? "local"
        ].joined(separator: "-")
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
        HStack(spacing: 10) {
            detailStatCard(
                title: "Average",
                value: String(format: "%.1f", displayedAverageRating),
                systemImage: "star.fill"
            )

            detailStatCard(
                title: "Visits",
                value: "\(displayedVisitCount)",
                systemImage: "cup.and.saucer.fill"
            )
        }
    }

    private var detailActionsSection: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return VStack(spacing: 12) {
            Button {
                guard authModel.authenticatedUser != nil else {
                    onAuthenticationRequired?(
                        "Keep this sip in your journal",
                        "Sign in to log this cafe. You can still favorite it or save it to try while browsing as a guest."
                    )
                    return
                }
                showLogVisit = true
            } label: {
                Label("Log Visit", systemImage: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            LazyVGrid(columns: columns, spacing: 10) {
                detailActionButton(
                    title: "Favorite",
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
                    title: "Directions",
                    systemImage: "location.north.circle",
                    isSelected: false,
                    action: openInMaps
                )

                if let websiteURL = currentCafe.websiteURL, !websiteURL.isEmpty {
                    detailActionButton(
                        title: "Website",
                        systemImage: "safari",
                        isSelected: false
                    ) {
                        openWebsite(urlString: websiteURL)
                    }
                }
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
        let friendVisits = Set(remoteVisits.filter { friendUserIDs.contains($0.visit.userId) }.map(\.visit.userId)).count

        return VStack(alignment: .leading, spacing: 10) {
            MugshotSectionTitle(
                title: "Community favorites",
                subtitle: friendVisits == 0 ? "Top drinks from visible sips" : "\(friendVisits) friends have shared sips here"
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
        for visit in remoteVisits {
            counts[visit.visit.drinkDisplayName, default: 0] += 1
        }
        return counts
            .map { CommunityDrinkCount(name: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }
    }

    private func detailStatCard(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.58))

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.espressoBrown)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.sandBeige.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
    }

    private func detailActionButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.espressoBrown)
                .lineLimit(1)
                .minimumScaleFactor(0.84)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? Color.mugshotSage.opacity(0.34) : Color.sandBeige.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                        .stroke(isSelected ? Color.mugshotSage : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
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
            Text("Recent Visits")
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
                Text("Recent Visits")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.espressoBrown)

                Spacer()

                if isLoadingRemoteVisits {
                    ProgressView()
                    .tint(.mugshotSage)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if let remoteVisitError {
                Text(remoteVisitError)
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            } else if remoteVisits.isEmpty && !isLoadingRemoteVisits {
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
                ForEach(remoteVisits.prefix(5)) { visit in
                    RemoteCafeVisitRow(visit: visit) {
                        selectedRemoteVisit = visit
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top, 8)
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

        guard let userId = authModel.authenticatedUser?.id else {
            return
        }

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
        .fullScreenCover(isPresented: $showVisitDetail) {
            VisitDetailView(visit: visit, dataManager: dataManager)
        }
    }
}
