import SwiftUI
import UIKit

struct SavedCafeComfortableCard: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    let communityImageURL: String?
    let isSyncing: Bool
    let onOpen: () -> Void
    let onFavorite: () -> Void
    let onWantToTry: () -> Void
    let onLogSip: () -> Void
    let onLists: () -> Void
    let onShowMap: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var visits: [Visit] { dataManager.getVisitsForCafe(cafe.id) }
    private var visitCount: Int { max(cafe.visitCount, visits.count) }
    private var personalScore: Double? {
        let scores = visits.map(\.overallScore).filter { $0 > 0 }
        if !scores.isEmpty { return scores.reduce(0, +) / Double(scores.count) }
        return cafe.averageRating > 0 ? cafe.averageRating : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityContent
            } else {
                standardContent
            }

            Divider().overlay(Color.mugshotLine)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        logSipButton
                        cafeOverflowMenu(
                            cafe: cafe,
                            onLogSip: onLogSip,
                            onLists: onLists,
                            onShowMap: onShowMap,
                            showsLabel: true
                        )
                    }
                } else {
                    HStack(spacing: 10) {
                        logSipButton
                        Spacer(minLength: 4)
                        cafeOverflowMenu(
                            cafe: cafe,
                            onLogSip: onLogSip,
                            onLists: onLists,
                            onShowMap: onShowMap
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.card).stroke(Color.mugshotLine))
        .shadow(color: DesignSystem.cardShadow.color, radius: 12, y: 4)
        .opacity(isSyncing ? 0.82 : 1)
        .animation(DesignSystem.Motion.fast, value: isSyncing)
        .accessibilityIdentifier("saved.cafe.card.\(cafe.id.uuidString)")
    }

    private var logSipButton: some View {
        Button(action: onLogSip) {
            Label("Log a Sip", systemImage: "plus.circle")
                .font(.headline)
                .foregroundColor(.foamWhite)
                .padding(.horizontal, 16)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 72 : 48)
                .background(Color.mugshotSageText, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Starts a sip with this cafe selected")
    }

    private var standardContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 12) {
                    SavedCafeImage(
                        cafe: cafe,
                        dataManager: dataManager,
                        communityImageURL: communityImageURL,
                        size: 96
                    )

                    identity
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(cafeAccessibilityLabel)
            .accessibilityHint("Opens cafe details")

            VStack(spacing: 8) {
                savedStateButton(
                    label: cafe.isFavorite ? "Favorited" : "Favorite",
                    systemImage: cafe.isFavorite ? "heart.fill" : "heart",
                    isSelected: cafe.isFavorite,
                    action: onFavorite
                )
                savedStateButton(
                    label: cafe.wantToTry ? "Saved to try" : "Want to Try",
                    systemImage: cafe.wantToTry ? "bookmark.fill" : "bookmark",
                    isSelected: cafe.wantToTry,
                    action: onWantToTry
                )
            }
        }
        .padding(12)
    }

    private var accessibilityContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 12) {
                    SavedCafeImage(
                        cafe: cafe,
                        dataManager: dataManager,
                        communityImageURL: communityImageURL,
                        size: 104
                    )
                    identity
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(cafeAccessibilityLabel)
            .accessibilityHint("Opens cafe details")

            VStack(spacing: 8) {
                fullWidthStateButton(
                    label: cafe.isFavorite ? "Favorited" : "Favorite",
                    systemImage: cafe.isFavorite ? "heart.fill" : "heart",
                    isSelected: cafe.isFavorite,
                    action: onFavorite
                )
                fullWidthStateButton(
                    label: cafe.wantToTry ? "Want to Try selected" : "Want to Try",
                    systemImage: cafe.wantToTry ? "bookmark.fill" : "bookmark",
                    isSelected: cafe.wantToTry,
                    action: onWantToTry
                )
            }
        }
        .padding(14)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(cafe.consumerDisplayName)
                .font(.headline)
                .foregroundColor(.espressoBrown)
                .fixedSize(horizontal: false, vertical: true)

            if let locationLabel {
                Text(locationLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }

            Text(personalSignal)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.mugshotSageText)
                .fixedSize(horizontal: false, vertical: true)

            if !membershipReasons.isEmpty {
                Text(membershipReasons.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var locationLabel: String? {
        cafe.address.remoteTrimmedNonEmpty ?? cafe.consumerPlaceCategory
    }

    private var personalSignal: String {
        if let personalScore {
            return "You \(String(format: "%.1f", personalScore)) · \(visitCount) \(visitCount == 1 ? "sip" : "sips")"
        }
        return visitCount > 0
            ? "\(visitCount) \(visitCount == 1 ? "sip" : "sips")"
            : "Not rated · No sips yet"
    }

    private var membershipReasons: [String] {
        var values: [String] = []
        if cafe.isFavorite { values.append("Favorite") }
        if cafe.wantToTry { values.append("Want to Try") }
        if visitCount > 0 { values.append("Visited") }
        return values
    }

    private var cafeAccessibilityLabel: String {
        [cafe.consumerDisplayName, locationLabel, personalSignal, membershipReasons.joined(separator: ", ")]
            .compactMap { $0?.remoteTrimmedNonEmpty }
            .joined(separator: ", ")
    }

    private func savedStateButton(
        label: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isSelected ? .mugshotSageText : .espressoBrown)
                .frame(width: 48, height: 48)
                .background(isSelected ? Color.mugshotMint.opacity(0.34) : Color.foamWhite)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.mugshotSageText : Color.mugshotLine, lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .disabled(isSyncing)
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func fullWidthStateButton(
        label: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .foregroundColor(isSelected ? .mugshotSageText : .espressoBrown)
                .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 72 : 48, alignment: .leading)
                .padding(.horizontal, 14)
                .background(isSelected ? Color.mugshotMint.opacity(0.34) : Color.sandBeige.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.mugshotSageText : Color.mugshotLine))
        }
        .buttonStyle(.plain)
        .disabled(isSyncing)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

