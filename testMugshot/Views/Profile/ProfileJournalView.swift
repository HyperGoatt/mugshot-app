import MapKit
import SwiftUI

struct JournalTabView: View {
    @ObservedObject var dataManager: DataManager
    let onComposeDraft: (SipDraft) -> Void
    @EnvironmentObject private var authModel: AppAuthModel
    @EnvironmentObject private var tabCoordinator: TabCoordinator

    @State private var selectedFilter: JournalFilter = .all
    @State private var activeProfileSheet: ProfileSheet?
    @State private var showJournalArchive = false
    @State private var selectedRemoteVisit: RemoteVisitSummary?
    @State private var selectedLocalVisit: Visit?
    @State private var journalEntries: [JournalEntryProjection] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var showAccountMenu = false
    @State private var localDrafts: [SipDraft] = []
    @State private var tasteSignals: [RemoteTasteSignal] = []
    @AppStorage(RoadmapFeatureFlags.phase2CanonicalJournal) private var phase2CanonicalJournal = true
    @AppStorage(RoadmapFeatureFlags.phase3ExplainableTasteGraph) private var phase3ExplainableTasteGraph = true

    fileprivate enum JournalFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case cafe = "Cafe"
        case home = "Home"
        case recipes = "Recipes"

        var id: String { rawValue }
    }

    private enum ProfileSheet: String, Identifiable {
        case editProfile
        case settings

        var id: String { rawValue }
    }

    private var user: User? { dataManager.appData.currentUser }

    private var remoteVisits: [RemoteVisitSummary] {
        journalEntries.map(\.summary)
    }

    private var onThisSipEntries: [JournalEntryProjection] {
        let calendar = Calendar.current
        let now = Date()
        return journalEntries.filter {
            calendar.component(.month, from: $0.date) == calendar.component(.month, from: now)
                && calendar.component(.day, from: $0.date) == calendar.component(.day, from: now)
                && calendar.component(.year, from: $0.date) < calendar.component(.year, from: now)
        }
    }

    private var journalTags: [String] {
        Array(Set(journalEntries.flatMap(\.tags))).sorted()
    }

    private var profileStats: RemoteProfileStats {
        RemoteProfileStats.calculate(from: remoteVisits)
    }

    private var tasteIdentity: TasteIdentitySummary {
        phase3ExplainableTasteGraph
            ? TasteIdentitySummary.calculate(from: tasteSignals)
            : TasteIdentitySummary.calculate(from: remoteVisits)
    }

    private var filteredVisits: [RemoteVisitSummary] {
        remoteVisits
            .filter { visit in
                switch selectedFilter {
                case .all: return true
                case .cafe: return visit.visit.journalContext == .cafe
                case .home: return visit.visit.journalContext == .home
                case .recipes: return visit.visit.journalContext == .recipe
                }
            }
            .sorted { $0.visit.createdAtDate > $1.visit.createdAtDate }
    }

    private var filteredLocalVisits: [Visit] {
        dataManager.appData.visits
            .filter { visit in
                switch selectedFilter {
                case .all: return true
                case .cafe: return visit.context == .cafe
                case .home: return visit.context == .home
                case .recipes: return visit.context == .recipe
                }
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var featuredVisit: RemoteVisitSummary? {
        if selectedFilter == .all,
           let homeEntry = filteredVisits.first(where: { $0.visit.journalContext != .cafe }) {
            return homeEntry
        }
        return filteredVisits.first
    }

    private var supportingVisits: [RemoteVisitSummary] {
        let limit = selectedFilter == .all ? 1 : 3
        return Array(filteredVisits.filter { $0.id != featuredVisit?.id }.prefix(limit))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    MugshotScreenHeader("Journal") {
                        Button {
                            showAccountMenu = true
                        } label: {
                            MugshotAvatar(
                                name: user?.displayNameOrUsername ?? authModel.profile?.displayName ?? "user",
                                size: 42,
                                imageURL: authModel.profile?.avatarURL ?? user?.avatarImageName
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Profile and settings")
                    }

                    Text(profileSummaryLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)

                    if phase2CanonicalJournal, !localDrafts.isEmpty {
                        draftSection
                            .padding(.top, 18)
                    }

                    if phase2CanonicalJournal, let memory = onThisSipEntries.first {
                        onThisSipCard(memory)
                            .padding(.horizontal, 16)
                            .padding(.top, 18)
                    }

                    journalSection
                        .padding(.top, 18)

                    Divider()
                        .overlay(Color.mugshotLine)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 24)

                    TasteIdentityJournalSection(
                        summary: tasteIdentity,
                        signals: phase3ExplainableTasteGraph ? tasteSignals : [],
                        entries: journalEntries,
                        onChange: updateTasteSignal
                    )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 124)
                }
            }
            .background(Color.creamWhite)
            .sheet(item: $activeProfileSheet) { sheet in
                switch sheet {
                case .editProfile:
                    if let profile = authModel.profile {
                        EditProfileView(profile: profile, dataManager: dataManager)
                            .environmentObject(authModel)
                    }
                case .settings:
                    SettingsView(dataManager: dataManager)
                        .environmentObject(authModel)
                }
            }
            .confirmationDialog(
                "Journal account",
                isPresented: $showAccountMenu,
                titleVisibility: .visible
            ) {
                if authModel.profile != nil {
                    Button("Edit Profile") {
                        authModel.clearProfileUpdateError()
                        activeProfileSheet = .editProfile
                    }
                }
                Button("Settings") { activeProfileSheet = .settings }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Profile and durable journal preferences live here.")
            }
            .fullScreenCover(item: $selectedRemoteVisit) { visit in
                RemoteVisitDetailView(
                    visitId: visit.id,
                    initialSummary: visit,
                    currentUserId: authModel.authenticatedUser?.id,
                    dataManager: dataManager,
                    onRepeat: { detail in
                        launchComposer(from: detail.summary)
                    }
                )
            }
            .fullScreenCover(item: $selectedLocalVisit) { visit in
                VisitDetailView(visit: visit, dataManager: dataManager)
            }
            .fullScreenCover(isPresented: $showJournalArchive) {
                JournalArchiveView(
                    entries: journalEntries,
                    currentUserID: authModel.authenticatedUser?.id,
                    dataManager: dataManager,
                    onComposeDraft: onComposeDraft,
                    showsPhase2Tools: phase2CanonicalJournal
                )
            }
            .task(id: "\(authModel.authenticatedUser?.id.uuidString ?? "signed-out")-\(dataManager.journalRevision)") {
                localDrafts = SipDraftStore.shared.allDrafts().sorted { $0.updatedAt > $1.updatedAt }
                await loadJournal()
            }
        }
    }

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Drafts")
                    .mugshotDisplay(size: 24)
                    .foregroundColor(.espressoBrown)
                Spacer()
                Text("\(localDrafts.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.mugshotSage)
            }

            ForEach(localDrafts.prefix(3)) { draft in
                HStack(spacing: 12) {
                    Button {
                        onComposeDraft(draft)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: draft.context.systemImage)
                                .foregroundColor(.mugshotSage)
                                .frame(width: 34, height: 34)
                                .background(Color.mugshotMint.opacity(0.55), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(draft.drinkName.remoteTrimmedNonEmpty ?? "Untitled sip")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.espressoBrown)
                                    .lineLimit(1)
                                Text("Saved \(draft.updatedAt.formatted(.relative(presentation: .named)))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondaryText)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        SipDraftStore.shared.remove(draft)
                        localDrafts.removeAll { $0.id == draft.id }
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Discard \(draft.drinkName.remoteTrimmedNonEmpty ?? "draft")")
                }
                .padding(12)
                .cardStyle()
            }
        }
        .padding(.horizontal, 16)
    }

    private func onThisSipCard(_ entry: JournalEntryProjection) -> some View {
        Button { selectedRemoteVisit = entry.summary } label: {
            HStack(spacing: 14) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.foamWhite)
                    .frame(width: 44, height: 44)
                    .background(Color.mugshotSage, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("On This Sip")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.mugshotSage)
                    Text(entry.summary.visit.drinkDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.tertiaryText)
            }
            .padding(14)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this memory")
    }

    private func launchComposer(from summary: RemoteVisitSummary) {
        selectedRemoteVisit = nil
        let userID = authModel.authenticatedUser?.id
        let draft = summary.visit.journalContext == .recipe
            ? SipDraft.brewAgain(from: summary, ownerUserID: userID)
            : SipDraft.repeatSip(from: summary, ownerUserID: userID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onComposeDraft(draft)
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                MugshotProfileBanner(imageURL: authModel.profile?.bannerURL, height: 142)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous))

                MugshotAvatar(
                    name: user?.displayNameOrUsername ?? authModel.profile?.displayName ?? "user",
                    size: 88,
                    imageURL: authModel.profile?.avatarURL ?? user?.avatarImageName
                )
                .offset(x: 18, y: 42)
            }
            .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(user?.displayNameOrUsername ?? authModel.profile?.displayName ?? "Mugshot User")
                            .mugshotDisplay(size: 28)
                            .foregroundColor(.espressoBrown)
                        Text("@\(user?.username ?? authModel.profile?.username ?? "user")\(profileLocationSuffix)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.tertiaryText)
                    }

                    Spacer()

                    if authModel.profile != nil {
                        Button {
                            authModel.clearProfileUpdateError()
                            activeProfileSheet = .editProfile
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.mugshotSage)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let bio = user?.bio.remoteTrimmedNonEmpty {
                    Text(bio)
                        .font(.system(size: 14))
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    MugshotTagChip(
                        title: profileStats.favoriteDrinkLabel?.lowercased() ?? "taste explorer",
                        icon: "leaf.fill"
                    )
                    if let topCafe = profileStats.topCafes.first?.cafe.consumerDisplayName {
                        MugshotTagChip(title: topCafe, icon: "sparkles")
                    }
                }

                Text(profileSummaryLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 50)
        }
    }

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent sips")
                    .mugshotDisplay(size: 30)
                    .foregroundColor(.espressoBrown)
                Spacer()
                if authModel.authenticatedUser != nil {
                    Button("See all") {
                        showJournalArchive = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            JournalFilterBar(selection: $selectedFilter)
                .padding(.horizontal, 16)

            if phase2CanonicalJournal, !journalTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(journalTags.prefix(12), id: \.self) { tag in
                            MugshotTagChip(title: tag, icon: "tag.fill")
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            if authModel.authenticatedUser == nil, !filteredLocalVisits.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(filteredLocalVisits.prefix(3))) { visit in
                        VisitCard(
                            visit: visit,
                            dataManager: dataManager,
                            selectedScope: .friends,
                            onOpen: { selectedLocalVisit = visit }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selectedLocalVisit = visit }
                    }
                }
                .padding(.horizontal, 16)
            } else if isLoading && remoteVisits.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Opening your journal…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
            } else if let featuredVisit {
                VStack(spacing: 12) {
                    Button { selectedRemoteVisit = featuredVisit } label: {
                        RemoteJournalFeatureCard(visit: featuredVisit)
                    }
                    .buttonStyle(.plain)

                    ForEach(supportingVisits) { visit in
                        Button { selectedRemoteVisit = visit } label: {
                            RemoteJournalRow(visit: visit)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            } else {
                JournalEmptyState(filter: selectedFilter.rawValue) {
                    tabCoordinator.selectedTab = 2
                }
                .padding(.horizontal, 16)
            }

            if let loadError {
                Text(loadError)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
                    .padding(.horizontal, 16)
            }
        }
    }

    private var profileLocationSuffix: String {
        guard let location = user?.location.remoteTrimmedNonEmpty else { return "" }
        return " · \(location)"
    }

    private var profileSummaryLine: String {
        if authModel.authenticatedUser == nil {
            let visits = dataManager.appData.visits
            let uniqueCafes = Set(visits.filter { $0.context == .cafe }.map(\.cafeId)).count
            let averageScore = visits.isEmpty ? 0 : visits.reduce(0.0) { $0 + $1.overallScore } / Double(visits.count)
            let average = averageScore > 0 ? String(format: "%.1f average", averageScore) : "taste still forming"
            return "\(visits.count) journal entries  ·  \(uniqueCafes) cafes  ·  \(average)"
        }
        let average = profileStats.averageScore > 0 ? String(format: "%.1f average", profileStats.averageScore) : "taste still forming"
        return "\(profileStats.totalVisits) journal entries  ·  \(profileStats.totalCafes) cafes  ·  \(average)"
    }

    @MainActor
    private func loadJournal() async {
        guard let userID = authModel.authenticatedUser?.id else {
            journalEntries = []
            tasteSignals = []
            isLoading = false
            loadError = nil
            return
        }

        isLoading = true
        loadError = nil
        do {
            let client = try SupabaseClientProvider.shared.client()
            async let entriesRequest = JournalService(client: client).fetchEntries(userID: userID)
            async let signalsRequest = TasteGraphService(client: client).fetchSignals(userID: userID)
            journalEntries = try await entriesRequest
            tasteSignals = (try? await signalsRequest) ?? []
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            loadError = MugshotUserFacingError.message(for: error, context: .loading)
            isLoading = false
        }
    }

    @MainActor
    private func updateTasteSignal(
        _ signal: RemoteTasteSignal,
        state: TasteSignalOwnerState,
        label: String?
    ) async -> Bool {
        guard let userID = authModel.authenticatedUser?.id else { return false }
        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = TasteGraphService(client: client)
            try await service.setOwnerState(signalID: signal.id, state: state, label: label)
            tasteSignals = try await service.fetchSignals(userID: userID)
            return true
        } catch {
            return false
        }
    }
}

