import SwiftUI

struct ReactionPeopleView: View {
    let visitID: UUID
    let dataManager: DataManager
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    @State private var filter: PostReactionKind?
    @State private var people: [ReactionPeoplePage.Person] = []
    @State private var counts: VisitReactionState?
    @State private var cursor: ReactionPeoplePage.Cursor?
    @State private var loading = false
    @State private var error: String?
    @State private var requestID = UUID()
    @State private var profile: PeopleProfileRoute?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            filterButton(nil, title: "All \(counts?.totalCount ?? 0)")
                            ForEach(PostReactionKind.allCases) { kind in
                                if (counts?.count(for: kind) ?? 0) > 0 || filter == kind {
                                    filterButton(kind, title: "\(kind.title) \(counts?.count(for: kind) ?? 0)")
                                }
                            }
                        }.padding(.vertical, 6)
                    }
                }
                ForEach(people) { person in
                    Button {
                        profile = PeopleProfileRoute(id: person.user_id, displayName: person.display_name,
                            username: person.username, state: person.user_id == authModel.authenticatedUser?.id ? .self : .none)
                    } label: {
                        HStack(spacing: 12) {
                            MugshotAvatar(name: person.display_name, size: 44, imageURL: person.avatar_url)
                            VStack(alignment: .leading) {
                                Text(person.display_name).font(.headline)
                                Text("@\(person.username)").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: person.reaction_kind.systemImage).foregroundStyle(Color.mugshotSage)
                                .accessibilityLabel(person.reaction_kind.title)
                        }
                    }.buttonStyle(.plain)
                }
                if let error {
                    Text(error).foregroundStyle(.secondary)
                    Button("Try again") { Task { await load(more: false) } }
                } else if !loading && people.isEmpty { Text("No reactions yet.") }
                if loading { ProgressView("Loading reactions…") }
                if cursor != nil && !loading { Button("Load more") { Task { await load(more: true) } } }
            }
            .navigationTitle("Reactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .navigationDestination(item: $profile) { route in
                PublicProfileView(route: route, dataManager: dataManager, onRelationshipChanged: { await load(more: false) })
            }
            .task(id: filter) { await load(more: false) }
            .refreshable { await load(more: false) }
            .onChange(of: authModel.authenticatedUser?.id) { _, _ in dismiss() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func filterButton(_ kind: PostReactionKind?, title: String) -> some View {
        Button { filter = kind } label: {
            HStack {
                if let kind { Image(systemName: kind.systemImage) }
                Text(title).fontWeight(filter == kind ? .bold : .regular)
            }
            .foregroundStyle(filter == kind ? Color.mugshotSage : Color.primary)
        }.buttonStyle(.plain).accessibilityAddTraits(filter == kind ? .isSelected : [])
    }

    @MainActor private func load(more: Bool) async {
        let token = UUID(); requestID = token; loading = true; error = nil
        if !more { people = []; cursor = nil }
        defer { if requestID == token { loading = false } }
        do {
            let page = try await ReactionPeopleService().page(visitID: visitID, kind: filter, cursor: more ? cursor : nil)
            guard token == requestID else { return }
            let existing = Set(people.map(\.id))
            people += page.people.filter { !existing.contains($0.id) }
            counts = page.counts; cursor = page.next_cursor
        } catch {
            guard !Task.isCancelled, token == requestID else { return }
            self.error = "Couldn’t load reactions. Please try again."
        }
    }
}
