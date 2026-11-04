import SwiftUI

enum HomeLibrarySection: String, CaseIterable, Identifiable {
    case recipes = "Recipes", beans = "Beans", gear = "Gear", preferences = "Preferences"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .recipes: "book.pages"
        case .beans: "leaf"
        case .gear: "kettle"
        case .preferences: "slider.horizontal.3"
        }
    }
}

struct HomeLibraryPresentation: Identifiable {
    let id = UUID()
    let ownerID: UUID?
    var section: HomeLibrarySection = .recipes
}

struct HomeLibraryEntryButton: View {
    var onComposeDraft: (SipDraft) -> Void = { _ in }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var authModel: AppAuthModel
    @State private var presentation: HomeLibraryPresentation?

    var body: some View {
        Button {
            presentation = HomeLibraryPresentation(ownerID: authModel.authenticatedUser?.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "house.fill").font(.title3)
                    .frame(width: 44, height: 44).background(Color.mugshotMint.opacity(0.3), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Home library").font(.headline)
                    Text("Recipes, beans, gear & preferences").font(.caption).foregroundStyle(Color.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold))
            }
            .foregroundStyle(Color.espressoBrown).padding(14)
            .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.mugshotLine))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.library.entry")
        .sheet(item: $presentation) { item in
            HomeLibraryView(ownerID: item.ownerID, initialSection: item.section, onComposeDraft: onComposeDraft)
                .environment(\.dynamicTypeSize, dynamicTypeSize)
        }
    }
}

