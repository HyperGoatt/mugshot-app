import CoreLocation
import MapKit
import SwiftUI

private struct ProfileFavoriteSpotDraft: Identifiable, Equatable {
    let id: UUID
    var cafe: Cafe
    var descriptor: String
    var coverPhotoURL: String?

    init(cafe: Cafe, descriptor: String, coverPhotoURL: String? = nil) {
        id = cafe.remoteCafeId ?? cafe.id
        self.cafe = cafe
        self.descriptor = descriptor
        self.coverPhotoURL = coverPhotoURL
    }
}

private enum ProfileFavoriteSpotEditorSheet: Identifiable, Equatable {
    case addDescriptor(String?)
    case chooseCafe(String)
    case editDescriptor(UUID)

    var id: String {
        switch self {
        case .addDescriptor(let descriptor): "add-descriptor-\(descriptor ?? "new")"
        case .chooseCafe(let descriptor): "choose-cafe-\(descriptor)"
        case .editDescriptor(let id): "edit-descriptor-\(id.uuidString)"
        }
    }
}

@MainActor
struct ProfileFavoriteSpotsEditor: View {
    let dataManager: DataManager
    let onSave: ([SharedProfileFavoriteSpot]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [ProfileFavoriteSpotDraft]
    @State private var activeSheet: ProfileFavoriteSpotEditorSheet?
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        spots: [SharedProfileFavoriteSpot],
        dataManager: DataManager,
        onSave: @escaping ([SharedProfileFavoriteSpot]) -> Void
    ) {
        self.dataManager = dataManager
        self.onSave = onSave
        _drafts = State(initialValue: spots.sorted { $0.position < $1.position }.map {
            ProfileFavoriteSpotDraft(
                cafe: $0.localCafe,
                descriptor: $0.descriptor,
                coverPhotoURL: $0.coverPhotoURL
            )
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intro

                    if drafts.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                                favoriteRow(draft, position: index)
                            }
                        }
                    }

                    if drafts.count < ProfileFavoriteSpotPolicy.maximumCount {
                        Button { activeSheet = .addDescriptor(nil) } label: {
                            Label("Add a favorite spot", systemImage: "plus.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.espressoBrown)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.sandBeige.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    privacyNote

                    if let errorMessage {
                        MugshotStatusCard(
                            title: "Favorite Spots not saved",
                            message: errorMessage,
                            systemImage: "exclamationmark.triangle.fill"
                        )
                    }
                }
                .padding(18)
            }
            .background(Color.creamWhite)
            .navigationTitle("Favorite Spots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                        .fontWeight(.bold)
                        .disabled(isSaving || !isValid)
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addDescriptor(let initialDescriptor):
                    ProfileSpotDescriptorPicker(
                        cafeName: nil,
                        initialDescriptor: initialDescriptor,
                        primaryActionTitle: "Choose cafe"
                    ) { descriptor in
                        transition(to: .chooseCafe(descriptor))
                    }
                case .chooseCafe(let descriptor):
                    ProfileFavoriteCafePicker(
                        dataManager: dataManager,
                        excludedCafeIDs: Set(drafts.map(\.id)),
                        cancellationTitle: "Back",
                        onCancel: { transition(to: .addDescriptor(descriptor)) }
                    ) { cafe in
                        drafts.append(ProfileFavoriteSpotDraft(cafe: cafe, descriptor: descriptor))
                        activeSheet = nil
                    }
                case .editDescriptor(let id):
                    if let draft = drafts.first(where: { $0.id == id }) {
                        ProfileSpotDescriptorPicker(
                            cafeName: draft.cafe.name,
                            initialDescriptor: draft.descriptor,
                            primaryActionTitle: "Save"
                        ) { descriptor in
                            if let index = drafts.firstIndex(where: { $0.id == id }) {
                                drafts[index].descriptor = descriptor
                            }
                            activeSheet = nil
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("The places that feel like you")
                .mugshotDisplay(size: 27)
                .foregroundStyle(Color.espressoBrown)
            Text("Choose up to three cafes, put them in your order, and describe what each one is best for.")
                .font(.system(size: 14))
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(Color.mugshotSage)
            Text("Build your cafe shortlist")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(Color.espressoBrown)
            Text("Pick from Mugshot, your private cafe history, or search somewhere completely new.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(20)
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
    }

    private func favoriteRow(_ draft: ProfileFavoriteSpotDraft, position: Int) -> some View {
        HStack(spacing: 12) {
            RemotePhotoImageView(
                urlString: draft.coverPhotoURL,
                placeholderSystemName: "storefront.fill",
                contentMode: .fill
            )
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("SPOT \(position + 1)")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1)
                    .foregroundStyle(Color.mugshotSage)
                Text(draft.cafe.name)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(Color.espressoBrown)
                    .lineLimit(2)
                Button(draft.descriptor) { activeSheet = .editDescriptor(draft.id) }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mugshotSage)
                    .buttonStyle(.plain)
            }

            Spacer(minLength: 8)

            Menu {
                Button("Change description", systemImage: "text.cursor") {
                    activeSheet = .editDescriptor(draft.id)
                }
                if position > 0 {
                    Button("Move earlier", systemImage: "arrow.up") { move(from: position, to: position - 1) }
                }
                if position + 1 < drafts.count {
                    Button("Move later", systemImage: "arrow.down") { move(from: position, to: position + 1) }
                }
                Button("Remove", systemImage: "trash", role: .destructive) {
                    drafts.removeAll { $0.id == draft.id }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 40, height: 40)
            }
            .foregroundStyle(Color.espressoBrown)
            .accessibilityLabel("Actions for \(draft.cafe.name)")
        }
        .padding(12)
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
    }

    private var privacyNote: some View {
        Label {
            Text("Adding a spot publishes only that cafe and your description. Private Mugshots, notes, and audiences stay private.")
        } icon: {
            Image(systemName: "lock.shield.fill")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Color.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var isValid: Bool {
        ProfileFavoriteSpotPolicy.validated(
            drafts.map { ProfileFavoriteSpotInput(cafeID: $0.id, descriptor: $0.descriptor) }
        ) != nil
    }

    private func move(from source: Int, to destination: Int) {
        guard drafts.indices.contains(source), drafts.indices.contains(destination) else { return }
        withAnimation(.snappy) {
            let item = drafts.remove(at: source)
            drafts.insert(item, at: destination)
        }
    }

    private func transition(to sheet: ProfileFavoriteSpotEditorSheet) {
        activeSheet = nil
        Task { @MainActor in
            await Task.yield()
            activeSheet = sheet
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let client = try SupabaseClientProvider.shared.client()
            let cafeService = CafeService(client: client)
            var inputs: [ProfileFavoriteSpotInput] = []
            for draft in drafts {
                let remote = try await cafeService.findOrCreateCafe(from: draft.cafe)
                inputs.append(ProfileFavoriteSpotInput(cafeID: remote.id, descriptor: draft.descriptor))
            }
            let saved = try await SharedProfileService(client: client).setFavoriteSpots(inputs)
            onSave(saved)
            dismiss()
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .social)
        }
    }
}

@MainActor
private struct ProfileFavoriteCafePicker: View {
    @ObservedObject var dataManager: DataManager
    let excludedCafeIDs: Set<UUID>
    var cancellationTitle = "Cancel"
    var onCancel: (() -> Void)?
    let onSelect: (Cafe) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authModel: AppAuthModel
    @StateObject private var searchService = MapSearchService()
    @StateObject private var locationManager = LocationManager()
    @State private var query = ""
    @State private var resolvingSuggestion: String?

    private var searchRegion: MKCoordinateRegion {
        if let coordinate = locationManager.location?.coordinate ?? dataManager.appData.cafes.compactMap(\.location).first {
            return MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
            )
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
            span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 55)
        )
    }

