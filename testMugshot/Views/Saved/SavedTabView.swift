//
//  SavedTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

struct SavedTabView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var selectedTab: SavedTab = .favorites
    @State private var sortOption: SortOption = .score
    @State private var activeSheet: SavedSheet?
    @State private var isLoadingRemoteStates = false
    @State private var remoteStateError: String?
    
    enum SavedTab: String, CaseIterable {
        case favorites = "Favorites"
        case wantToTry = "Want to Try"
        case allCafes = "All Cafes"
    }
    
    enum SortOption: String, CaseIterable {
        case score = "By Score"
        case date = "By Date"
        case name = "By Name"
    }

    private var savedSubtitle: String {
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
        NavigationView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Saved")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.espressoBrown)

                    Text(savedSubtitle)
                        .font(.system(size: 15))
                        .foregroundColor(.espressoBrown.opacity(0.68))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

                Picker("Tab", selection: $selectedTab) {
                    ForEach(SavedTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Sort option (only for All Cafes)
                if selectedTab == .allCafes {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                if authModel.authenticatedUser != nil {
                    remoteStateStatus
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }
                
                // Cafe list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if filteredAndSortedCafes.isEmpty {
                            SavedEmptyStateView(
                                systemImage: selectedTab == .wantToTry ? "bookmark.fill" : "heart.fill",
                                title: emptyTitle,
                                message: emptyMessage
                            )
                        } else {
                            ForEach(filteredAndSortedCafes) { cafe in
                                CafeCard(
                                    cafe: cafe,
                                    dataManager: dataManager,
                                    showWantToTryTag: selectedTab == .wantToTry,
                                    onLogVisit: {
                                        activeSheet = .logVisit(cafe)
                                    },
                                    onShowDetails: {
                                        activeSheet = .cafeDetail(cafe)
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color.creamWhite)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task(id: authModel.authenticatedUser?.id) {
                await loadRemoteCafeStates()
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .logVisit(let cafe):
                LogVisitView(dataManager: dataManager, preselectedCafe: cafe)
            case .cafeDetail(let cafe):
                CafeDetailView(cafe: cafe, dataManager: dataManager)
            }
        }
    }

    @ViewBuilder
    private var remoteStateStatus: some View {
        if isLoadingRemoteStates {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.mugshotMint)
                Text("Syncing saved cafes...")
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.65))
                Spacer()
            }
        } else if let remoteStateError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red.opacity(0.75))
                Text(remoteStateError)
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.7))
                    .lineLimit(2)
                Spacer()
            }
        }
    }

    @MainActor
    private func loadRemoteCafeStates() async {
        guard let userId = authModel.authenticatedUser?.id else {
            remoteStateError = nil
            return
        }

        isLoadingRemoteStates = true
        remoteStateError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = CafeStateService(client: client)
            let states = try await service.fetchCafeStates(userId: userId)
            dataManager.applyRemoteCafeStates(states)
            isLoadingRemoteStates = false
        } catch {
            remoteStateError = "Could not sync saved cafes."
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
}

struct SavedEmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.36))
                .frame(width: 56, height: 56)
                .background(Color.sandBeige.opacity(0.5))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.espressoBrown)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.espressoBrown.opacity(0.64))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(Color.creamWhite)
        .cornerRadius(DesignSystem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .stroke(Color.sandBeige, lineWidth: 1)
        )
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
    let onLogVisit: () -> Void
    let onShowDetails: () -> Void
    
    // Get cafe image from most recent visit, or nil if no visits/photos
    var cafeImagePath: String? {
        let visits = dataManager.getVisitsForCafe(cafe.id)
        let sortedVisits = visits.sorted { $0.createdAt > $1.createdAt }
        return sortedVisits.first?.posterImagePath
    }

    private var displayedVisitCount: Int {
        max(cafe.visitCount, dataManager.getVisitsForCafe(cafe.id).count)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                cafeImage

                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(cafe.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.espressoBrown)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 6)

                        scoreBadge
                    }

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
                        cafePill("\(displayedVisitCount) visits", systemImage: "cup.and.saucer.fill")

                        if let category = cafe.placeCategory?.remoteTrimmedNonEmpty {
                            cafePill(category, systemImage: "tag.fill")
                        }
                    }
                }
            }
            .padding(12)

            Divider()
                .padding(.horizontal, 12)

            HStack(spacing: 0) {
                savedCardAction("Directions", systemImage: "location.north.circle") {
                    openInMaps()
                }

                savedActionDivider

                savedCardAction("Log Visit", systemImage: "plus.circle") {
                    onLogVisit()
                }

                savedActionDivider

                if let websiteURL = cafe.websiteURL, !websiteURL.isEmpty {
                    savedCardAction("Website", systemImage: "safari") {
                        openWebsite(urlString: websiteURL)
                    }
                    savedActionDivider
                }

                savedCardAction("Details", systemImage: "chevron.right") {
                    onShowDetails()
                }
            }
            .padding(.vertical, 10)
        }
        .background(Color.creamWhite)
        .cornerRadius(DesignSystem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .stroke(Color.sandBeige, lineWidth: 1)
        )
        .shadow(
            color: DesignSystem.cardShadow.color,
            radius: DesignSystem.cardShadow.radius,
            x: DesignSystem.cardShadow.x,
            y: DesignSystem.cardShadow.y
        )
    }

    @ViewBuilder
    private var cafeImage: some View {
        if let imagePath = cafeImagePath {
            PhotoThumbnailView(photoPath: imagePath, size: 112)
                .frame(width: 112, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.espressoBrown.opacity(0.34))

                Text("Cafe")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.espressoBrown.opacity(0.52))
            }
            .frame(width: 112, height: 132)
            .background(Color.sandBeige.opacity(0.66))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))
        }
    }

    private var scoreBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(String(format: "%.1f", cafe.averageRating))
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(.espressoBrown)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.mugshotMint.opacity(0.38))
        .clipShape(Capsule())
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
        .foregroundColor(.espressoBrown.opacity(0.68))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.sandBeige.opacity(0.42))
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

