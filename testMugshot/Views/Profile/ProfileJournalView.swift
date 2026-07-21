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
    @State private var showOwnerProfile = false
    @State private var localDrafts: [SipDraft] = []
    @State private var tasteSignals: [RemoteTasteSignal] = []
    @State private var cafeExperienceSummaries: [RemoteCafeExperienceSummary] = []
    @State private var selectedReflection: JournalReflectionSummary?
    @AppStorage(RoadmapFeatureFlags.phase2CanonicalJournal) private var phase2CanonicalJournal = true
    @AppStorage(RoadmapFeatureFlags.phase3ExplainableTasteGraph) private var phase3ExplainableTasteGraph = true
    @AppStorage(RoadmapFeatureFlags.phase5Reflections) private var phase5Reflections = true

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
            ? TasteIdentitySummary.calculate(from: tasteSignals, visits: remoteVisits)
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

    private var recentVisits: [RemoteVisitSummary] {
        Array(filteredVisits.prefix(4))
    }

    private var ritualDates: [Date] {
        if authModel.authenticatedUser != nil {
            return journalEntries.map(\.date)
        }
        return dataManager.appData.visits.map(\.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    MugshotScreenHeader("Journal") {
                        Button {
                            showOwnerProfile = true
                        } label: {
                            MugshotAvatar(
                                name: user?.displayNameOrUsername ?? authModel.profile?.displayName ?? "user",
                                size: 42,
                                imageURL: authModel.profile?.avatarURL ?? user?.avatarImageName
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Open your profile")
                    }

                    Text(profileSummaryLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)

                    MugshotRitualCard(dates: ritualDates)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    if phase2CanonicalJournal, !localDrafts.isEmpty {
                        draftSection
                            .padding(.top, 18)
                    }

                    if phase2CanonicalJournal, let memory = onThisSipEntries.first {
                        onThisSipCard(memory)
                            .padding(.horizontal, 16)
                            .padding(.top, 18)
                    }

                    if phase5Reflections, !journalEntries.isEmpty {
                        JournalReflectionsSection(
                            entries: journalEntries,
                            onSelect: { selectedReflection = $0 }
                        )
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
            .toolbar(.hidden, for: .navigationBar)
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
            .navigationDestination(isPresented: $showOwnerProfile) {
                OwnerPassportProfileView(
                    dataManager: dataManager,
                    entries: journalEntries,
                    identity: tasteIdentity,
                    cafeExperienceSummaries: cafeExperienceSummaries
                )
                .environmentObject(authModel)
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
                        onRepeat: { detail in
                            launchComposer(from: detail.summary)
                        }
                    )
                }
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { selectedLocalVisit != nil },
                    set: { if !$0 { selectedLocalVisit = nil } }
                )
            ) {
                if let visit = selectedLocalVisit {
                    VisitDetailView(visit: visit, dataManager: dataManager)
                }
            }
            .sheet(item: $selectedReflection) { reflection in
                JournalReflectionDetailView(
                    reflection: reflection,
                    entries: journalEntries,
                    milestones: JournalReflectionEngine.milestones(entries: journalEntries)
                )
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
                    Text("Revisit what stood out, with no pressure to add anything new.")
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                        .lineLimit(2)
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
                MugshotLoadingState(layout: .journal, count: 3)
                    .padding(.horizontal, 16)
            } else if !recentVisits.isEmpty {
                VStack(spacing: 12) {
                    ForEach(recentVisits) { visit in
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
            let average = averageScore > 0 ? String(format: "%.1f sip average", averageScore) : "taste still forming"
            return "\(visits.count) journal entries  ·  \(uniqueCafes) cafes  ·  \(average)"
        }
        let average = profileStats.averageScore > 0 ? String(format: "%.1f sip average", profileStats.averageScore) : "taste still forming"
        return "\(profileStats.totalVisits) journal entries  ·  \(profileStats.totalCafes) cafes  ·  \(average)"
    }

    @MainActor
    private func loadJournal() async {
        guard let userID = authModel.authenticatedUser?.id else {
            journalEntries = []
            tasteSignals = []
            cafeExperienceSummaries = []
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
            let loadedEntries = try await entriesRequest
            let cafeIDs: [UUID] = Array(Set(loadedEntries.compactMap { entry -> UUID? in
                guard entry.summary.visit.journalContext == .cafe else {
                    return nil
                }
                return entry.summary.cafe?.id
            }))
            async let summariesRequest = CafeSessionService(client: client).fetchCafeSummaries(
                cafeIDs: cafeIDs,
                scope: .personal
            )
            let loadedSignals = (try? await signalsRequest) ?? []
            let loadedCafeSummaries = (try? await summariesRequest) ?? []
            guard !Task.isCancelled else { return }
            journalEntries = loadedEntries
            tasteSignals = loadedSignals
            cafeExperienceSummaries = loadedCafeSummaries
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

private struct OwnerPassportProfileView: View {
    @ObservedObject var dataManager: DataManager
    let entries: [JournalEntryProjection]
    let identity: TasteIdentitySummary
    let cafeExperienceSummaries: [RemoteCafeExperienceSummary]
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var selectedVisit: RemoteVisitSummary?

    private var profile: SupabaseUserProfile? { authModel.profile }
    private var visits: [RemoteVisitSummary] { entries.map(\.summary) }
    private var stats: RemoteProfileStats { RemoteProfileStats.calculate(from: visits) }
    private var homeCount: Int { visits.filter { $0.visit.journalContext == .home }.count }
    private var average: Double? { stats.totalVisits > 0 ? stats.averageScore : nil }
    private var cafeRanking: RemoteProfileCafeRanking {
        RemoteProfileCafeRanking.calculate(
            from: visits,
            cafeExperienceSummaries: cafeExperienceSummaries
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MugshotScreenHeader("Profile", subtitle: "Your public-facing coffee identity") {
                    MugshotIconButton(systemName: "gearshape.fill", size: 36) {
                        showSettings = true
                    }
                    .accessibilityLabel("Settings")
                }

                MugshotPassportCard(
                    displayName: profile?.displayName ?? dataManager.appData.currentUser?.displayNameOrUsername ?? "Mugshot User",
                    username: profile?.username ?? dataManager.appData.currentUser?.username ?? "user",
                    avatarURL: profile?.avatarURL,
                    bannerURL: profile?.bannerURL,
                    identity: identity,
                    stats: MugshotPassportStats(
                        sips: stats.totalVisits,
                        cafes: stats.totalCafes,
                        homeSips: homeCount,
                        averageRating: average
                    ),
                    allowsSharing: true
                )
                .padding(.horizontal, 16)

                if let bio = profile?.bio?.remoteTrimmedNonEmpty {
                    Text(bio)
                        .font(.system(size: 14))
                        .foregroundColor(.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(15)
                        .cardStyle()
                        .padding(.horizontal, 16)
                }

                Button {
                    authModel.clearProfileUpdateError()
                    showEditProfile = true
                } label: {
                    Label("Edit profile", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, 16)

                if !cafeRanking.entries.isEmpty {
                    topCafesSection
                }

                if !visits.isEmpty {
                    MugshotSectionTitle(
                        title: "Your visible profile",
                        subtitle: "This is how your recent shared journal reads to other people."
                    )
                    .padding(.horizontal, 16)

                    VStack(spacing: 10) {
                        ForEach(visits.filter { $0.visit.visibility.lowercased() != "private" }.prefix(6)) { visit in
                            Button { selectedVisit = visit } label: {
                                RemoteJournalRow(visit: visit)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.creamWhite)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showEditProfile) {
            if let profile {
                EditProfileView(profile: profile, dataManager: dataManager)
                    .environmentObject(authModel)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(dataManager: dataManager)
                .environmentObject(authModel)
        }
        .navigationDestination(
            isPresented: Binding(
                get: { selectedVisit != nil },
                set: { if !$0 { selectedVisit = nil } }
            )
        ) {
            if let visit = selectedVisit {
                RemoteVisitDetailView(
                    visitId: visit.id,
                    initialSummary: visit,
                    currentUserId: authModel.authenticatedUser?.id,
                    dataManager: dataManager
                )
            }
        }
    }

    private var topCafesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MugshotSectionTitle(
                title: "Top cafes",
                subtitle: topCafesSubtitle
            )

            ForEach(cafeRanking.entries.prefix(5)) { entry in
                ProfileTopCafeCard(
                    entry: entry,
                    basis: cafeRanking.basis
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private var topCafesSubtitle: String {
        switch cafeRanking.basis {
        case .cafeExperience:
            return "Ranked by your independent Cafe Pulse ratings."
        case .sipAverageLegacy:
            return "Sip average fallback · drink enjoyment, not a cafe rating."
        }
    }
}

private struct ProfileTopCafeCard: View {
    let entry: RemoteProfileCafeRanking.Entry
    let basis: RemoteProfileCafeRanking.Basis

    var body: some View {
        HStack(spacing: 12) {
            RemotePhotoImageView(
                urlString: entry.posterPhotoURL,
                placeholderSystemName: "cup.and.saucer.fill"
            )
            .frame(width: 68, height: 68)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignSystem.Radius.control,
                    style: .continuous
                )
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.cafe.consumerDisplayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.espressoBrown)
                    .lineLimit(2)

                if !entry.cafe.displayLocation.isEmpty {
                    Text(entry.cafe.displayLocation)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                }

                HStack(spacing: 9) {
                    Label(scoreLabel, systemImage: "star.fill")
                    Label(evidenceLabel, systemImage: "cup.and.saucer.fill")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.mugshotSage)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private var scoreLabel: String {
        let value = String(format: "%.1f", entry.score)
        switch basis {
        case .cafeExperience:
            return "Cafe average \(value)"
        case .sipAverageLegacy:
            return "Sip average \(value)"
        }
    }

    private var evidenceLabel: String {
        switch basis {
        case .cafeExperience:
            let count = entry.ratedCafeSessionCount
            return "\(count) cafe rating\(count == 1 ? "" : "s")"
        case .sipAverageLegacy:
            return "\(entry.sipCount) sip\(entry.sipCount == 1 ? "" : "s")"
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

    private var timelineGroups: [JournalArchiveMonthGroup] {
        let calendar = Calendar.current
        return Dictionary(grouping: filteredEntries) { entry in
            calendar.date(from: calendar.dateComponents([.year, .month], from: entry.date)) ?? entry.date
        }
        .map { JournalArchiveMonthGroup(month: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
        .sorted { $0.month > $1.month }
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
                            ForEach(timelineGroups) { group in
                                JournalTimelineMonthSection(
                                    group: group,
                                    bookmarkedIDs: bookmarkedIDs,
                                    onSelect: { selectedVisit = $0.summary },
                                    onToggleBookmark: toggleBookmark
                                )
                                if group.id != timelineGroups.last?.id {
                                    Divider()
                                        .overlay(Color.mugshotLine)
                                        .padding(.vertical, 4)
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
            .navigationDestination(
                isPresented: Binding(
                    get: { selectedVisit != nil },
                    set: { if !$0 { selectedVisit = nil } }
                )
            ) {
                if let visit = selectedVisit {
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

private struct JournalArchiveMonthGroup: Identifiable {
    let month: Date
    let entries: [JournalEntryProjection]

    var id: Date { month }
    var photoEntries: [JournalEntryProjection] {
        Array(entries.filter { $0.summary.visit.posterPhotoURL?.remoteTrimmedNonEmpty != nil }.prefix(8))
    }
}

private struct JournalTimelineMonthSection: View {
    let group: JournalArchiveMonthGroup
    let bookmarkedIDs: Set<UUID>
    let onSelect: (JournalEntryProjection) -> Void
    let onToggleBookmark: (JournalEntryProjection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.month.formatted(.dateTime.month(.wide).year()))
                    .mugshotDisplay(size: 23)
                    .foregroundColor(.espressoBrown)
                Spacer()
                Text("\(group.entries.count) \(group.entries.count == 1 ? "memory" : "memories")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.mugshotSage)
            }

            if !group.photoEntries.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(group.photoEntries) { entry in
                            Button { onSelect(entry) } label: {
                                RemotePhotoImageView(
                                    urlString: entry.summary.visit.posterPhotoURL,
                                    placeholderSystemName: "cup.and.saucer.fill",
                                    contentMode: .fill
                                )
                                .frame(width: 102, height: 126)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                                .overlay(alignment: .bottomLeading) {
                                    Text(entry.summary.visit.drinkDisplayName)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.foamWhite)
                                        .lineLimit(1)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(.black.opacity(0.46))
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(entry.summary.visit.drinkDisplayName) from \(entry.date.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }
                }
            }

            ForEach(group.entries) { entry in
                Button { onSelect(entry) } label: {
                    RemoteJournalRow(visit: entry.summary)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { onToggleBookmark(entry) } label: {
                        Label(
                            bookmarkedIDs.contains(entry.id) ? "Remove Bookmark" : "Bookmark Sip",
                            systemImage: bookmarkedIDs.contains(entry.id) ? "bookmark.slash" : "bookmark"
                        )
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Button { onToggleBookmark(entry) } label: {
                        Image(systemName: bookmarkedIDs.contains(entry.id) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.mugshotSage)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(bookmarkedIDs.contains(entry.id) ? "Remove bookmark" : "Bookmark sip")
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
                    ZStack {
                        Capsule()
                            .fill(selection == filter ? Color.mugshotSage : Color.foamWhite.opacity(0.10))
                        Text(filter.rawValue)
                            .font(.system(size: 13, weight: selection == filter ? .bold : .medium))
                            .foregroundColor(selection == filter ? .foamWhite : .secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityAddTraits(selection == filter ? .isSelected : [])
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
            Group {
                if visit.visit.posterPhotoURL != nil {
                    RemotePhotoImageView(
                        urlString: visit.visit.posterPhotoURL,
                        placeholderSystemName: "cup.and.saucer.fill",
                        contentMode: .fill
                    )
                } else {
                    RemoteVisitNoPhotoThumbnail(
                        usesMugsyFallback: visit.usesMugsyPhotoFallback
                    )
                }
            }
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
        case .elsewhere: return visit.locationTitle
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

struct RemoteJournalRow: View {
    let visit: RemoteVisitSummary

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if visit.visit.posterPhotoURL != nil {
                    RemotePhotoImageView(
                        urlString: visit.visit.posterPhotoURL,
                        placeholderSystemName: "cup.and.saucer.fill",
                        contentMode: .fill
                    )
                } else {
                    RemoteVisitNoPhotoThumbnail(
                        usesMugsyFallback: visit.usesMugsyPhotoFallback
                    )
                }
            }
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
                Label(String(format: "%.1f", visit.displayedMugshotScore), systemImage: "star.fill")
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
            MugsyModelView(configuration: MugsyPlacement.journalEmpty.configuration)
                .frame(width: 104, height: 104)
                .accessibilityHidden(true)
            Text(filter == "All" ? "Your journal starts with a sip" : "No \(filter.lowercased()) entries yet")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.espressoBrown)
            Text("Capture the drink, the moment, and the details you want to remember.")
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
            if let onAdd {
                Button(action: onAdd) {
                    ZStack {
                        Capsule().fill(Color.mugshotMint.opacity(0.34))
                        Text("New journal entry")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.mugshotSage)
                            .padding(.horizontal, 16)
                    }
                    .frame(minWidth: 164, minHeight: 44)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
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

    private var recentEntries: [JournalEntryProjection] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) else { return entries }
        return entries.filter { $0.date >= cutoff }
    }

    private var locatedEntries: [JournalEntryProjection] {
        entries.filter { $0.summary.cafe?.latitude != nil && $0.summary.cafe?.longitude != nil }
    }

    private var uniqueLocatedCafeCount: Int {
        Set(locatedEntries.compactMap { $0.summary.cafe?.id }).count
    }

    private var bloomSamples: [TasteBloomSample] {
        let durable = signals.filter(\.isDurableClaim)
        if !durable.isEmpty {
            return durable.map {
                TasteBloomSample(
                    label: $0.displayAttribute,
                    value: MugshotMotion.normalized($0.confidence),
                    support: $0.supportCount
                )
            }
        }

        let confidence = min(0.72, 0.24 + Double(recentEntries.count) * 0.06)
        return summary.descriptors.enumerated().map { index, descriptor in
            TasteBloomSample(
                label: descriptor,
                value: max(0.22, confidence - Double(index) * 0.07),
                support: recentEntries.count
            )
        }
    }

    private var bloomConfidence: Double {
        let durable = signals.filter(\.isDurableClaim)
        if !durable.isEmpty {
            return durable.map(\.confidence).reduce(0, +) / Double(durable.count)
        }
        return min(0.68, Double(recentEntries.count) / 10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Mugshot Passport")
                    .mugshotDisplay(size: 28)
                    .foregroundColor(.espressoBrown)
                Spacer()
                Text(summary.isForming ? "Still forming" : "One of 512 title combinations")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.mugshotSage)
            }

            HStack(alignment: .top, spacing: 14) {
                MugshotTasteBloom(
                    samples: bloomSamples,
                    confidence: bloomConfidence,
                    size: 104
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(summary.title)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(.espressoBrown)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(summary.descriptors, id: \.self) { descriptor in
                                Text(descriptor)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.mugshotSage)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.mugshotMint.opacity(0.34), in: Capsule())
                            }
                        }
                    }
                    Text(summary.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Your passport grows from your journal history. The last 90 days keep the picture current without turning taste into a score.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                identityFact(
                    value: "\(recentEntries.count)",
                    label: "sips · 90 days",
                    icon: "clock.fill"
                )
                identityFact(
                    value: "\(uniqueLocatedCafeCount)",
                    label: uniqueLocatedCafeCount == 1 ? "cafe on your map" : "cafes on your map",
                    icon: "map.fill"
                )
            }

            if !locatedEntries.isEmpty {
                TasteIdentityFootprint(entries: locatedEntries)
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

    private func identityFact(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.mugshotSage)
                .frame(width: 30, height: 30)
                .background(Color.mugshotMint.opacity(0.44), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(.espressoBrown)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.sandBeige.opacity(0.38), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct TasteIdentityFootprint: View {
    let entries: [JournalEntryProjection]

    private var mapEntries: [JournalEntryProjection] {
        var seen: Set<UUID> = []
        return entries.filter { entry in
            guard let cafeID = entry.summary.cafe?.id else { return false }
            return seen.insert(cafeID).inserted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your coffee footprint")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Spacer()
                Text("Personal, not ranked")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.mugshotSage)
            }

            Map {
                ForEach(mapEntries) { entry in
                    if let latitude = entry.summary.cafe?.latitude,
                       let longitude = entry.summary.cafe?.longitude {
                        Marker(
                            entry.summary.locationTitle,
                            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        )
                        .tint(Color.mugshotSage)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 156)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .allowsHitTesting(false)
            .accessibilityLabel("Map of \(mapEntries.count) cafes in your journal")
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