    private var localCafes: [Cafe] {
        dataManager.appData.cafes
            .filter { !excludedCafeIDs.contains($0.remoteCafeId ?? $0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.mugshotSage)
                        TextField("Search any cafe or city", text: $query)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onSubmit { searchService.search(query: query, region: searchRegion, immediately: true) }
                    }
                } footer: {
                    Text("Choose a cafe already in Mugshot, one from your history, or a new place from Apple Maps.")
                }

                if query.remoteTrimmedNonEmpty == nil {
                    Section("From Mugshot and your history") {
                        if localCafes.isEmpty {
                            Text("Search above to add somewhere new.").foregroundStyle(Color.secondaryText)
                        } else {
                            ForEach(localCafes) { cafe in cafeButton(cafe) }
                        }
                    }
                } else {
                    if searchService.isSearching || searchService.isUpdatingSuggestions {
                        Section { HStack { ProgressView(); Text("Finding cafes…") } }
                    }

                    if !searchService.searchResults.isEmpty {
                        Section("Places") {
                            ForEach(searchService.searchResults, id: \.self) { item in
                                Button { choose(item) } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name ?? "Cafe").fontWeight(.semibold).foregroundStyle(Color.espressoBrown)
                                        let subtitle = MapSearchService.subtitle(for: item)
                                        if !subtitle.isEmpty {
                                            Text(subtitle).font(.caption).foregroundStyle(Color.secondaryText)
                                        }
                                    }
                                }
                            }
                        }
                    } else if !searchService.completions.isEmpty {
                        Section("Suggestions") {
                            ForEach(searchService.completions.prefix(7), id: \.self) { completion in
                                Button {
                                    resolvingSuggestion = completion.title
                                    Task {
                                        if let item = await searchService.resolve(completion: completion, region: searchRegion) {
                                            choose(item)
                                        }
                                        resolvingSuggestion = nil
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(completion.title).fontWeight(.semibold).foregroundStyle(Color.espressoBrown)
                                            if !completion.subtitle.isEmpty {
                                                Text(completion.subtitle).font(.caption).foregroundStyle(Color.secondaryText)
                                            }
                                        }
                                        Spacer()
                                        if resolvingSuggestion == completion.title { ProgressView().controlSize(.small) }
                                    }
                                }
                                .disabled(resolvingSuggestion != nil)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("Choose a cafe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancellationTitle) {
                        if let onCancel { onCancel() } else { dismiss() }
                    }
                }
            }
            .task(id: query) {
                let value = query
                guard value.remoteTrimmedNonEmpty != nil else {
                    searchService.cancelSearch()
                    return
                }
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled, query == value else { return }
                searchService.search(query: value, region: searchRegion, immediately: true)
            }
            .onAppear {
                let scope = authModel.authenticatedUser.map { LocalAccountScope.user($0.id) } ?? .guest
                searchService.activate(scope: scope)
            }
        }
    }

    private func cafeButton(_ cafe: Cafe) -> some View {
        Button { onSelect(cafe) } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(cafe.consumerDisplayName).fontWeight(.semibold).foregroundStyle(Color.espressoBrown)
                if !cafe.address.isEmpty { Text(cafe.address).font(.caption).foregroundStyle(Color.secondaryText) }
            }
        }
    }

    private func choose(_ item: MKMapItem) {
        let cafe = dataManager.findOrCreateCafe(from: item)
        guard !excludedCafeIDs.contains(cafe.remoteCafeId ?? cafe.id) else { return }
        searchService.recordRecent(item)
        onSelect(cafe)
    }
}