struct CafeDetailView: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) var dismiss
    @State private var showLogVisit = false
    @State private var isSyncingCafeState = false
    @State private var cafeStateError: String?
    @State private var remoteVisits: [RemoteVisitSummary] = []
    @State private var isLoadingRemoteVisits = false
    @State private var remoteVisitError: String?
    @State private var selectedRemoteVisit: RemoteVisitSummary?

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
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero image - user photos > placeholder
                    if let imagePath = heroImagePath {
                        if imagePath.hasPrefix("http") {
                            RemotePhotoImageView(
                                urlString: imagePath,
                                placeholderSystemName: "photo"
                            )
                                .aspectRatio(16/9, contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 250)
                                .clipped()
                        } else {
                            PhotoImageView(photoPath: imagePath)
                                .aspectRatio(16/9, contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 250)
                                .clipped()
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color.sandBeige)
                            .frame(height: 250)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundColor(.espressoBrown.opacity(0.3))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        cafeSummarySection
                            .padding(.horizontal)
                        .padding(.top, 20)
                        
                        detailStatsSection
                            .padding(.horizontal)

                        detailActionsSection
                            .padding(.horizontal)
                        
                        recentVisitsSection
                    }
                    .padding(.bottom, 20)
                }
            }
            .background(Color.creamWhite)
            .navigationTitle("Café Details")
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
            .sheet(item: $selectedRemoteVisit) { visit in
                RemoteVisitDetailView(
                    visitId: visit.id,
                    initialSummary: visit,
                    currentUserId: authModel.authenticatedUser?.id
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
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.espressoBrown)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !currentCafe.address.isEmpty {
                Label(currentCafe.address, systemImage: "mappin.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.68))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let category = currentCafe.placeCategory?.remoteTrimmedNonEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(category)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundColor(.espressoBrown.opacity(0.62))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.sandBeige.opacity(0.42))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.creamWhite)
        .cornerRadius(DesignSystem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .stroke(Color.sandBeige, lineWidth: 1)
        )
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
        .background(Color.sandBeige.opacity(0.34))
        .cornerRadius(DesignSystem.cornerRadius)
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
                .background(isSelected ? Color.mugshotMint.opacity(0.34) : Color.sandBeige.opacity(0.55))
                .cornerRadius(DesignSystem.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                        .stroke(isSelected ? Color.mugshotMint : Color.clear, lineWidth: 1.5)
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
                        .tint(.mugshotMint)
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
                    Text("No remote visits here yet.")
                        .font(.system(size: 14))
                        .foregroundColor(.espressoBrown.opacity(0.62))
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
            remoteVisitError = nil
            isLoadingRemoteVisits = false
            return
        }

        isLoadingRemoteVisits = true
        remoteVisitError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            let visits = try await service.fetchCafeVisits(
                cafeId: remoteCafeId,
                userId: userId,
                limit: 10
            )
            remoteVisits = visits
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
            remoteVisitError = "Could not load remote visits for this cafe."
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
                        .foregroundColor(.espressoBrown.opacity(0.58))
                        .lineLimit(1)

                    if let caption = visit.visit.caption.remoteTrimmedNonEmpty {
                        Text(caption)
                            .font(.system(size: 12))
                            .foregroundColor(.espressoBrown.opacity(0.68))
                            .lineLimit(2)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(String(format: "%.1f", visit.visit.overallScore))
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.espressoBrown)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.mugshotMint.opacity(0.36))
                    .clipShape(Capsule())

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.espressoBrown.opacity(0.35))
                }
            }
            .padding(12)
            .background(Color.creamWhite)
            .cornerRadius(DesignSystem.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                    .stroke(Color.sandBeige, lineWidth: 1)
            )
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
                    
                    Text(visit.drinkType.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.7))
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.mugshotMint)
                        .font(.system(size: 12))
                    Text(String(format: "%.1f", visit.overallScore))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                }
            }
            .padding()
            .background(Color.sandBeige)
            .cornerRadius(DesignSystem.smallCornerRadius)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showVisitDetail) {
            VisitDetailView(visit: visit, dataManager: dataManager)
        }
    }
}