private struct JournalArchiveView: View {
    let entries: [JournalEntryProjection]
    let currentUserID: UUID?
    @ObservedObject var dataManager: DataManager
    let onComposeDraft: (SipDraft) -> Void
    let showsPhase2Tools: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var selection: JournalTabView.JournalFilter = .all
    @State private var query = ""
    @State private var selectedVisit: RemoteVisitSummary?
    @State private var showsBookmarksOnly = false
    @State private var mode: JournalArchiveMode = .timeline
    @State private var selectedDate = Date()
    @State private var bookmarkedIDs: Set<UUID>

    init(
        entries: [JournalEntryProjection],
        currentUserID: UUID?,
        dataManager: DataManager,
        onComposeDraft: @escaping (SipDraft) -> Void,
        showsPhase2Tools: Bool
    ) {
        self.entries = entries
        self.currentUserID = currentUserID
        self.dataManager = dataManager
        self.onComposeDraft = onComposeDraft
        self.showsPhase2Tools = showsPhase2Tools
        _bookmarkedIDs = State(initialValue: Set(entries.filter(\.isBookmarked).map(\.id)))
    }

    private var filteredEntries: [JournalEntryProjection] {
        entries
            .filter { entry in
                switch selection {
                case .all: return true
                case .cafe: return entry.context == .cafe
                case .home: return entry.context == .home
                case .recipes: return entry.context == .recipe
                }
            }
            .filter { !showsBookmarksOnly || bookmarkedIDs.contains($0.id) }
            .filter { $0.matches(query) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    JournalFilterBar(selection: $selection)

                    if showsPhase2Tools {
                        JournalArchiveModePicker(selection: $mode)
                    }

                    if filteredEntries.isEmpty {
                        JournalEmptyState(filter: selection.rawValue)
                    } else {
                        switch mode {
                        case .timeline:
                            ForEach(filteredEntries) { entry in
                                Button { selectedVisit = entry.summary } label: {
                                    RemoteJournalRow(visit: entry.summary)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        toggleBookmark(entry)
                                    } label: {
                                        Label(
                                            bookmarkedIDs.contains(entry.id) ? "Remove Bookmark" : "Bookmark Sip",
                                            systemImage: bookmarkedIDs.contains(entry.id) ? "bookmark.slash" : "bookmark"
                                        )
                                    }
                                }
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        toggleBookmark(entry)
                                    } label: {
                                        Image(systemName: bookmarkedIDs.contains(entry.id) ? "bookmark.fill" : "bookmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.mugshotSage)
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(bookmarkedIDs.contains(entry.id) ? "Remove bookmark" : "Bookmark sip")
                                }
                            }
                        case .calendar:
                            JournalCalendarView(
                                entries: filteredEntries,
                                selectedDate: $selectedDate,
                                onSelect: { selectedVisit = $0.summary }
                            )
                        case .map:
                            JournalMapSummaryView(
                                entries: filteredEntries,
                                onSelect: { selectedVisit = $0.summary }
                            )
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .background(Color.creamWhite)
            .navigationTitle("Your Journal")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search drinks, cafes, notes, or equipment")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsBookmarksOnly.toggle()
                    } label: {
                        Image(systemName: showsBookmarksOnly ? "bookmark.fill" : "bookmark")
                    }
                    .foregroundColor(.mugshotSage)
                    .accessibilityLabel(showsBookmarksOnly ? "Show all journal entries" : "Show bookmarked entries")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.mugshotSage)
                }
            }
            .fullScreenCover(item: $selectedVisit) { visit in
                RemoteVisitDetailView(
                    visitId: visit.id,
                    initialSummary: visit,
                    currentUserId: currentUserID,
                    dataManager: dataManager,
                    onRepeat: { detail in
                        selectedVisit = nil
                        let draft = detail.summary.visit.journalContext == .recipe
                            ? SipDraft.brewAgain(from: detail.summary, ownerUserID: currentUserID)
                            : SipDraft.repeatSip(from: detail.summary, ownerUserID: currentUserID)
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onComposeDraft(draft)
                        }
                    }
                )
            }
        }
    }

    private func toggleBookmark(_ entry: JournalEntryProjection) {
        guard let currentUserID else { return }
        let wasBookmarked = bookmarkedIDs.contains(entry.id)
        if wasBookmarked {
            bookmarkedIDs.remove(entry.id)
        } else {
            bookmarkedIDs.insert(entry.id)
        }
        Task {
            do {
                let client = try SupabaseClientProvider.shared.client()
                try await JournalService(client: client).setBookmarked(
                    !wasBookmarked,
                    visitID: entry.id,
                    userID: currentUserID
                )
            } catch {
                await MainActor.run {
                    if wasBookmarked {
                        bookmarkedIDs.insert(entry.id)
                    } else {
                        bookmarkedIDs.remove(entry.id)
                    }
                }
            }
        }
    }
}