/// A library, not a sip draft. All mutations stay in the originating account's shelf.
struct HomeLibraryView: View {
    let ownerID: UUID?
    var initialSection: HomeLibrarySection = .recipes
    var onComposeDraft: (SipDraft) -> Void = { _ in }
    var onSelectRecipe: ((HomeRecipeRecord, HomeRecipeVersion) -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var workspace = HomeRecipeWorkspaceStore.shared
    @ObservedObject private var permission = CoffeeAssistancePermissionStore.shared
    @ObservedObject private var synchronizer = HomeLibrarySynchronizer.shared
    @State private var section: HomeLibrarySection = .recipes
    @State private var library = HomeLibrarySnapshot.empty
    @State private var bagEditor: HomeBagEditorConfiguration?
    @State private var gearEditor: HomeEquipmentEditorConfiguration?
    @State private var recipe: HomeRecipeRecord?
    @State private var addsRecipe = false
    @State private var drinkDraft: HomeRecipeEditorDraft?
    @State private var pendingRecipe: HomeRecipeRecord?
    @State private var recipeUseFilter: HomeRecipeUse?
    @State private var findsRecipes = false
    @State private var addsAfterDiscovery = false
    @State private var showsArchived = false
    @State private var query = ""
    @State private var error: String?

    private var scope: LocalAccountScope { .forUserID(ownerID) }
    private var isCurrentOwner: Bool { authModel.authenticatedUser?.id == ownerID }
    private var preferences: HomeLibraryPreferences { library.preferences ?? HomeLibraryPreferences() }
    private var recipes: [HomeRecipeRecord] {
        guard workspace.scope == scope else { return [] }
        return workspace.workspace.recipes.filter {
            !$0.isArchived && (query.isEmpty || $0.current?.content.name.localizedCaseInsensitiveContains(query) == true)
                && (recipeUseFilter == nil || $0.current.map { HomeRecipeUse.suggested(for: $0.content) == recipeUseFilter } == true)
        }.sorted { lhs, rhs in
            lhs.isPinned != rhs.isPinned ? lhs.isPinned
                : (lhs.lastUsedAt ?? lhs.current?.createdAt ?? .distantPast)
                    > (rhs.lastUsedAt ?? rhs.current?.createdAt ?? .distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(heading).font(.system(size: 32, weight: .semibold, design: .serif))
                    Text(subtitle).font(.subheadline).foregroundStyle(Color.secondaryText)
                    sectionPicker
                    sectionContent
                    if let ownerID, let message = synchronizer.messages[ownerID] {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(message).font(.footnote)
                            Button("Retry sync") { Task { await synchronize() } }
                        }.foregroundStyle(Color.secondaryText)
                    }
                    if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                }.padding(20)
            }
            .background(Color.creamWhite)
            .navigationTitle("Home library").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("home.library.close")
                }
            }
            .task {
                section = initialSection
                guard isCurrentOwner else { return }
                workspace.activate(scope)
                reload()
                await synchronize()
            }
            .onChange(of: authModel.authenticatedUser?.id) { _, _ in
                if !isCurrentOwner {
                    bagEditor = nil; gearEditor = nil; recipe = nil; pendingRecipe = nil
                    drinkDraft = nil; addsRecipe = false; dismiss()
                }
            }
            .sheet(item: $bagEditor) { configuration in
                HomeCoffeeBagEditorSheet(configuration: configuration, scope: scope, existingBags: library.bags, store: .shared) { _ in reload() }
                    .environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(item: $gearEditor) { configuration in
                HomeEquipmentEditorSheet(configuration: configuration, scope: scope, store: .shared) { _ in reload() }
                    .environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(isPresented: $addsRecipe, onDismiss: openPendingRecipe) {
                HomeQuickRecipeSheet(store: workspace) { saved, version in
                    addsRecipe = false
                    if let onSelectRecipe { onSelectRecipe(saved, version); dismiss() }
                    else { pendingRecipe = saved }
                }.environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(item: $drinkDraft, onDismiss: openPendingRecipe) { draft in
                HomeDrinkBuilderSheet(store: workspace, draft: draft) { id in
                    drinkDraft = nil
                    guard let saved = workspace.workspace.recipes.first(where: { $0.id == id }), let version = saved.current else { return }
                    if let onSelectRecipe { onSelectRecipe(saved, version); dismiss() }
                    else { pendingRecipe = saved }
                }.environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(item: $recipe) { item in
                HomeRecipeExperienceView(ownerID: ownerID, initialRecipeID: item.id, initialCollection: "Recipes", onShare: { draft in
                    recipe = nil
                    dismiss()
                    onComposeDraft(draft)
                }).environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(isPresented: $findsRecipes, onDismiss: {
                if addsAfterDiscovery { addsAfterDiscovery = false; addsRecipe = true }
            }) {
                HomeRecipeDiscoveryView { addsAfterDiscovery = true; findsRecipes = false }
                    .environment(\.dynamicTypeSize, dynamicTypeSize)
            }
        }
        .tint(Color.mugshotSageText)
        .disabled(!isCurrentOwner)
    }

    private var heading: String {
        switch section {
        case .recipes: "Make something yours."
        case .beans: "Your beans"
        case .gear: "Your gear"
        case .preferences: "Just your way."
        }
    }
    private var subtitle: String {
        switch section {
        case .recipes: "A recipe from anywhere. A favorite made at home."
        case .beans: "Keep your bags together, from the first scoop to the last."
        case .gear: "The tools you reach for, ready when you are."
        case .preferences: "A few defaults. A little less to fill in."
        }
    }
    private var sectionPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(HomeLibrarySection.allCases) { item in
                    Button { section = item; query = "" } label: {
                        Text(item.rawValue)
                            .font(.subheadline.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 44)
                            .foregroundStyle(section == item ? Color.foamWhite : Color.espressoBrown)
                            .background(section == item ? Color.mugshotSageText : Color.foamWhite, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(section == item ? .isSelected : [])
                    .accessibilityIdentifier("home.library.\(item.rawValue.lowercased())")
                }
            }
        }.scrollIndicators(.hidden).accessibilityIdentifier("home.library.sections")
    }

    @ViewBuilder private var sectionContent: some View {
        switch section {
        case .recipes: recipeShelf
        case .beans: beanShelf
        case .gear: gearShelf
        case .preferences: preferencesForm
        }
    }

    private var recipeShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button { drinkDraft = HomeRecipeEditorDraft(content: HomeDrinkComposition.starting()) } label: {
                    Label("Build a drink", systemImage: "mug").frame(maxWidth: .infinity)
                }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("home.library.buildDrink")
                Button { addsRecipe = true } label: { Label("Add a recipe", systemImage: "plus").frame(maxWidth: .infinity) }
                    .buttonStyle(SecondaryButtonStyle()).accessibilityIdentifier("home.library.addRecipe")
            }
            Button("Find your next recipe", systemImage: "safari") { findsRecipes = true }
                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            ForEach(workspace.workspace.recipeDrafts.filter { $0.content.template == .drink && $0.content.name.remoteTrimmedNonEmpty != nil }) { draft in
                Button { drinkDraft = draft } label: {
                    shelfRow("Continue \(draft.content.name)", detail: "Your recipe draft", symbol: "pencil")
                }.buttonStyle(.plain)
            }
            TextField("Search your recipes", text: $query).textFieldStyle(.roundedBorder)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    recipeFilter("All", use: nil)
                    ForEach([HomeRecipeUse.drink, .component, .base]) { use in recipeFilter(use.title, use: use) }
                }
            }.scrollIndicators(.hidden)
            if recipes.isEmpty {
                empty("An idea is enough to start.", detail: "Save a link, paste a caption, scan a screenshot, or build your own. Coffee, tea, matcha and all the good things in between.", symbol: "book.pages")
            }
            ForEach(recipes) { item in
                if let version = item.current {
                    Button {
                        if let onSelectRecipe { onSelectRecipe(item, version); dismiss() }
                        else { recipe = item }
                    } label: {
                        shelfRow(version.content.name,
                            detail: HomeRecipeUse.suggested(for: version.content).title + " · " + version.content.recipeContentsSummary,
                            symbol: HomeRecipeUse.suggested(for: version.content).symbol)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func recipeFilter(_ title: String, use: HomeRecipeUse?) -> some View {
        Button { recipeUseFilter = use } label: {
            Text(title).font(.caption.weight(.semibold)).padding(.horizontal, 14).frame(minHeight: 44)
                .foregroundStyle(recipeUseFilter == use ? Color.foamWhite : Color.espressoBrown)
                .background(recipeUseFilter == use ? Color.mugshotSageText : Color.foamWhite, in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(recipeUseFilter == use ? .isSelected : [])
    }

    private func openPendingRecipe() {
        guard isCurrentOwner, let saved = pendingRecipe else { pendingRecipe = nil; return }
        query = ""; recipeUseFilter = nil; pendingRecipe = nil; recipe = saved
    }

    private var beanShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button("Scan a bag", systemImage: "viewfinder") { bagEditor = .scan }.buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("home.library.scanBag")
            Button("Add manually", systemImage: "plus") { bagEditor = .manual }.buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("home.library.addBag")
            Toggle("Show finished and archived bags", isOn: $showsArchived).font(.subheadline)
            if library.bags.isEmpty { empty("Meet your next morning.", detail: "Add a bag once. Pick it whenever you make a sip.", symbol: "leaf") }
            ForEach(library.bags.filter { $0.ownerUserID == ownerID && (showsArchived || $0.status.isCurrent) }.sorted { $0.updatedAt > $1.updatedAt }) { bag in
                Button { bagEditor = .edit(bag) } label: {
                    shelfRow(bag.displayName, detail: [bag.roaster, bag.origin, bag.status.title].filter { !$0.isEmpty }.joined(separator: " · "), symbol: "leaf")
                }.buttonStyle(.plain)
            }
        }
    }

    private var gearShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button("Add gear", systemImage: "plus") { gearEditor = .new }.buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("home.library.addGear")
            Toggle("Show archived gear", isOn: $showsArchived).font(.subheadline)
            if library.equipment.isEmpty { empty("Make room for your favorites.", detail: "Brewers, grinders, kettles and the little tools that make it yours.", symbol: "kettle") }
            ForEach(library.equipment.filter { $0.ownerUserID == ownerID && (showsArchived || $0.archivedAt == nil) }) { gear in
                Button { gearEditor = HomeEquipmentEditorConfiguration(equipment: gear) } label: {
                    shelfRow(gear.displayName, detail: gear.role.title, symbol: gear.role.systemImage)
                }.buttonStyle(.plain)
            }
        }
    }

    private var preferencesForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Text("For a fresh setup").font(.headline)
                Menu(preferences.preferredMethod.map { "Favorite method: \($0.title)" } ?? "Choose a favorite method") {
                    Button("No favorite") { updatePreferences { $0.preferredMethod = nil } }
                    ForEach(HomeBrewMethod.allCases) { method in Button(method.title) { updatePreferences { $0.preferredMethod = method } } }
                }
                Menu(library.defaults(for: ownerID).bag.map { "Go-to beans: \($0.displayName)" } ?? "Choose go-to beans") {
                    Button("None") { updatePreferences { $0.defaultBagID = nil } }
                    ForEach(library.currentBags) { bag in Button(bag.displayName) { updatePreferences { $0.defaultBagID = bag.id } } }
                }
                ForEach(library.activeEquipment) { gear in
                    Toggle(gear.displayName, isOn: Binding(get: { preferences.defaultEquipmentIDs.contains(gear.id) }, set: { value in
                        updatePreferences { if value { $0.defaultEquipmentIDs.insert(gear.id) } else { $0.defaultEquipmentIDs.remove(gear.id) } }
                    }))
                }
                Text("Used for a fresh setup on this device. Your saved recipes keep their own details.").font(.caption).foregroundStyle(Color.secondaryText)
            }.padding(16).background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 20))
            VStack(alignment: .leading, spacing: 12) {
                if let ownerID, permission.isEnabled(ownerID: ownerID) {
                    Toggle("Use Luna", isOn: Binding(get: { permission.isEnabled(ownerID: ownerID) }, set: { permission.setEnabled($0, ownerID: ownerID) }))
                    Text("OpenAI reads selected photos, recipe text and saved sip details when you use a Luna tool. Manual entry always works.").font(.caption).foregroundStyle(Color.secondaryText)
                } else if ownerID != nil { LunaPermissionControl(ownerID: ownerID) }
                else { Text("Sign in to use Luna. Your on-device library and manual entry work here too.").font(.subheadline).foregroundStyle(Color.secondaryText) }
            }.padding(16).background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func shelfRow(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Color.mugshotSageText).frame(width: 42)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(Color.espressoBrown)
                Text(detail).font(.caption).foregroundStyle(Color.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Color.mugshotSageText)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 18))
    }
    private func empty(_ title: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(Color.mugshotSageText)
            Text(title).font(.title2.weight(.semibold))
            Text(detail).font(.subheadline).foregroundStyle(Color.secondaryText)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.mugshotMint.opacity(0.18), in: RoundedRectangle(cornerRadius: 22))
    }
    private func reload() {
        guard isCurrentOwner else { return }
        library = HomeLibraryStore.shared.load(in: scope)
    }
    private func updatePreferences(_ update: (inout HomeLibraryPreferences) -> Void) {
        guard isCurrentOwner else { return }
        var changed = preferences; update(&changed)
        do { library = try HomeLibraryStore.shared.savePreferences(changed, in: scope) }
        catch { self.error = "Couldn’t save that preference. Please try again." }
    }
    private func synchronize() async {
        await synchronizer.synchronize(scope: scope, currentOwner: { authModel.authenticatedUser?.id })
        if isCurrentOwner { reload() }
    }
}

