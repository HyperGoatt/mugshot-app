//
//  ProfileTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

struct ProfileTabView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var selectedTab: ProfileContentTab = .recent
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var remoteProfileVisits: [RemoteVisitSummary] = []
    @State private var isLoadingRemoteProfileStats = false
    @State private var remoteProfileStatsError: String?

    enum ProfileContentTab: String, CaseIterable {
        case recent = "Recent"
        case topCafes = "Top Cafes"
        case favorites = "Favorites"
        case wishlist = "Wishlist"
    }

    var user: User? {
        dataManager.appData.currentUser
    }

    var stats: (totalVisits: Int, totalCafes: Int, averageScore: Double, favoriteDrinkType: DrinkType?) {
        dataManager.getUserStats()
    }

    private var displayedStats: ProfileStatsDisplay {
        if authModel.authenticatedUser != nil {
            return ProfileStatsDisplay(remote: RemoteProfileStats.calculate(from: remoteProfileVisits))
        }

        return ProfileStatsDisplay(
            totalVisits: stats.totalVisits,
            totalCafes: stats.totalCafes,
            averageScore: stats.averageScore,
            favoriteDrinkLabel: stats.favoriteDrinkType?.rawValue
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    MugshotScreenHeader("Profile") {
                        MugshotIconButton(systemName: "gearshape", size: 36) {
                            showSettings = true
                        }
                        .accessibilityLabel("Settings")
                    }

                    profileIdentity

                    statsStrip

                    if isLoadingRemoteProfileStats {
                        Text("Refreshing remote stats...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.tertiaryText)
                    } else if let remoteProfileStatsError {
                        Text(remoteProfileStatsError)
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.82))
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Taste identity")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.espressoBrown)

                        CoffeeJourneyView(stats: displayedStats)
                    }
                    .padding(16)
                    .cardStyle()
                    .padding(.horizontal, 16)

                    MugshotSegmentedControl(
                        options: ProfileContentTab.allCases,
                        selection: $selectedTab,
                        title: { $0.rawValue }
                    )
                    .padding(.horizontal, 16)

                    contentView
                        .padding(.horizontal, 16)

                    Text("Sip. Save. Share.")
                        .mugshotDisplay(size: 15)
                        .foregroundColor(.mugshotLatte)
                        .padding(.bottom, 32)
                }
            }
            .background(Color.creamWhite)
            .sheet(isPresented: $showEditProfile) {
                if let profile = authModel.profile {
                    EditProfileView(profile: profile, dataManager: dataManager)
                        .environmentObject(authModel)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authModel)
            }
            .task(id: authModel.authenticatedUser?.id) {
                await loadRemoteProfileStats()
            }
        }
    }

    private var profileIdentity: some View {
        VStack(spacing: 10) {
            MugshotAvatar(name: user?.username ?? "user", size: 76)

            VStack(spacing: 3) {
                Text(user?.displayName?.isEmpty == false ? user?.displayName ?? "" : user?.username ?? "user")
                    .mugshotDisplay(size: 24)
                    .foregroundColor(.espressoBrown)

                Text("@\(user?.username ?? "user")\(user?.location.isEmpty == false ? " · \(user?.location ?? "")" : "")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.tertiaryText)
            }

            if let bio = user?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 14))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 6) {
                MugshotTagChip(title: displayedStats.favoriteDrinkLabel?.lowercased() ?? "daily ritual", icon: "leaf.fill")
                MugshotTagChip(title: "hidden gem hunter", icon: "sparkles")
            }

            if authModel.profile != nil {
                Button {
                    authModel.clearProfileUpdateError()
                    showEditProfile = true
                } label: {
                    Label("Edit profile", systemImage: "pencil")
                        .frame(maxWidth: 150)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statsStrip: some View {
        HStack(spacing: 8) {
            MugshotStatPill(icon: "mug.fill", value: "\(displayedStats.totalVisits)", label: "Logs")
            MugshotStatPill(icon: "mappin.circle.fill", value: "\(displayedStats.totalCafes)", label: "Cafes")
            MugshotStatPill(icon: "star.fill", value: String(format: "%.1f", displayedStats.averageScore), label: "Avg")
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .recent:
            RecentVisitsView(dataManager: dataManager)
                .environmentObject(authModel)
        case .topCafes:
            TopCafesView(
                dataManager: dataManager,
                remoteStats: authModel.authenticatedUser == nil ? nil : RemoteProfileStats.calculate(from: remoteProfileVisits)
            )
        case .favorites:
            FavoritesView(dataManager: dataManager)
        case .wishlist:
            WishlistView(dataManager: dataManager)
        }
    }

    @MainActor
    private func loadRemoteProfileStats() async {
        guard let userId = authModel.authenticatedUser?.id else {
            remoteProfileVisits = []
            remoteProfileStatsError = nil
            isLoadingRemoteProfileStats = false
            return
        }

        isLoadingRemoteProfileStats = true
        remoteProfileStatsError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            remoteProfileVisits = try await service.fetchRecentVisits(
                userId: userId,
                limit: 100,
                includeSocialState: false
            )
            isLoadingRemoteProfileStats = false
        } catch {
            remoteProfileStatsError = "Could not load remote profile stats."
            isLoadingRemoteProfileStats = false
        }
    }
}