private enum JournalArchiveMode: String, CaseIterable, Identifiable {
    case timeline = "Timeline"
    case calendar = "Calendar"
    case map = "Map"

    var id: String { rawValue }
}

private struct JournalArchiveModePicker: View {
    @Binding var selection: JournalArchiveMode

    var body: some View {
        Picker("Journal view", selection: $selection) {
            ForEach(JournalArchiveMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityHint("Choose timeline, calendar, or map")
    }
}

private struct JournalCalendarView: View {
    let entries: [JournalEntryProjection]
    @Binding var selectedDate: Date
    let onSelect: (JournalEntryProjection) -> Void

    private var entriesForDay: [JournalEntryProjection] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        VStack(spacing: 14) {
            DatePicker(
                "Journal date",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(.mugshotSage)
            .padding(10)
            .cardStyle()

            if entriesForDay.isEmpty {
                Text("No sips remembered on this day.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
            } else {
                ForEach(entriesForDay) { entry in
                    Button { onSelect(entry) } label: {
                        RemoteJournalRow(visit: entry.summary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct JournalMapSummaryView: View {
    let entries: [JournalEntryProjection]
    let onSelect: (JournalEntryProjection) -> Void

    private var mappedEntries: [JournalEntryProjection] {
        entries.filter { $0.summary.cafe?.latitude != nil && $0.summary.cafe?.longitude != nil }
    }

    var body: some View {
        VStack(spacing: 14) {
            if mappedEntries.isEmpty {
                Text("Cafe sips with saved locations will appear here.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .cardStyle()
            } else {
                Map {
                    ForEach(mappedEntries) { entry in
                        if let latitude = entry.summary.cafe?.latitude,
                           let longitude = entry.summary.cafe?.longitude {
                            Annotation(
                                entry.summary.locationTitle,
                                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                            ) {
                                Button { onSelect(entry) } label: {
                                    Image(systemName: "cup.and.saucer.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.foamWhite)
                                        .frame(width: 36, height: 36)
                                        .background(Color.mugshotSage, in: Circle())
                                        .overlay(Circle().stroke(Color.foamWhite, lineWidth: 2))
                                        .shadow(color: .black.opacity(0.14), radius: 6, y: 3)
                                }
                                .accessibilityLabel("Open \(entry.summary.visit.drinkDisplayName) at \(entry.summary.locationTitle)")
                            }
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous))

                Text("\(mappedEntries.count) located cafe sip\(mappedEntries.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }
        }
    }
}

private struct JournalFilterBar: View {
    @Binding var selection: JournalTabView.JournalFilter

    var body: some View {
        HStack(spacing: 4) {
            ForEach(JournalTabView.JournalFilter.allCases) { filter in
                Button {
                    withAnimation(DesignSystem.Motion.fast) { selection = filter }
                } label: {
                    Text(filter.rawValue)
                        .font(.system(size: 13, weight: selection == filter ? .bold : .medium))
                        .foregroundColor(selection == filter ? .foamWhite : .secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selection == filter ? Color.mugshotSage : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.sandBeige.opacity(0.48), in: Capsule())
        .accessibilityElement(children: .contain)
    }
}

private struct RemoteJournalFeatureCard: View {
    let visit: RemoteVisitSummary

    private var details: BrewDetails { visit.visit.structuredBrewDetails }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RemotePhotoImageView(
                urlString: visit.visit.posterPhotoURL,
                placeholderSystemName: "cup.and.saucer.fill",
                contentMode: .fill
            )
            .frame(width: 118, height: 205)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Label(contextLabel, systemImage: visit.visit.journalContext.systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.mugshotSage)

                Text(details.recipeDisplayName ?? visit.visit.drinkDisplayName)
                    .mugshotDisplay(size: 22)
                    .foregroundColor(.espressoBrown)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let extraction = details.extractionSummary {
                    Label(extraction, systemImage: "timer")
                        .journalFactStyle()
                }

                if let origin = journalOriginLine {
                    Label(origin, systemImage: "globe.americas.fill")
                        .journalFactStyle()
                }

                if let method = visit.visit.brewMethod?.remoteTrimmedNonEmpty {
                    Label(method, systemImage: "drop.fill")
                        .journalFactStyle()
                }

                if let equipment = visit.visit.equipment?.remoteTrimmedNonEmpty {
                    Label(equipment, systemImage: "dial.high.fill")
                        .journalFactStyle()
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if let note = visit.visit.trimmedNotes ?? visit.visit.caption.remoteTrimmedNonEmpty {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                        .lineLimit(3)
                }

                Label(visit.visit.backendVisibilityLabel, systemImage: visibilityIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.tertiaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 205, alignment: .topLeading)
        }
        .padding(12)
        .background(Color.sandBeige.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var contextLabel: String {
        switch visit.visit.journalContext {
        case .cafe: return "Cafe Sip · \(visit.locationTitle)"
        case .home: return "Home Brew"
        case .recipe: return "Recipe"
        }
    }

    private var journalOriginLine: String? {
        [details.roastLevel?.remoteTrimmedNonEmpty, details.beanOrigin?.remoteTrimmedNonEmpty]
            .compactMap { $0 }
            .joined(separator: " · ")
            .remoteTrimmedNonEmpty
    }

    private var visibilityIcon: String {
        switch visit.visit.visibility.lowercased() {
        case "private": return "lock.fill"
        case "friends": return "person.2.fill"
        default: return "globe.americas.fill"
        }
    }
}

private struct RemoteJournalRow: View {
    let visit: RemoteVisitSummary

    var body: some View {
        HStack(spacing: 12) {
            RemotePhotoImageView(
                urlString: visit.visit.posterPhotoURL,
                placeholderSystemName: "cup.and.saucer.fill",
                contentMode: .fill
            )
            .frame(width: 92, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: visit.visit.journalContext.systemImage)
                    Text(visit.visit.journalContext == .cafe ? "Cafe Sip" : visit.visit.journalContext.rawValue)
                    Text("·")
                    Text(visit.visit.createdAtDate, style: .date)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.mugshotSage)

                Text(visit.locationTitle)
                    .mugshotDisplay(size: 19)
                    .foregroundColor(.espressoBrown)
                    .lineLimit(1)
                Text(visit.visit.drinkDisplayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                Label(String(format: "%.1f", visit.visit.overallScore), systemImage: "star.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.mugshotSage)
            }

            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.tertiaryText)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct JournalEmptyState: View {
    let filter: String
    var onAdd: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: filter == "Recipes" ? "book.pages.fill" : "cup.and.saucer.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.mugshotSage)
            Text(filter == "All" ? "Your journal starts with a sip" : "No \(filter.lowercased()) entries yet")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.espressoBrown)
            Text("Capture the drink, the moment, and the details you want to remember.")
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
            if let onAdd {
                Button("New journal entry", action: onAdd)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.mugshotSage)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

private struct TasteIdentityJournalSection: View {
    let summary: TasteIdentitySummary
    let signals: [RemoteTasteSignal]
    let entries: [JournalEntryProjection]
    let onChange: (RemoteTasteSignal, TasteSignalOwnerState, String?) async -> Bool
    @State private var selectedSignal: RemoteTasteSignal?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Taste Identity")
                    .mugshotDisplay(size: 28)
                    .foregroundColor(.espressoBrown)
                Spacer()
                Text("Evolves with every journal entry")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.mugshotSage)
            }

            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundColor(.foamWhite)
                    .frame(width: 64, height: 64)
                    .background(Color.mugshotSage, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(summary.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.espressoBrown)
                    Text(summary.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if signals.filter(\.isDurableClaim).isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(summary.patterns) { pattern in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: pattern.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.mugshotSage)
                                .frame(width: 18)
                            Text(pattern.text)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(signals.filter(\.isDurableClaim).prefix(5)) { signal in
                        Button {
                            selectedSignal = signal
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: signal.systemImage)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.mugshotSage)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(signal.claimText)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.espressoBrown)
                                    Text(signal.evidenceSummary)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondaryText)
                                }
                                Spacer(minLength: 6)
                                Image(systemName: "info.circle")
                                    .foregroundColor(.mugshotSage)
                            }
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(item: $selectedSignal) { signal in
            TasteSignalEvidenceView(
                signal: signal,
                entries: entries.filter { signal.evidenceVisitIDs.contains($0.id) },
                onChange: onChange
            )
        }
    }
}

private struct TasteSignalEvidenceView: View {
    let signal: RemoteTasteSignal
    let entries: [JournalEntryProjection]
    let onChange: (RemoteTasteSignal, TasteSignalOwnerState, String?) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var correctedLabel = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(signal.signalType.title, systemImage: signal.systemImage)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.mugshotSage)
                        Text(signal.claimText)
                            .mugshotDisplay(size: 28)
                            .foregroundColor(.espressoBrown)
                        Text(signal.evidenceSummary + ". Mugshot requires at least three before showing this pattern.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondaryText)
                    }

                    if signal.signalType == .orderPreference {
                        Text("This describes what you tend to order. It does not claim that a specific drink tasted sweet, bitter, acidic, or clear.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.espressoBrown.opacity(0.76))
                            .padding(14)
                            .background(Color.mugshotMint.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Journal evidence")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.espressoBrown)
                        ForEach(entries) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.summary.visit.drinkDisplayName)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("\(entry.summary.locationTitle) · \(entry.date.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondaryText)
                                }
                                Spacer()
                                if signal.signalType == .sensoryEvaluation,
                                   let score = entry.summary.visit.orderedRatingScores.first(where: {
                                       $0.name.lowercased().replacingOccurrences(of: " ", with: "_") == signal.attribute
                                   })?.score {
                                    Text(String(format: "%.1f", score))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.mugshotSage)
                                }
                            }
                            .padding(12)
                            .cardStyle()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Make it yours")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.espressoBrown)
                        TextField("A label that feels right", text: $correctedLabel)
                            .textFieldStyle(.roundedBorder)
                        Button("Use my wording") {
                            Task { await save(.corrected, label: correctedLabel) }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(correctedLabel.remoteTrimmedNonEmpty == nil || isSaving)

                        Button("This is not me", role: .destructive) {
                            Task { await save(.dismissed, label: nil) }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .disabled(isSaving)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }
            .background(Color.creamWhite)
            .navigationTitle("Why Mugshot thinks this")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func save(_ state: TasteSignalOwnerState, label: String?) async {
        isSaving = true
        errorMessage = nil
        let succeeded = await onChange(signal, state, label)
        isSaving = false
        if succeeded {
            dismiss()
        } else {
            errorMessage = "That change did not save. Please try again."
        }
    }
}

private extension View {
    func journalFactStyle() -> some View {
        font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondaryText)
            .lineLimit(1)
    }
}