struct SavedCafeCompactRow: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    let communityImageURL: String?
    let isSyncing: Bool
    let onOpen: () -> Void
    let onFavorite: () -> Void
    let onWantToTry: () -> Void
    let onLogSip: () -> Void
    let onLists: () -> Void
    let onShowMap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    SavedCafeImage(
                        cafe: cafe,
                        dataManager: dataManager,
                        communityImageURL: communityImageURL,
                        size: 64
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cafe.consumerDisplayName)
                            .font(.headline)
                            .foregroundColor(.espressoBrown)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(compactMetadata)
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(compactAccessibilityLabel)
            .accessibilityHint("Opens cafe details")

            Spacer(minLength: 2)
            compactStateButton(
                systemImage: cafe.isFavorite ? "heart.fill" : "heart",
                selected: cafe.isFavorite,
                label: cafe.isFavorite ? "Favorited" : "Favorite",
                action: onFavorite
            )
            compactStateButton(
                systemImage: cafe.wantToTry ? "bookmark.fill" : "bookmark",
                selected: cafe.wantToTry,
                label: cafe.wantToTry ? "Saved to try" : "Want to Try",
                action: onWantToTry
            )
            cafeOverflowMenu(cafe: cafe, onLogSip: onLogSip, onLists: onLists, onShowMap: onShowMap)
        }
        .padding(10)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.card).stroke(Color.mugshotLine))
        .opacity(isSyncing ? 0.82 : 1)
        .accessibilityIdentifier("saved.cafe.row.\(cafe.id.uuidString)")
    }

    private var compactMetadata: String {
        let count = max(cafe.visitCount, dataManager.getVisitsForCafe(cafe.id).count)
        let state = [cafe.isFavorite ? "Favorite" : nil, cafe.wantToTry ? "Want to Try" : nil, count > 0 ? "Visited" : nil]
            .compactMap { $0 }
            .joined(separator: " · ")
        return [cafe.address.remoteTrimmedNonEmpty, state.remoteTrimmedNonEmpty]
            .compactMap { $0 }
            .joined(separator: "\n")
    }

    private var compactAccessibilityLabel: String {
        [cafe.consumerDisplayName, compactMetadata.remoteTrimmedNonEmpty]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func compactStateButton(systemImage: String, selected: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(selected ? .mugshotSageText : .espressoBrown)
                .frame(width: 44, height: 44)
                .background(selected ? Color.mugshotMint.opacity(0.30) : Color.clear, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .disabled(isSyncing)
        .accessibilityLabel(label)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct SavedCafeImage: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    let communityImageURL: String?
    let size: CGFloat

    private var imagePath: String? {
        CafePhotoSelection.mostRecentLocalPosterPath(
            in: dataManager.getVisitsForCafe(cafe.id)
        )
    }

    private var resolvedCommunityImageURL: String? {
        communityImageURL?.remoteTrimmedNonEmpty
    }

    private var scene: MugsyScene {
        MugsySceneResolver.cafePhoto(
            stableID: cafe.id.uuidString,
            origin: .library,
            isFavorite: cafe.isFavorite,
            wantToTry: cafe.wantToTry,
            hasVisited: max(cafe.visitCount, dataManager.getVisitsForCafe(cafe.id).count) > 0
        )
    }

    var body: some View {
        Group {
            if let imagePath {
                PhotoThumbnailView(photoPath: imagePath, size: size)
            } else if let communityImageURL = resolvedCommunityImageURL {
                RemotePhotoImageView(
                    urlString: communityImageURL,
                    placeholderSystemName: "photo",
                    contentMode: .fill
                )
            } else {
                MugsyPhotoPlaceholderView(
                    scene: scene,
                    style: size >= 90 ? .card : .thumbnail,
                    photoDescription: "No cafe photo yet"
                )
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: size >= 90 ? 16 : 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size >= 90 ? 16 : 12).stroke(Color.mugshotLine))
        .accessibilityLabel(imagePath == nil && resolvedCommunityImageURL == nil ? "No cafe photo yet" : "Cafe photo")
    }
}

struct SavedCafeCardPlaceholder: View {
    let density: SavedCafeDensity

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.sandBeige)
                .frame(width: density == .cards ? 96 : 64, height: density == .cards ? 96 : 64)
            VStack(alignment: .leading, spacing: 9) {
                RoundedRectangle(cornerRadius: 5).fill(Color.sandBeige).frame(height: 18)
                RoundedRectangle(cornerRadius: 4).fill(Color.sandBeige).frame(width: 170, height: 13)
                RoundedRectangle(cornerRadius: 4).fill(Color.sandBeige).frame(width: 130, height: 13)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mugshotLine))
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading cafe")
    }
}

