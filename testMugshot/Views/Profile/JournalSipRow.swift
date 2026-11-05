import SwiftUI

/// One visual hierarchy for every Journal sip, including private Home memories.
struct JournalSipRowContent {
    let id: String
    let context: JournalEntryContext
    let date: Date
    let locationName: String
    let drinkName: String
    let score: Double?
    var locationControlID: String? = nil

    var normalizedContext: JournalEntryContext { context == .recipe ? .home : context }
    var contextTitle: String { normalizedContext == .cafe ? "Cafe Sip" : normalizedContext.rawValue }
}

struct JournalSipRow<Thumbnail: View>: View {
    let content: JournalSipRowContent
    var onOpen: (() -> Void)?
    var onLocationTap: (() -> Void)?
    var trailingSymbol: String
    var trailingLabel: String?
    var trailingAction: (() -> Void)?
    @ViewBuilder let thumbnail: Thumbnail
    @ScaledMetric(relativeTo: .headline) private var placeSize = 19
    @Environment(\.dynamicTypeSize) private var typeSize

    init(content: JournalSipRowContent, onOpen: (() -> Void)? = nil,
         onLocationTap: (() -> Void)? = nil, trailingSymbol: String = "chevron.right",
         trailingLabel: String? = nil, trailingAction: (() -> Void)? = nil,
         @ViewBuilder thumbnail: () -> Thumbnail) {
        self.content = content; self.onOpen = onOpen; self.onLocationTap = onLocationTap
        self.trailingSymbol = trailingSymbol; self.trailingLabel = trailingLabel; self.trailingAction = trailingAction
        self.thumbnail = thumbnail()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            openControl {
                thumbnail.frame(width: 92, height: 96).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
            }
            .frame(width: 92, height: 96)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Open \(content.drinkName) photo")
            .accessibilityIdentifier("journal.thumbnail.\(content.id)")

            VStack(alignment: .leading, spacing: 3) {
                metadata
                location
                openControl(label: "Open \(content.drinkName), \(scoreDescription)") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(content.drinkName)
                            .font(.subheadline.weight(.medium)).foregroundStyle(Color.secondaryText)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                        if let score = content.score {
                            Label(score.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                                .font(.caption.weight(.bold)).foregroundStyle(Color.mugshotSageText)
                        } else {
                            Text("Unrated").font(.caption).foregroundStyle(Color.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingControl
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.sip.\(content.id)")
    }

    private var metadata: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) {
                Label(content.contextTitle, systemImage: content.normalizedContext.systemImage)
                Text("·")
                Text(content.date, style: .date)
            }
            VStack(alignment: .leading, spacing: 3) {
                Label(content.contextTitle, systemImage: content.normalizedContext.systemImage)
                Text(content.date, style: .date)
            }
        }
        .font(.caption2.weight(.semibold)).foregroundStyle(Color.mugshotSageText)
    }

    @ViewBuilder private var trailingControl: some View {
        if let trailingAction {
            Button(action: trailingAction) {
                Image(systemName: trailingSymbol).font(.caption.weight(.bold))
                    .foregroundStyle(Color.mugshotSageText).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(trailingLabel ?? "Bookmark sip")
            .accessibilityIdentifier("journal.bookmark.\(content.id)")
        } else {
            openControl {
                Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    .foregroundStyle(Color.tertiaryText).frame(width: 44, height: 44)
            }
        }
    }

    @ViewBuilder private var location: some View {
        if let onLocationTap {
            Button(action: onLocationTap) {
                HStack(spacing: 5) {
                    locationTitle
                    Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(content.locationControlID ?? "journal.location.\(content.id)")
            .accessibilityLabel("Open \(content.locationName) cafe details")
            .accessibilityHint("Opens this cafe")
        } else {
            openControl(label: "Open \(content.drinkName) at \(content.locationName)") {
                locationTitle.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
    }

    private var locationTitle: some View {
        Text(content.locationName).mugshotDisplay(size: placeSize)
            .foregroundStyle(Color.espressoBrown)
            .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
    }

    private var scoreDescription: String {
        content.score.map { $0.formatted(.number.precision(.fractionLength(1))) + " out of 5" } ?? "Unrated"
    }

    @ViewBuilder private func openControl<Content: View>(label: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        if let onOpen {
            Button(action: onOpen, label: content).buttonStyle(.plain)
                .accessibilityLabel(label ?? "Open \(self.content.drinkName)")
                .accessibilityHint("Opens this Mugshot")
                .accessibilityIdentifier("journal.open.\(self.content.id)")
        } else { content() }
    }
}

struct PrivateHomeJournalRow: View {
    let attempt: HomeAttemptRecord
    var photo: UIImage?
    let onOpen: () -> Void

    var body: some View {
        JournalSipRow(content: JournalSipRowContent(id: "home-\(attempt.id)", context: .home,
            date: attempt.journalDate, locationName: attempt.journalLocationName,
            drinkName: attempt.name, score: attempt.resolvedRating), onOpen: onOpen) {
            if let photo { Image(uiImage: photo).resizable().scaledToFill() }
            else { RemoteVisitNoPhotoThumbnail(usesMugsyFallback: true, stableID: attempt.id.uuidString) }
        }
    }
}

/// Resolve a private photo once per scope/source change, outside view construction.
/// A scope switch immediately removes the old text and image from this row.
struct HomeJournalEntryRow: View {
    let attempt: HomeAttemptRecord
    let scope: LocalAccountScope
    let onOpen: () -> Void
    @ObservedObject private var store = HomeRecipeWorkspaceStore.shared
    @State private var photo: UIImage?

    var body: some View {
        Group {
            if store.scope == scope { PrivateHomeJournalRow(attempt: attempt, photo: photo, onOpen: onOpen) }
        }
        .task(id: "\(scope.storageComponent):\(attempt.photoNames.joined(separator: ","))") {
            guard store.scope == scope else { photo = nil; return }
            photo = attempt.photoNames.lazy.compactMap { store.photo($0) }.first
        }
        .onChange(of: store.scope) { _, _ in photo = nil }
    }
}

struct HomeJournalPhotoThumbnail: View {
    let attempt: HomeAttemptRecord
    let scope: LocalAccountScope
    @ObservedObject private var store = HomeRecipeWorkspaceStore.shared
    @State private var photo: UIImage?

    var body: some View {
        Group {
            if store.scope == scope {
                if let photo { Image(uiImage: photo).resizable().scaledToFill() }
                else { RemoteVisitNoPhotoThumbnail(usesMugsyFallback: true, stableID: attempt.id.uuidString) }
            } else { Color.clear }
        }
        .task(id: "\(scope.storageComponent):\(attempt.photoNames.joined(separator: ","))") {
            guard store.scope == scope else { photo = nil; return }
            photo = attempt.photoNames.lazy.compactMap { store.photo($0) }.first
        }
        .onChange(of: store.scope) { _, _ in photo = nil }
    }
}

enum JournalHistoryItem: Identifiable {
    case published(JournalEntryProjection)
    case privateHome(HomeAttemptRecord)

    var id: String {
        switch self {
        case .published(let entry): "visit-\(entry.id)"
        case .privateHome(let attempt): "home-\(attempt.id)"
        }
    }
    var date: Date {
        switch self {
        case .published(let entry): entry.date
        case .privateHome(let attempt): attempt.journalDate
        }
    }
    var drinkName: String {
        switch self {
        case .published(let entry): entry.summary.visit.drinkDisplayName
        case .privateHome(let attempt): attempt.name
        }
    }
    var published: JournalEntryProjection? { if case .published(let value) = self { value } else { nil } }
    var privateHome: HomeAttemptRecord? { if case .privateHome(let value) = self { value } else { nil } }
}

enum JournalHistoryProjection {
    static func ordered(entries: [JournalEntryProjection], privateHome: [HomeAttemptRecord]) -> [JournalHistoryItem] {
        let canonical = Set(entries.map(\.id))
        let local = privateHome.filter {
            !canonical.contains($0.id) && !($0.publicationDraftID.map(canonical.contains) ?? false)
        }.map(JournalHistoryItem.privateHome)
        return (entries.map(JournalHistoryItem.published) + local).sorted {
            $0.date == $1.date ? $0.id < $1.id : $0.date > $1.date
        }
    }

    static func onDay(_ date: Date, items: [JournalHistoryItem], calendar: Calendar = .current) -> [JournalHistoryItem] {
        items.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

enum HomeJournalSearch {
    static func matches(_ attempt: HomeAttemptRecord, query: String) -> Bool {
        guard let query = query.remoteTrimmedNonEmpty else { return true }
        let preparation = attempt.preparation ?? attempt.targets
        var terms = [attempt.name, attempt.journalLocationName, attempt.reaction, attempt.privateNote,
                     attempt.nextTimeNote, preparation?.name ?? "", preparation?.methodDisplayName ?? "",
                     preparation?.coffee?.displayName ?? "", preparation?.coffee?.origin ?? ""]
        terms += preparation?.tags ?? []
        terms += preparation?.equipment.map(\.displayName) ?? []
        return terms.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    static func matchesCoffee(_ attempt: HomeAttemptRecord, id: UUID, legacySnapshot: CoffeeBagSnapshot?) -> Bool {
        if let recorded = attempt.homeCoffeeBagID { return recorded == id }
        guard let legacySnapshot else { return false }
        let content = attempt.preparation ?? attempt.targets
        return (content?.coffee ?? content?.legacyDetails?.coffeeBag) == legacySnapshot
    }
}