private struct ProfileSpotDescriptorPicker: View {
    let cafeName: String?
    let primaryActionTitle: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var category: ProfileSpotDescriptorCategory = .drink
    @State private var descriptor: String
    @State private var customDescriptor = ""
    @FocusState private var isCustomDescriptorFocused: Bool

    private var categoryColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 8, alignment: .leading),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
    }

    init(
        cafeName: String?,
        initialDescriptor: String?,
        primaryActionTitle: String,
        onSave: @escaping (String) -> Void
    ) {
        self.cafeName = cafeName
        self.primaryActionTitle = primaryActionTitle
        self.onSave = onSave
        let startingCategory = ProfileSpotDescriptorCategory.category(containing: initialDescriptor)
        let initialDescriptor = initialDescriptor ?? ""
        _category = State(initialValue: startingCategory)
        _descriptor = State(initialValue: initialDescriptor)
        let allSuggestions = ProfileSpotDescriptorCategory.allCases.flatMap(\.suggestions)
        _customDescriptor = State(initialValue: allSuggestions.contains(initialDescriptor) ? "" : initialDescriptor)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(cafeName.map { "What is \($0) best for?" } ?? "What makes it a favorite?")
                            .mugshotDisplay(size: 25)
                            .foregroundStyle(Color.espressoBrown)
                        Text(
                            cafeName == nil
                                ? "Choose the reason first. Then pick the cafe that owns it."
                                : "This short line sits above the cafe name on your profile."
                        )
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("Pick a category")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.espressoBrown)

                        LazyVGrid(columns: categoryColumns, alignment: .leading, spacing: 8) {
                            ForEach(ProfileSpotDescriptorCategory.allCases) { option in
                                Button {
                                    category = option
                                    descriptor = ""
                                    customDescriptor = ""
                                    isCustomDescriptorFocused = option == .custom
                                } label: {
                                    Label(option.rawValue, systemImage: option.systemImage)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(category == option ? Color.foamWhite : Color.espressoBrown)
                                        .padding(.horizontal, 12)
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                        .background(
                                            category == option ? Color.mugshotSage : Color.sandBeige.opacity(0.58),
                                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Favorite spot category: \(option.rawValue)")
                                .accessibilityAddTraits(category == option ? .isSelected : [])
                            }
                        }
                    }

                    if category == .custom {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Make it yours")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.espressoBrown)
                            TextField("e.g. Best people-watching", text: $customDescriptor)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.sentences)
                                .submitLabel(.done)
                                .focused($isCustomDescriptorFocused)
                                .onChange(of: customDescriptor) { _, value in
                                    let limited = String(value.prefix(ProfileFavoriteSpotPolicy.descriptorLimit))
                                    if limited != value { customDescriptor = limited }
                                    descriptor = limited
                                }
                            Text("\(descriptor.count)/\(ProfileFavoriteSpotPolicy.descriptorLimit)")
                                .font(.caption2)
                                .foregroundStyle(Color.tertiaryText)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    } else {
                        TastingLensFlowLayout(spacing: 8) {
                            ForEach(category.suggestions, id: \.self) { suggestion in
                                Button {
                                    descriptor = suggestion
                                    customDescriptor = ""
                                } label: {
                                    Text(suggestion)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(descriptor == suggestion ? Color.foamWhite : Color.espressoBrown)
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 9)
                                        .background(
                                            descriptor == suggestion ? Color.mugshotSage : Color.sandBeige.opacity(0.6),
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.creamWhite)
            .navigationTitle("Describe this spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(primaryActionTitle) {
                        guard let normalized = ProfileFavoriteSpotPolicy.normalizedDescriptor(descriptor) else { return }
                        onSave(normalized)
                    }
                    .fontWeight(.bold)
                    .disabled(ProfileFavoriteSpotPolicy.normalizedDescriptor(descriptor) == nil)
                }
            }
        }
        .presentationDetents([.large])
    }
}
