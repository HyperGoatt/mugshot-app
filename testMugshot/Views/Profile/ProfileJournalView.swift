import SwiftUI

struct ProfileTabView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @EnvironmentObject private var tabCoordinator: TabCoordinator

    @State private var selectedFilter: JournalFilter = .all
    @State private var activeProfileSheet: ProfileSheet?
    @State private var showJournalArchive = false
    @State private var selectedRemoteVisit: RemoteVisitSummary?
    @State private var selectedLocalVisit: Visit?
    @State private var remoteVisits: [RemoteVisitSummary] = []
    @State private var isLoading = false
    @State private var loadError: String?

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

    private var profileStats: RemoteProfileStats {
        RemoteProfileStats.calculate(from: remoteVisits)
    }

    private var tasteIdentity: TasteIdentitySummary {
        TasteIdentitySummary.calculate(from: remoteVisits)
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
                    MugshotScreenHeader("Profile") {
                        MugshotIconButton(systemName: "gearshape", size: 44) {
                            activeProfileSheet = .settings
                        }
                        .accessibilityLabel("Settings")
                    }

                    profileHeader

                    Divider()
                        .overlay(Color.mugshotLine)
                        .padding(.horizontal, 16)
                        .padding(.top, 22)

                    journalSection
                        .padding(.top, 22)

                    Divider()
                        .overlay(Color.mugshotLine)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 24)

                    TasteIdentityJournalSection(summary: tasteIdentity)
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
            .fullScreenCover(item: $selectedRemoteVisit) { visit in
                RemoteVisitDetailView(
                    visitId: visit.id,
                    initialSummary: visit,
                    currentUserId: authModel.authenticatedUser?.id,
                    dataManager: dataManager
                )
            }
            .fullScreenCover(item: $selectedLocalVisit) { visit in
                VisitDetailView(visit: visit, dataManager: dataManager)
            }
            .fullScreenCover(isPresented: $showJournalArchive) {
                JournalArchiveView(
                    visits: remoteVisits,
                    currentUserID: authModel.authenticatedUser?.id,
                    dataManager: dataManager
                )
            }
            .task(id: "\(authModel.authenticatedUser?.id.uuidString ?? "signed-out")-\(dataManager.journalRevision)") {
                await loadJournal()
            }
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
                Text("Journal")
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
            remoteVisits = []
            isLoading = false
            loadError = nil
            return
        }

        isLoading = true
        loadError = nil
        do {
            let client = try SupabaseClientProvider.shared.client()
            remoteVisits = try await VisitService(client: client).fetchRecentVisits(
                userId: userID,
                limit: 100,
                includeSocialState: false
            )
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            loadError = MugshotUserFacingError.message(for: error, context: .loading)
            isLoading = false
        }
    }
}

private struct JournalArchiveView: View {
    let visits: [RemoteVisitSummary]
    let currentUserID: UUID?
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    @State private var selection: ProfileTabView.JournalFilter = .all
    @State private var query = ""
    @State private var selectedVisit: RemoteVisitSummary?

    private var filteredVisits: [RemoteVisitSummary] {
        visits
            .filter { visit in
                switch selection {
                case .all: return true
                case .cafe: return visit.visit.journalContext == .cafe
                case .home: return visit.visit.journalContext == .home
                case .recipes: return visit.visit.journalContext == .recipe
                }
            }
            .filter { visit in
                guard let query = query.remoteTrimmedNonEmpty?.lowercased() else { return true }
                return [
                    visit.visit.drinkDisplayName,
                    visit.locationTitle,
                    visit.visit.caption,
                    visit.visit.notes ?? "",
                    visit.visit.brewMethod ?? "",
                    visit.visit.equipment ?? ""
                ].contains { $0.lowercased().contains(query) }
            }
            .sorted { $0.visit.createdAtDate > $1.visit.createdAtDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    JournalFilterBar(selection: $selection)

                    if filteredVisits.isEmpty {
                        JournalEmptyState(filter: selection.rawValue)
                    } else {
                        ForEach(filteredVisits) { visit in
                            Button { selectedVisit = visit } label: {
                                RemoteJournalRow(visit: visit)
                            }
                            .buttonStyle(.plain)
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
                    dataManager: dataManager
                )
            }
        }
    }
}

private struct JournalFilterBar: View {
    @Binding var selection: ProfileTabView.JournalFilter

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ProfileTabView.JournalFilter.allCases) { filter in
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
                    if pattern.id != summary.patterns.last?.id {
                        Divider().overlay(Color.mugshotLine)
                    }
                }
            }
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