struct ProfileStatsDisplay: Equatable {
    let totalVisits: Int
    let totalCafes: Int
    let averageScore: Double
    let favoriteDrinkLabel: String?

    init(
        totalVisits: Int,
        totalCafes: Int,
        averageScore: Double,
        favoriteDrinkLabel: String?
    ) {
        self.totalVisits = totalVisits
        self.totalCafes = totalCafes
        self.averageScore = averageScore
        self.favoriteDrinkLabel = favoriteDrinkLabel
    }

    init(remote: RemoteProfileStats) {
        self.init(
            totalVisits: remote.totalVisits,
            totalCafes: remote.totalCafes,
            averageScore: remote.averageScore,
            favoriteDrinkLabel: remote.favoriteDrinkLabel
        )
    }
}

struct EditProfileView: View {
    let profile: SupabaseUserProfile
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String
    @State private var username: String
    @State private var bio: String
    @State private var location: String
    @State private var favoriteDrink: String
    @State private var instagramHandle: String
    @State private var websiteURL: String

    init(profile: SupabaseUserProfile, dataManager: DataManager) {
        self.profile = profile
        self.dataManager = dataManager
        _displayName = State(initialValue: profile.displayName)
        _username = State(initialValue: profile.username)
        _bio = State(initialValue: profile.bio ?? "")
        _location = State(initialValue: profile.location ?? "")
        _favoriteDrink = State(initialValue: profile.favoriteDrink ?? "")
        _instagramHandle = State(initialValue: profile.instagramHandle ?? "")
        _websiteURL = State(initialValue: profile.websiteURL ?? "")
    }

    private var normalizedUsername: String {
        username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private var displayNameIsValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var usernameIsValid: Bool {
        normalizedUsername.count >= 3
    }

    private var canSave: Bool {
        displayNameIsValid && usernameIsValid && !authModel.isUpdatingProfile
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MugshotSectionTitle(
                        title: "Profile details",
                        subtitle: "Keep this warm and useful. It appears alongside your sips."
                    )

                    profileField(
                        title: "Display Name",
                        text: $displayName,
                        placeholder: "Your name"
                    )

                    profileField(
                        title: "Username",
                        text: $username,
                        placeholder: "username",
                        autocapitalization: .never,
                        autocorrectionDisabled: true
                    )

                    if !usernameIsValid {
                        Text("Username must be at least 3 letters, numbers, or underscores.")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.8))
                    } else if normalizedUsername != username.trimmingCharacters(in: .whitespacesAndNewlines) {
                        Text("Will save as @\(normalizedUsername).")
                            .font(.system(size: 12))
                            .foregroundColor(.tertiaryText)
                    }

