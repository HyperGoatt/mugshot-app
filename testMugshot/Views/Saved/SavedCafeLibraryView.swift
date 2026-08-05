import SwiftUI

struct SavedTabView: View {
    @ObservedObject var dataManager: DataManager
    var onLogVisitRequested: ((Cafe) -> Void)? = nil
    var onAuthenticationRequired: ((_ title: String, _ message: String) -> Void)? = nil

    @EnvironmentObject private var authModel: AppAuthModel
    @EnvironmentObject private var tabCoordinator: TabCoordinator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var mutationCoordinator = CafeStateMutationCoordinator()

    @State private var selectedSection: SavedLibrarySection = .cafes
    @State private var selectedCategory: SavedCafeCategory = .favorites
    @State private var searchText = ""
    @State private var activeSheet: SavedLibrarySheet?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var lastRefresh: Date?
    @State private var coverURLs: [UUID: String] = [:]
    @State private var pendingRows: [UUID: Cafe] = [:]
    @State private var feedback: SavedLibraryFeedback?
    @State private var feedbackTask: Task<Void, Never>?
#if DEBUG
    @State private var auditRetrySucceeded = false
#endif

    @AppStorage("saved.library.sort") private var sortRaw = SavedCafeSort.recentActivity.rawValue
    @AppStorage("saved.library.density") private var densityRaw = SavedCafeDensity.cards.rawValue
    @AppStorage("saved.library.filter.visited") private var requiresVisit = false
    @AppStorage("saved.library.filter.directions") private var requiresDirections = false
    @AppStorage(RoadmapFeatureFlags.phase4LightweightFriends) private var phase4LightweightFriends = true

    private var sort: SavedCafeSort {
        get { SavedCafeSort(rawValue: sortRaw) ?? .recentActivity }
        nonmutating set { sortRaw = newValue.rawValue }
    }

    private var density: SavedCafeDensity {
        get { SavedCafeDensity(rawValue: densityRaw) ?? .cards }
        nonmutating set { densityRaw = newValue.rawValue }
    }

    private var query: SavedCafeLibraryQuery {
        SavedCafeLibraryQuery(
            category: selectedCategory,
            searchText: searchText,
            sort: sort,
            requiresVisit: requiresVisit,
            requiresDirections: requiresDirections
        )
    }