private struct HomeRecipeDiscoveryView: View {
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private var searchURL: URL {
        var url = URLComponents(string: "https://www.google.com/search")!
        url.queryItems = [URLQueryItem(name: "q", value: (query.isEmpty ? "coffee tea matcha drinks" : query) + " recipe")]
        return url.url!
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Follow your curiosity.").font(.system(size: 32, weight: .semibold, design: .serif))
                    Text("A creator’s video, a favorite website, your own experiment. Keep the source with the recipe.").foregroundStyle(Color.secondaryText)
                    TextField("What sounds good?", text: $query).textFieldStyle(.roundedBorder)
                    ForEach(["Iced matcha", "Pour-over coffee", "Chai", "Coffee syrups"], id: \.self) { idea in
                        Button(idea, systemImage: "magnifyingglass") { query = idea }.frame(minHeight: 44)
                    }
                    Link(destination: searchURL) { Label("Search the web", systemImage: "safari") }.buttonStyle(PrimaryButtonStyle())
                    Button("Save a recipe you found", systemImage: "plus", action: onAdd).buttonStyle(SecondaryButtonStyle())
                    Text("Paste a public Instagram or TikTok link, add a caption, or choose screenshots or a saved video. Keep the creator’s source with your recipe.")
                        .font(.caption).foregroundStyle(Color.secondaryText)
                }.padding(20)
            }.background(Color.creamWhite).navigationTitle("Find a recipe").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
        }.tint(Color.mugshotSageText)
    }
}