                    profileField(
                        title: "Location",
                        text: $location,
                        placeholder: "City"
                    )

                    profileField(
                        title: "Favorite Drink",
                        text: $favoriteDrink,
                        placeholder: "Cortado, matcha, pour-over..."
                    )

                    profileField(
                        title: "Instagram",
                        text: $instagramHandle,
                        placeholder: "handle",
                        autocapitalization: .never,
                        autocorrectionDisabled: true
                    )

                    profileField(
                        title: "Website",
                        text: $websiteURL,
                        placeholder: "https://...",
                        autocapitalization: .never,
                        autocorrectionDisabled: true
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.espressoBrown)

                        TextField("Tell people what you are sipping lately.", text: $bio, axis: .vertical)
                            .lineLimit(3...5)
                            .profileEditorField()
                    }

                    if let error = authModel.profileUpdateError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: saveProfile) {
                        HStack {
                            if authModel.isUpdatingProfile {
                                ProgressView()
                                    .tint(.foamWhite)
                            }

                            Text("Save profile")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.6)
                }
                .padding(DesignSystem.largePadding)
            }
            .background(Color.creamWhite)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(authModel.isUpdatingProfile)
                }
            }
        }
    }

    private func profileField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        autocapitalization: TextInputAutocapitalization = .words,
        autocorrectionDisabled: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.espressoBrown)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .profileEditorField()
        }
    }

    private func saveProfile() {
        Task {
            let didSave = await authModel.updateProfile(
                displayName: displayName,
                username: normalizedUsername,
                bio: bio,
                location: location,
                favoriteDrink: favoriteDrink,
                instagramHandle: instagramHandle,
                websiteURL: websiteURL,
                dataManager: dataManager
            )

            if didSave {
                dismiss()
            }
        }
    }
}

private extension View {
    func profileEditorField() -> some View {
        mugshotFormField()
    }
}

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.espressoBrown)

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.espressoBrown.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

struct CoffeeJourneyView: View {
    let stats: ProfileStatsDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Simple progress representation
            HStack(spacing: 8) {
                ForEach(0..<min(stats.totalCafes, 10), id: \.self) { _ in
                    Circle()
                        .fill(Color.mugshotSage)
                        .frame(width: 12, height: 12)
                }

                if stats.totalCafes > 10 {
                    Text("+\(stats.totalCafes - 10)")
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.7))
                }
            }

            Text("\(stats.totalVisits) visits across \(stats.totalCafes) cafés")
                .font(.system(size: 14))
                .foregroundColor(.espressoBrown.opacity(0.7))
        }
    }
}

struct RecentVisitsView: View {
    @ObservedObject var dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var remoteVisits: [RemoteVisitSummary] = []
    @State private var isLoadingRemoteVisits = false
    @State private var remoteVisitError: String?
    @State private var selectedVisit: Visit?
    @State private var showVisitDetail = false
    @State private var selectedRemoteVisit: RemoteVisitSummary?