    private var projectedCafes: [Cafe] {
        let projected = SavedCafeLibraryProjector.project(
            cafes: dataManager.personalLibraryCafes,
            visits: dataManager.appData.visits,
            query: query
        )
        let visibleIDs = Set(projected.map(\.id))
        let retained = pendingRows.values.filter { !visibleIDs.contains($0.id) && matchesSearchAndFilters($0) }
        return SavedCafeLibraryProjector.project(
            cafes: projected + retained,
            visits: dataManager.appData.visits,
            query: SavedCafeLibraryQuery(
                category: .all,
                searchText: searchText,
                sort: sort,
                requiresVisit: requiresVisit,
                requiresDirections: requiresDirections
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MugshotScreenHeader("Saved", subtitle: selectedSection == .cafes ? "Your personal cafe library" : "Plan places together")

                if showsSectionPicker {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            accessibilitySelectionMenu(
                                selection: sectionSelection,
                                options: SavedLibrarySection.allCases,
                                title: "Saved section",
                                label: { $0.rawValue }
                            )
                        } else {
                            MugshotSegmentedControl(
                                options: SavedLibrarySection.allCases,
                                selection: sectionSelection,
                                title: { $0.rawValue }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .accessibilityIdentifier("saved.section")
                }

                if selectedSection == .cafes {
                    cafeLibrary
                } else if let currentUserID = authModel.authenticatedUser?.id {
                    ScrollView {
                        SharedCafeListsView(dataManager: dataManager, currentUserID: currentUserID)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 116)
                    }
                }
            }
            .background(Color.creamWhite)
            .toolbar(.hidden, for: .navigationBar)
            .task(id: "\(authModel.authenticatedUser?.id.uuidString ?? "guest")-\(dataManager.journalRevision)") {
                if authModel.authenticatedUser == nil { selectedSection = .cafes }
                await refreshLibrary()
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .detail(let cafe):
                CafeDetailView(
                    cafe: cafe,
                    dataManager: dataManager,
                    initialDetent: .medium,
                    onLogVisitRequested: onLogVisitRequested,
                    onAuthenticationRequired: onAuthenticationRequired
                )
                .environment(\.dynamicTypeSize, dynamicTypeSize)
            case .filters:
                SavedCafeFilterSheet(
                    requiresVisit: $requiresVisit,
                    requiresDirections: $requiresDirections
                )
                .presentationDetents([.height(dynamicTypeSize.isAccessibilitySize ? 430 : 330)])
                .presentationDragIndicator(.visible)
            case .lists(let cafe):
                CafeListMembershipSheet(
                    cafe: cafe,
                    dataManager: dataManager,
                    onAuthenticationRequired: onAuthenticationRequired
                )
            }
        }
        .overlay(alignment: .bottom) {
            if let feedback {
                SavedLibraryFeedbackBar(feedback: feedback, onUndo: undoFeedback)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 102)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
            }
        }
    }

    private var showsSectionPicker: Bool {
        guard phase4LightweightFriends else { return false }
        if authModel.authenticatedUser != nil { return true }
#if DEBUG
        return MugshotLaunchEnvironment.savedAuditScenario != nil
#else
        return false
#endif
    }

    private var sectionSelection: Binding<SavedLibrarySection> {
        Binding(
            get: { selectedSection },
            set: { section in
#if DEBUG
                if MugshotLaunchEnvironment.savedAuditScenario != nil,
                   authModel.authenticatedUser == nil,
                   section == .lists {
                    return
                }
#endif
                selectedSection = section
            }
        )
    }

    private var cafeLibrary: some View {
        VStack(spacing: 0) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibilitySelectionMenu(
                        selection: $selectedCategory,
                        options: SavedCafeCategory.allCases,
                        title: "Cafe category",
                        label: { $0.rawValue }
                    )
                    .accessibilityIdentifier("saved.category.menu")
                } else {
                    MugshotSegmentedControl(
                        options: SavedCafeCategory.allCases,
                        selection: $selectedCategory,
                        title: { $0.rawValue },
                        accessibilityIdentifier: { "saved.category.\($0.id)" },
                        selectedColor: Color.mugshotMint.opacity(0.34)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            searchAndFilter
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            libraryControls
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            if let displayedLoadError {
                InlineSavedLibraryStatus(
                    systemImage: "wifi.exclamationmark",
                    message: cachedStatusMessage(error: displayedLoadError),
                    actionTitle: "Retry"
                ) {
                    retryRefresh()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            } else if displayedIsLoading, !projectedCafes.isEmpty {
                InlineSavedLibraryStatus(
                    systemImage: "arrow.triangle.2.circlepath",
                    message: "Refreshing your cafe library…"
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    if displayedIsLoading, projectedCafes.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in
                            SavedCafeCardPlaceholder(density: density)
                        }
                    } else if projectedCafes.isEmpty {
                        emptyState
                    } else {
                        ForEach(projectedCafes) { cafe in
                            if density == .cards || dynamicTypeSize.isAccessibilitySize {
                                SavedCafeComfortableCard(
                                    cafe: currentCafe(cafe),
                                    dataManager: dataManager,
                                    communityImageURL: coverURLs[cafe.remoteCafeId ?? cafe.id],
                                    isSyncing: mutationCoordinator.isSyncing(cafe.id),
                                    onOpen: { activeSheet = .detail(cafe) },
                                    onFavorite: { toggleFavorite(cafe) },
                                    onWantToTry: { toggleWantToTry(cafe) },
                                    onLogSip: { onLogVisitRequested?(cafe) },
                                    onLists: { presentLists(for: cafe) },
                                    onShowMap: { showOnMap(cafe) }
                                )
                            } else {
                                SavedCafeCompactRow(
                                    cafe: currentCafe(cafe),
                                    dataManager: dataManager,
                                    communityImageURL: coverURLs[cafe.remoteCafeId ?? cafe.id],
                                    isSyncing: mutationCoordinator.isSyncing(cafe.id),
                                    onOpen: { activeSheet = .detail(cafe) },
                                    onFavorite: { toggleFavorite(cafe) },
                                    onWantToTry: { toggleWantToTry(cafe) },
                                    onLogSip: { onLogVisitRequested?(cafe) },
                                    onLists: { presentLists(for: cafe) },
                                    onShowMap: { showOnMap(cafe) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 120)
            }
            .refreshable { await refreshLibrary() }
        }
    }

    private var searchAndFilter: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.roastBrown)
                    .accessibilityHidden(true)
                TextField(dynamicTypeSize.isAccessibilitySize ? "Search" : "Search your cafes", text: $searchText)
                    .font(dynamicTypeSize.isAccessibilitySize ? .system(size: 22) : .body)
                    .foregroundColor(.inputText)
                    .submitLabel(.search)
                    .accessibilityIdentifier("saved.search")
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.tertiaryText)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.leading, 14)
            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 64 : 52)
            .background(Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.control).stroke(Color.mugshotLine))

            Button {
                activeSheet = .filters
            } label: {
                Image(systemName: activeFilterCount == 0 ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? 64 : 52, height: dynamicTypeSize.isAccessibilitySize ? 64 : 52)
                    .background(Color.foamWhite)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.control).stroke(activeFilterCount > 0 ? Color.mugshotSageText : Color.mugshotLine, lineWidth: activeFilterCount > 0 ? 1.5 : 1))
            }
            .accessibilityLabel("Cafe filters")
            .accessibilityValue(activeFilterCount == 0 ? "No filters applied" : "\(activeFilterCount) applied")
        }
    }

    private var libraryControls: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    sortMenu(accessibilityLayout: true)

                    Text("\(projectedCafes.count) \(projectedCafes.count == 1 ? "cafe" : "cafes")")
                        .font(.system(size: 20))
                        .foregroundColor(.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .accessibilityLabel("\(projectedCafes.count) cafes shown")

                    densityMenu(accessibilityLayout: true)
                }
            } else {
                HStack(spacing: 8) {
                    sortMenu(accessibilityLayout: false)

                    Spacer(minLength: 4)

                    Text("\(projectedCafes.count) \(projectedCafes.count == 1 ? "cafe" : "cafes")")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .accessibilityLabel("\(projectedCafes.count) cafes shown")

                    Spacer(minLength: 4)

                    densityMenu(accessibilityLayout: false)
                }
            }
        }
    }

    private func sortMenu(accessibilityLayout: Bool) -> some View {
        Menu {
            Picker("Sort cafes", selection: Binding(get: { sort }, set: { sort = $0 })) {
                ForEach(SavedCafeSort.allCases) { option in
                    Label(option.rawValue, systemImage: option.systemImage).tag(option)
                }
            }
        } label: {
            Label(sort.rawValue, systemImage: sort.systemImage)
                .font(accessibilityLayout ? .system(size: 20, weight: .semibold) : .subheadline.weight(.semibold))
                .foregroundColor(.mugshotSageText)
                .frame(maxWidth: accessibilityLayout ? .infinity : nil, minHeight: accessibilityLayout ? 52 : 44, alignment: .leading)
        }
        .accessibilityLabel("Sort cafes")
        .accessibilityValue(sort.rawValue)
    }

    private func densityMenu(accessibilityLayout: Bool) -> some View {
        Menu {
            Picker("Cafe density", selection: Binding(get: { density }, set: { density = $0 })) {
                ForEach(SavedCafeDensity.allCases) { option in
                    Label(option.rawValue, systemImage: option.systemImage).tag(option)
                }
            }
        } label: {
            Label(density.rawValue, systemImage: density.systemImage)
                .font(accessibilityLayout ? .system(size: 20, weight: .semibold) : .subheadline.weight(.semibold))
                .foregroundColor(.mugshotSageText)
                .frame(maxWidth: accessibilityLayout ? .infinity : nil, minHeight: accessibilityLayout ? 52 : 44, alignment: .leading)
        }
    }

    private func accessibilitySelectionMenu<Option: Hashable>(
        selection: Binding<Option>,
        options: [Option],
        title: String,
        label: @escaping (Option) -> String
    ) -> some View {
        Menu {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(label(selection.wrappedValue))
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.espressoBrown)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Color.sandBeige.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityLabel(title)
        .accessibilityValue(label(selection.wrappedValue))
    }

    private var emptyState: some View {
        let hasQuery = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasFilters = activeFilterCount > 0
        return VStack(spacing: 14) {
            MugsyModelView(configuration: MugsyModelConfiguration(
                expression: .curious,
                prop: selectedCategory == .wantToTry ? .wishlistBadge : .guidebookAndPen,
                outfit: .cafeScout
            ))
            .frame(width: 132, height: 132)

            Text(hasQuery || hasFilters ? "No cafes match" : emptyTitle)
                .mugshotDisplay(size: 24)
                .foregroundColor(.espressoBrown)
            Text(hasQuery || hasFilters ? "Try clearing your search or filters." : emptyMessage)
                .font(.body)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if hasQuery || hasFilters {
                Button("Clear search and filters") {
                    searchText = ""
                    requiresVisit = false
                    requiresDirections = false
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 42)
    }

    private var emptyTitle: String {
        switch selectedCategory {
        case .favorites: "No favorites yet"
        case .wantToTry: "Nothing waiting to be tried"
        case .all: "Your cafe library is ready"
        }
    }

    private var emptyMessage: String {
        switch selectedCategory {
        case .favorites: "Favorite a cafe from Saved, Map, or cafe details and it will stay close."
        case .wantToTry: "Save a cafe you want to try and it will wait here until your first completed sip."
        case .all: "Favorite a cafe, mark it Want to Try, or log a sip to add it here."
        }
    }

    private var activeFilterCount: Int {
        (requiresVisit ? 1 : 0) + (requiresDirections ? 1 : 0)
    }

    private var displayedIsLoading: Bool {
#if DEBUG
        if let scenario = MugshotLaunchEnvironment.savedAuditScenario,
           !auditRetrySucceeded,
           scenario.isForcedLoading {
            return true
        }
#endif
        return isLoading
    }

    private var displayedLoadError: String? {
#if DEBUG
        if let scenario = MugshotLaunchEnvironment.savedAuditScenario,
           !auditRetrySucceeded,
           let message = scenario.forcedSavedErrorMessage {
            return message
        }
#endif
        return loadError
    }

    private func retryRefresh() {
#if DEBUG
        if MugshotLaunchEnvironment.savedAuditScenario != nil {
            auditRetrySucceeded = true
            return
        }
#endif
        Task { await refreshLibrary() }
    }

    private func currentCafe(_ cafe: Cafe) -> Cafe {
        dataManager.getCafe(id: cafe.id) ?? cafe
    }

    private func matchesSearchAndFilters(_ cafe: Cafe) -> Bool {
        !SavedCafeLibraryProjector.project(
            cafes: [cafe],
            visits: dataManager.appData.visits,
            query: SavedCafeLibraryQuery(
                category: .all,
                searchText: searchText,
                sort: sort,
                requiresVisit: requiresVisit,
                requiresDirections: requiresDirections
            )
        ).isEmpty
    }

    private func toggleFavorite(_ cafe: Cafe) {
        let current = currentCafe(cafe)
        updateCafeState(current, isFavorite: !current.isFavorite, wantToTry: current.wantToTry, changedState: .favorite)
    }

    private func toggleWantToTry(_ cafe: Cafe) {
        let current = currentCafe(cafe)
        updateCafeState(current, isFavorite: current.isFavorite, wantToTry: !current.wantToTry, changedState: .wantToTry)
    }

    private func updateCafeState(
        _ cafe: Cafe,
        isFavorite: Bool,
        wantToTry: Bool,
        changedState: SavedCafeChangedState
    ) {
        let isRemovingFromActiveCategory =
            (selectedCategory == .favorites && changedState == .favorite && !isFavorite)
            || (selectedCategory == .wantToTry && changedState == .wantToTry && !wantToTry)

        if isRemovingFromActiveCategory {
            pendingRows[cafe.id] = cafe
            showFeedback(SavedLibraryFeedback(
                message: changedState == .favorite ? "Removed from Favorites" : "Removed from Want to Try",
                cafe: cafe,
                restoresFavorite: cafe.isFavorite,
                restoresWantToTry: cafe.wantToTry
            ))
        } else {
            showFeedback(SavedLibraryFeedback(
                message: changedState == .favorite
                    ? (isFavorite ? "Added to Favorites" : "Removed from Favorites")
                    : (wantToTry ? "Added to Want to Try" : "Removed from Want to Try"),
                cafe: cafe,
                restoresFavorite: cafe.isFavorite,
                restoresWantToTry: cafe.wantToTry
            ))
        }

        mutationCoordinator.setCafeState(
            cafe: cafe,
            isFavorite: isFavorite,
            wantToTry: wantToTry,
            dataManager: dataManager,
            userID: authModel.authenticatedUser?.id,
            analyticsSurface: .saved
        ) { error in
            guard let error else { return }
            pendingRows.removeValue(forKey: cafe.id)
            showFeedback(SavedLibraryFeedback(message: error, cafe: nil, restoresFavorite: nil, restoresWantToTry: nil))
        }
    }

    private func showFeedback(_ value: SavedLibraryFeedback) {
        feedbackTask?.cancel()
        withAnimation(DesignSystem.Motion.base) { feedback = value }
        feedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(DesignSystem.Motion.base) {
                feedback = nil
                if let cafeID = value.cafe?.id { pendingRows.removeValue(forKey: cafeID) }
            }
        }
    }

    private func undoFeedback() {
        guard let feedback,
              let cafe = feedback.cafe,
              let favorite = feedback.restoresFavorite,
              let wantToTry = feedback.restoresWantToTry else { return }
        feedbackTask?.cancel()
        pendingRows.removeValue(forKey: cafe.id)
        mutationCoordinator.setCafeState(
            cafe: currentCafe(cafe),
            isFavorite: favorite,
            wantToTry: wantToTry,
            dataManager: dataManager,
            userID: authModel.authenticatedUser?.id,
            analyticsSurface: .saved
        ) { _ in }
        withAnimation(DesignSystem.Motion.base) { self.feedback = nil }
    }

    private func presentLists(for cafe: Cafe) {
        guard authModel.authenticatedUser != nil else {
            onAuthenticationRequired?(
                "Keep cafe lists in sync",
                "Sign in to add this cafe to a private or shared list."
            )
            return
        }
        activeSheet = .lists(cafe)
    }

    private func showOnMap(_ cafe: Cafe) {
        guard cafe.location != nil else {
            showFeedback(SavedLibraryFeedback(
                message: "This cafe does not have a map location yet.",
                cafe: nil,
                restoresFavorite: nil,
                restoresWantToTry: nil
            ))
            return
        }
        tabCoordinator.showCafeOnMap(currentCafe(cafe))
    }

    private func cachedStatusMessage(error: String) -> String {
        guard let lastRefresh else { return error }
        return "Showing saved data from \(lastRefresh.formatted(.relative(presentation: .named))). \(error)"
    }

    @MainActor
    private func refreshLibrary() async {
#if DEBUG
        if MugshotLaunchEnvironment.savedAuditScenario != nil {
            isLoading = false
            loadError = nil
            return
        }
#endif
        guard let userID = authModel.authenticatedUser?.id else {
            isLoading = false
            loadError = nil
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try SupabaseClientProvider.shared.client()
            async let snapshotRequest = MapPinService(
                visitService: VisitService(client: client),
                cafeStateService: CafeStateService(client: client),
                cafeSessionService: CafeSessionService(client: client)
            ).fetchSnapshot(userId: userID)
            async let coversRequest = try? SocialDiscoveryService(client: client).discovery(
                section: .saved,
                location: nil,
                radiusKM: 100,
                limit: 100
            )
            let (snapshot, coverRows) = try await (snapshotRequest, coversRequest)
            guard !Task.isCancelled else { return }
            dataManager.applyPersonalMapSnapshot(snapshot)
            coverURLs = Dictionary(uniqueKeysWithValues: (coverRows ?? []).compactMap { row in
                guard let url = row.recentCover?.remoteTrimmedNonEmpty else { return nil }
                return (row.id, url)
            })
            lastRefresh = .now
            loadError = nil
        } catch is CancellationError {
            return
        } catch {
            loadError = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }
}

private enum SavedLibrarySection: String, CaseIterable {
    case cafes = "Cafes"
    case lists = "Lists"
}

private enum SavedLibrarySheet: Identifiable {
    case detail(Cafe)
    case filters
    case lists(Cafe)

    var id: String {
        switch self {
        case .detail(let cafe): "detail-\(cafe.id)"
        case .filters: "filters"
        case .lists(let cafe): "lists-\(cafe.id)"
        }
    }
}

private enum SavedCafeChangedState { case favorite, wantToTry }

private struct SavedLibraryFeedback: Identifiable {
    let id = UUID()
    let message: String
    let cafe: Cafe?
    let restoresFavorite: Bool?
    let restoresWantToTry: Bool?
}

private struct SavedLibraryFeedbackBar: View {
    let feedback: SavedLibraryFeedback
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.mugshotSageText)
            Text(feedback.message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.espressoBrown)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if feedback.cafe != nil {
                Button("Undo", action: onUndo)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.mugshotSageText)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.control).stroke(Color.mugshotLine))
        .shadow(color: DesignSystem.cardShadow.color, radius: 18, y: 6)
        .accessibilityElement(children: .contain)
    }
}