@ViewBuilder
private func cafeOverflowMenu(
    cafe: Cafe,
    onLogSip: @escaping () -> Void,
    onLists: @escaping () -> Void,
    onShowMap: @escaping () -> Void,
    showsLabel: Bool = false
) -> some View {
    Menu {
        Button(action: onLogSip) {
            Label("Log a Sip", systemImage: "plus.circle")
        }
        Button(action: onLists) {
            Label("Lists", systemImage: "rectangle.stack")
        }
        Button(action: onShowMap) {
            Label("Show on Map", systemImage: "map")
        }
        Button {
            openCafeDirections(cafe)
        } label: {
            Label("Directions", systemImage: "location.north")
        }
        .disabled(cafe.location == nil)
        ShareLink(item: shareText(for: cafe)) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    } label: {
        Group {
            if showsLabel {
                Label("More actions", systemImage: "ellipsis")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(Color.sandBeige.opacity(0.58), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
        }
        .foregroundColor(.roastBrown)
    }
    .accessibilityLabel("More actions for \(cafe.consumerDisplayName)")
}

private func openCafeDirections(_ cafe: Cafe) {
    guard let location = cafe.location else { return }
    if let mapItemURL = cafe.mapItemURL, let url = URL(string: mapItemURL) {
        UIApplication.shared.open(url)
        return
    }
    let name = cafe.consumerDisplayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Cafe"
    if let url = URL(string: "https://maps.apple.com/?ll=\(location.latitude),\(location.longitude)&q=\(name)") {
        UIApplication.shared.open(url)
    }
}

private func shareText(for cafe: Cafe) -> String {
    [cafe.consumerDisplayName, cafe.address.remoteTrimmedNonEmpty]
        .compactMap { $0 }
        .joined(separator: " — ")
}

struct CafeListMembershipSheet: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    var onAuthenticationRequired: ((_ title: String, _ message: String) -> Void)? = nil

    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [CafeListMembershipRow] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var workingListID: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading, rows.isEmpty {
                    MugshotLoadingState(layout: .collection, count: 4)
                        .padding(16)
                } else if let errorMessage, rows.isEmpty {
                    MugshotRecoveryCard(
                        title: "Cafe lists need another try",
                        message: errorMessage,
                        actionTitle: "Retry"
                    ) {
                        Task { await load() }
                    }
                    .padding(16)
                } else if rows.isEmpty {
                    VStack(spacing: 14) {
                        MugsyModelView(
                            configuration: MugsySceneFamily.happyBuilder.configuration
                        )
                        .frame(width: 124, height: 124)
                        Text("No cafe lists yet")
                            .mugshotDisplay(size: 24)
                        Text("Create lists from Saved, then return here to add this cafe.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                } else {
                    List {
                        Section {
                            ForEach(rows) { row in
                                CafeListMembershipRowView(
                                    row: row,
                                    isWorking: workingListID == row.id
                                ) {
                                    Task { await toggle(row) }
                                }
                            }
                        } header: {
                            Text("Add \(cafe.consumerDisplayName) to lists")
                        } footer: {
                            Text("List creation, collaborators, editing, maps, ownership, and deletion stay in the existing Lists experience.")
                        }

                        if let errorMessage {
                            Section {
                                Label(errorMessage, systemImage: "exclamationmark.circle")
                                    .foregroundColor(.roastBrown)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.creamWhite)
            .navigationTitle("Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @MainActor
    private func load() async {
        guard let accountID = authModel.authenticatedUser?.id else {
            isLoading = false
            onAuthenticationRequired?(
                "Keep cafe lists in sync",
                "Sign in to add this cafe to a private or shared list."
            )
            dismiss()
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let service = CollaborativeCafeListService(client: try SupabaseClientProvider.shared.client())
            let summaries = try await service.lists(accountID: accountID)
                .filter { $0.accessKind != .pendingInvitation }
            var loadedRows: [CafeListMembershipRow] = []
            for summary in summaries {
                try Task.checkCancellation()
                let detail = summary.canViewItems
                    ? (try? await service.list(id: summary.id, accountID: accountID))
                    : nil
                let remoteCafeID = dataManager.getCafe(id: cafe.id)?.remoteCafeId ?? cafe.remoteCafeId
                let item = remoteCafeID.flatMap { id in
                    detail?.resolvedItems.first { $0.cafeID == id }
                }
                loadedRows.append(CafeListMembershipRow(
                    list: detail ?? summary,
                    itemID: item?.id,
                    errorMessage: nil
                ))
            }
            rows = loadedRows.sorted { $0.list.title.localizedCaseInsensitiveCompare($1.list.title) == .orderedAscending }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
    }

    @MainActor
    private func toggle(_ row: CafeListMembershipRow) async {
        guard workingListID == nil,
              let accountID = authModel.authenticatedUser?.id else { return }
        workingListID = row.id
        errorMessage = nil
        defer { workingListID = nil }
        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = CollaborativeCafeListService(client: client)
            if let itemID = row.itemID {
                try await service.remove(itemID: itemID, accountID: accountID)
            } else {
                let remoteCafe = try await CafeService(client: client).findOrCreateCafe(from: cafe)
                dataManager.upsertRemoteCafe(remoteCafe)
                try await service.add(cafeID: remoteCafe.id, to: row.id, accountID: accountID)
            }
            let refreshed = try await service.list(id: row.id, accountID: accountID)
            let targetID = cafe.remoteCafeId
                ?? dataManager.getCafe(id: cafe.id)?.remoteCafeId
            let item = targetID.flatMap { id in refreshed.resolvedItems.first { $0.cafeID == id } }
            if let index = rows.firstIndex(where: { $0.id == row.id }) {
                rows[index] = CafeListMembershipRow(list: refreshed, itemID: item?.id, errorMessage: nil)
            }
        } catch {
            let message = MugshotUserFacingError.message(for: error, context: .social)
            if let index = rows.firstIndex(where: { $0.id == row.id }) {
                rows[index] = CafeListMembershipRow(
                    list: rows[index].list,
                    itemID: rows[index].itemID,
                    errorMessage: message
                )
            }
            errorMessage = "One list could not be updated. Your other memberships are unchanged."
        }
    }
}

private struct CafeListMembershipRow: Identifiable {
    let list: CollaborativeCafeList
    let itemID: UUID?
    let errorMessage: String?
    var id: UUID { list.id }
    var isMember: Bool { itemID != nil }
    var canEdit: Bool { list.canEditItems && list.socialActionsAvailable }
}

private struct CafeListMembershipRowView: View {
    let row: CafeListMembershipRow
    let isWorking: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: row.isMember ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(row.isMember ? .mugshotSageText : .tertiaryText)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.list.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    Text(row.canEdit ? row.list.roleTitle : "\(row.list.roleTitle) · Read-only")
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                    if let error = row.errorMessage {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.roastBrown)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                if isWorking {
                    ProgressView().tint(.mugshotSageText)
                } else if !row.canEdit {
                    Image(systemName: "lock.fill").foregroundColor(.tertiaryText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!row.canEdit || isWorking)
        .accessibilityLabel("\(row.list.title), \(row.isMember ? "selected" : "not selected"), \(row.list.roleTitle)")
        .accessibilityHint(row.canEdit ? "Double tap to change membership" : "This list is read-only")
        .accessibilityAddTraits(row.isMember ? .isSelected : [])
    }
}