    private var localVisits: [Visit] {
        dataManager.appData.visits.sorted { $0.date > $1.date }.prefix(10).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if authModel.authenticatedUser != nil {
                remoteContent
            } else {
                localContent
            }
        }
        .task(id: authModel.authenticatedUser?.id) {
            await loadRemoteVisits()
        }
        .sheet(isPresented: $showVisitDetail) {
            if let visit = selectedVisit {
                VisitDetailView(visit: visit, dataManager: dataManager)
            }
        }
        .sheet(item: $selectedRemoteVisit) { visit in
            RemoteVisitDetailView(
                visitId: visit.id,
                initialSummary: visit,
                currentUserId: authModel.authenticatedUser?.id,
                dataManager: dataManager
            )
        }
    }

    @ViewBuilder
    private var remoteContent: some View {
        if isLoadingRemoteVisits {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.mugshotSage)

                Text("Loading real visits...")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
        } else if let remoteVisitError {
            VStack(spacing: 10) {
                Text("Could not load real visits")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)

                Text(remoteVisitError)
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.65))
                    .multilineTextAlignment(.center)

                Button("Retry") {
                    Task {
                        await loadRemoteVisits()
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
            ProfileEmptyStateCard(
                asset: .noCafes,
                systemImage: "cup.and.saucer.fill",
                title: "No visits yet",
                message: "Save a real visit from Add. It will appear here, open in detail, and persist after relaunch."
            )
        } else {
            ForEach(remoteVisits) { visit in
                Button {
                    selectedRemoteVisit = visit
                } label: {
                    RemoteVisitSummaryCard(visit: visit)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(visit.visit.drinkDisplayName) at \(visit.locationTitle)")
                .accessibilityHint("Opens visit details")
            }
        }
    }

    @ViewBuilder
    private var localContent: some View {
        if localVisits.isEmpty {
            ProfileEmptyStateCard(
                asset: .noCafes,
                systemImage: "cup.and.saucer.fill",
                title: "No local visits yet",
                message: "Log a visit to start filling your taste journal."
            )
        } else {
            ForEach(localVisits) { visit in
                if dataManager.getCafe(id: visit.cafeId) != nil {
                    VisitCard(visit: visit, dataManager: dataManager, selectedScope: .friends)
                        .onTapGesture {
                            selectedVisit = visit
                            showVisitDetail = true
                        }
                }
            }
        }
    }

    private func loadRemoteVisits() async {
        guard let userId = authModel.authenticatedUser?.id else {
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
            let visits = try await service.fetchRecentVisits(userId: userId)
            remoteVisits = visits
            isLoadingRemoteVisits = false
        } catch {
            remoteVisits = []
            remoteVisitError = error.localizedDescription
            isLoadingRemoteVisits = false
        }
    }
}

struct ProfileEmptyStateCard: View {
    let asset: MugsyEmptyStateAsset?
    let systemImage: String
    let title: String
    let message: String

    init(
        asset: MugsyEmptyStateAsset? = nil,
        systemImage: String,
        title: String,
        message: String
    ) {
        self.asset = asset
        self.systemImage = systemImage
        self.title = title
        self.message = message
    }

    var body: some View {
        if let asset {
            MugsyEmptyStateView(asset: asset, title: title, message: message)
        } else {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.36))
                .frame(width: 52, height: 52)
                .background(Color.sandBeige.opacity(0.45))
                .clipShape(Circle())

            Text(title)
                .mugshotDisplay(size: 20)
                .foregroundColor(.espressoBrown)

            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
        }
    }
}

struct RemoteVisitSummaryCard: View {
    let visit: RemoteVisitSummary

    private var hasPhoto: Bool {
        visit.visit.posterPhotoURL != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasPhoto {
                poster
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        scoreBadge
                            .padding(10)
                    }
                    .padding([.top, .horizontal], 12)
            }

            HStack(alignment: .top, spacing: 12) {
                if !hasPhoto {
                    poster
                        .frame(width: 76, height: 76)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(visit.locationTitle)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.espressoBrown)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            if let subtitle = visit.locationSubtitle {
                                Text(subtitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.espressoBrown.opacity(0.6))
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        if !hasPhoto {
                            scoreBadge
                        }
                    }

                    Text(visit.visit.drinkDisplayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                        .lineLimit(2)

                    if !visit.visit.caption.isEmpty {
                        Text(visit.visit.caption)
                            .font(.system(size: 13))
                            .foregroundColor(.espressoBrown.opacity(0.68))
                            .lineLimit(2)
                    }

                    metadataRow
                }
            }
            .padding(12)
        }
        .cardStyle()
    }

    private var poster: some View {
        Group {
            if visit.visit.posterPhotoURL != nil {
                RemotePhotoImageView(
                    urlString: visit.visit.posterPhotoURL,
                    placeholderSystemName: "photo"
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
            } else {
                RemoteVisitNoPhotoThumbnail()
            }
        }
    }

    private var scoreBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 11))
            Text(String(format: "%.1f", visit.visit.overallScore))
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(.espressoBrown)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.mugshotSage.opacity(0.45))
        .cornerRadius(999)
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            Label(formatDate(visit.visit.createdAtDate), systemImage: "clock.fill")
            Text("•")
            Label(visit.visit.backendVisibilityLabel, systemImage: visibilityIcon)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.35))
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.espressoBrown.opacity(0.55))
        .lineLimit(1)
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

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct RemoteVisitNoPhotoThumbnail: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.4))

            Text("No photo")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sandBeige.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))
    }
}