private struct SavedCafeFilterSheet: View {
    @Binding var requiresVisit: Bool
    @Binding var requiresDirections: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Cafe history") {
                    Toggle("Only cafes with a sip", isOn: $requiresVisit)
                }
                Section("Location") {
                    Toggle("Only cafes with directions", isOn: $requiresDirections)
                }
                if requiresVisit || requiresDirections {
                    Section {
                        Button("Clear filters") {
                            requiresVisit = false
                            requiresDirections = false
                        }
                        .foregroundColor(.mugshotSageText)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("Filter cafes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct InlineSavedLibraryStatus: View {
    let systemImage: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundColor(.mugshotSageText)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.mugshotSageText)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 12)
        .background(Color.sandBeige.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
final class CafeStateMutationCoordinator: ObservableObject {
    @Published private var syncingCafeIDs: Set<UUID> = []
    private var generationByCafeID: [UUID: Int] = [:]
    private var tailTasks: [UUID: Task<Void, Never>] = [:]

    func isSyncing(_ cafeID: UUID) -> Bool { syncingCafeIDs.contains(cafeID) }

    func setCafeState(
        cafe: Cafe,
        isFavorite: Bool,
        wantToTry: Bool,
        dataManager: DataManager,
        userID: UUID?,
        analyticsSurface: MugshotAnalyticsSurface,
        completion: @escaping (String?) -> Void
    ) {
        let priorFavorite = cafe.isFavorite
        let priorWantToTry = cafe.wantToTry
        let generation = (generationByCafeID[cafe.id] ?? 0) + 1
        generationByCafeID[cafe.id] = generation
        let priorTask = tailTasks[cafe.id]

        dataManager.setCafeState(cafeId: cafe.id, isFavorite: isFavorite, wantToTry: wantToTry)
        syncingCafeIDs.insert(cafe.id)

        if priorFavorite != isFavorite {
            MugshotAnalytics.shared.capture(.cafeStateChanged(
                state: .favorite,
                action: isFavorite ? .added : .removed,
                surface: analyticsSurface
            ))
        }
        if priorWantToTry != wantToTry {
            MugshotAnalytics.shared.capture(.cafeStateChanged(
                state: .wantToTry,
                action: wantToTry ? .added : .removed,
                surface: analyticsSurface
            ))
        }

#if DEBUG
        if MugshotLaunchEnvironment.savedAuditScenario == .saveFailure {
            let task = Task { @MainActor in
                await priorTask?.value
                try? await Task.sleep(for: .milliseconds(450))
                guard generationByCafeID[cafe.id] == generation else { return }
                dataManager.setCafeState(
                    cafeId: cafe.id,
                    isFavorite: priorFavorite,
                    wantToTry: priorWantToTry
                )
                syncingCafeIDs.remove(cafe.id)
                tailTasks[cafe.id] = nil
                completion("Could not update this cafe. Your confirmed state was restored.")
            }
            tailTasks[cafe.id] = task
            return
        }
#endif

        guard let userID else {
            syncingCafeIDs.remove(cafe.id)
            completion(nil)
            return
        }

        let task = Task { @MainActor in
            await priorTask?.value
            do {
                let client = try SupabaseClientProvider.shared.client()
                let summary = try await CafeStateService(client: client).setCafeState(
                    userId: userID,
                    cafe: cafe,
                    isFavorite: isFavorite,
                    wantToTry: wantToTry
                )
                guard generationByCafeID[cafe.id] == generation else { return }
                dataManager.applyRemoteCafeState(summary)
                syncingCafeIDs.remove(cafe.id)
                tailTasks[cafe.id] = nil
                completion(nil)
            } catch is CancellationError {
                return
            } catch {
                guard generationByCafeID[cafe.id] == generation else { return }
                dataManager.setCafeState(
                    cafeId: cafe.id,
                    isFavorite: priorFavorite,
                    wantToTry: priorWantToTry
                )
                syncingCafeIDs.remove(cafe.id)
                tailTasks[cafe.id] = nil
                completion("Could not update this cafe. Your confirmed state was restored.")
            }
        }
        tailTasks[cafe.id] = task
    }
}