struct TopCafesView: View {
    @ObservedObject var dataManager: DataManager
    let remoteStats: RemoteProfileStats?

    var topCafes: [Cafe] {
        dataManager.appData.cafes
            .filter { $0.averageRating > 0 }
            .sorted { $0.averageRating > $1.averageRating }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let remoteStats {
                if remoteStats.topCafes.isEmpty {
                    ProfileEmptyStateCard(
                        asset: .noCafes,
                        systemImage: "cup.and.saucer.fill",
                        title: "No top cafés yet",
                        message: "Photo-backed remote visits will rank your cafés here."
                    )
                } else {
                    ForEach(remoteStats.topCafes) { topCafe in
                        RemoteTopCafeCard(topCafe: topCafe)
                    }
                }
            } else if topCafes.isEmpty {
                ProfileEmptyStateCard(
                    asset: .noCafes,
                    systemImage: "cup.and.saucer.fill",
                    title: "No cafés yet",
                    message: "Log visits to rank your cafés."
                )
            } else {
                ForEach(topCafes) { cafe in
                    CafeCard(
                        cafe: cafe,
                        dataManager: dataManager,
                        showWantToTryTag: false,
                        onLogVisit: {},
                        onShowDetails: {}
                    )
                }
            }
        }
    }
}

struct RemoteTopCafeCard: View {
    let topCafe: RemoteTopCafe

    var body: some View {
        HStack(spacing: 12) {
            RemotePhotoImageView(
                urlString: topCafe.posterPhotoURL,
                placeholderSystemName: "cup.and.saucer.fill"
            )
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))

            VStack(alignment: .leading, spacing: 6) {
                Text(topCafe.cafe.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.espressoBrown)
                    .lineLimit(2)

                if !topCafe.cafe.displayLocation.isEmpty {
                    Text(topCafe.cafe.displayLocation)
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.62))
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Label(String(format: "%.1f", topCafe.averageScore), systemImage: "star.fill")
                    Label("\(topCafe.visitCount)", systemImage: "cup.and.saucer.fill")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.68))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .cardStyle()
    }
}

struct FavoritesView: View {
    @ObservedObject var dataManager: DataManager

    var favorites: [Cafe] {
        dataManager.appData.cafes.filter { $0.isFavorite }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if favorites.isEmpty {
                Text("No favorites yet")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(favorites) { cafe in
                    CafeCard(
                        cafe: cafe,
                        dataManager: dataManager,
                        showWantToTryTag: false,
                        onLogVisit: {},
                        onShowDetails: {}
                    )
                }
            }
        }
    }
}

struct WishlistView: View {
    @ObservedObject var dataManager: DataManager

    var wishlist: [Cafe] {
        dataManager.appData.cafes.filter { $0.wantToTry }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if wishlist.isEmpty {
                Text("No wishlist items yet")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(wishlist) { cafe in
                    CafeCard(
                        cafe: cafe,
                        dataManager: dataManager,
                        showWantToTryTag: true,
                        onLogVisit: {},
                        onShowDetails: {}
                    )
                }
            }
        }
    }
}
