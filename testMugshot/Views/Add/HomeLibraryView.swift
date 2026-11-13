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
            HomeLibraryView(ownerID: item.ownerID, initialSection: item.section, onComposeDraft: onComposeDraft, includesSipDrafts: true)
                .environment(\.dynamicTypeSize, dynamicTypeSize)
        }
    }
}

/// A library, not a sip draft. All mutations stay in the originating account's shelf.
struct HomeLibraryView: View {
    let ownerID: UUID?
    var initialSection: HomeLibrarySection = .recipes
    var onComposeDraft: (SipDraft) -> Void = { _ in }
    var includesSipDrafts = false
    var onSelectRecipe: ((HomeRecipeRecord, HomeRecipeVersion) -> Void)? = nil
    var onMakeRecipe: ((HomeRecipeRecord, HomeRecipeVersion) -> Void)? = nil
    var onSelectStarter: ((HomeRecipeContent) -> Void)? = nil
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
    @State private var pendingMake: HomeRecipeRecord?
    @State private var brewDraft: HomeRecipeEditorDraft?
    @State private var recipeUseFilter: HomeRecipeUse?
    @State private var recipeMethodFilter: HomeBrewMethod?
    @State private var recipeSort = HomeRecipeShelfSort.recentlyUsed
    @State private var showsArchivedRecipes = false
    @State private var findsRecipes = false
    @State private var addsAfterDiscovery = false
    @State private var showsStarterPicker = false
    @State private var pendingStarter: HomeRecipeContent?
    @State private var showsArchivedBags = false
    @State private var bagStatusFilter: CoffeeBagStatus?
    @State private var bagSort = HomeBagShelfSort.roastDate
    @State private var showsArchivedGear = false
    @State private var gearRoleFilter: EquipmentRole?
    @State private var gearSetupFilter: UUID?
    @State private var query = ""
    @State private var error: String?
    @State private var showsDrafts = false
    @State private var sipDrafts: [SipDraft] = []
    @State private var profileEditor: HomePlaceProfile?
    @State private var profileRemoval: HomePlaceProfile?
    @FocusState private var isSearchingRecipes: Bool

    private var scope: LocalAccountScope { .forUserID(ownerID) }
    private var isCurrentOwner: Bool { authModel.authenticatedUser?.id == ownerID }
    private var preferences: HomeLibraryPreferences { library.preferences ?? HomeLibraryPreferences() }
    private var profiles: [HomePlaceProfile] { (preferences.homeProfiles ?? []).filter { $0.ownerUserID == ownerID } }
    private var canStartRecipe: Bool { includesSipDrafts || onSelectStarter != nil }
    private var offersGuestPhotoDrafts: Bool { includesSipDrafts && ownerID == nil }
    private var availableSections: [HomeLibrarySection] {
        includesSipDrafts || onSelectRecipe != nil || onSelectStarter != nil ? HomeLibrarySection.allCases : [initialSection]
    }
    private var draftCount: Int {
        guard workspace.scope == scope else { return 0 }
        return HomeDraftCatalogue(sipDrafts: includesSipDrafts ? sipDrafts : [], workspace: workspace.workspace).count
    }
    private var scopedRecipes: [HomeRecipeRecord] {
        guard workspace.scope == scope else { return [] }
        return workspace.workspace.recipes.filter { $0.current != nil }
    }

    var body: some View {
        NavigationStack {
            AnyView(libraryContent)
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
                    drinkDraft = nil; addsRecipe = false; profileEditor = nil; profileRemoval = nil
                    showsDrafts = false; showsStarterPicker = false; pendingStarter = nil
                    findsRecipes = false; addsAfterDiscovery = false
                    dismiss()
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
                HomeQuickRecipeSheet(store: workspace, onMake: canStartRecipe ? { saved, _ in
                    if isCurrentOwner, workspace.scope == scope { pendingMake = saved }
                    addsRecipe = false
                } : nil) { saved, version in
                    addsRecipe = false
                    guard isCurrentOwner, workspace.scope == scope else { return }
                    if let onSelectRecipe { onSelectRecipe(saved, version); dismiss() }
                    else { pendingRecipe = saved }
                }.environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(item: $brewDraft, onDismiss: openPendingRecipe) { draft in
                NavigationStack {
                    HomeRecipeEditorView(store: workspace, draft: draft) { id in
                        guard isCurrentOwner, workspace.scope == scope,
                              let saved = workspace.workspace.recipes.first(where: { $0.id == id }) else { return }
                        pendingRecipe = saved
                        brewDraft = nil
                    }
                }.environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(item: $drinkDraft, onDismiss: openPendingRecipe) { draft in
                HomeDrinkBuilderSheet(store: workspace, draft: draft) { id in
                    drinkDraft = nil
                    guard isCurrentOwner, workspace.scope == scope,
                          let saved = workspace.workspace.recipes.first(where: { $0.id == id }), let version = saved.current else { return }
                    if let onSelectRecipe { onSelectRecipe(saved, version); dismiss() }
                    else { pendingRecipe = saved }
                }.environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(item: $recipe) { item in
                HomeRecipeExperienceView(ownerID: ownerID, initialRecipeID: item.id, opensRecipeDirectly: true, onShare: { draft in
                    guard isCurrentOwner, workspace.scope == scope else { return }
                    recipe = nil
                    dismiss()
                    onComposeDraft(draft)
                }).environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(isPresented: $showsStarterPicker, onDismiss: openPendingStarter) {
                HomeStarterPicker { content in
                    guard isCurrentOwner, workspace.scope == scope else { return }
                    pendingStarter = content
                    showsStarterPicker = false
                }.environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(isPresented: $findsRecipes, onDismiss: {
                if addsAfterDiscovery { addsAfterDiscovery = false; addsRecipe = true }
            }) {
                HomeRecipeDiscoveryView { addsAfterDiscovery = true; findsRecipes = false }
                    .environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(isPresented: $showsDrafts, onDismiss: reload) {
                HomeDraftManagementView(
                    ownerID: ownerID,
                    includesSipDrafts: includesSipDrafts,
                    onResumeSip: { draft in
                        showsDrafts = false; dismiss(); onComposeDraft(draft)
                    },
                    onPhotoDraftSaved: offersGuestPhotoDrafts ? { reload() } : nil
                ).environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(item: $profileEditor, onDismiss: reload) { profile in
                HomePlaceProfileEditorView(ownerID: ownerID, profile: profile) { _ in reload() }
                    .environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(isPresented: Binding(
                get: { profileRemoval != nil }, set: { if !$0 { profileRemoval = nil } }
            )) {
                SipDeleteConfirmationSheet(isDeleting: false, errorMessage: nil,
                    title: "Remove this Home setup?", deleteTitle: "Remove setup", cancelTitle: "Keep setup",
                    message: "Earlier sips keep their recorded Home name. Your gear and recipes stay in your library.") {
                    guard isCurrentOwner, let profileRemoval else { return }
                    do {
                        library = try HomeLibraryStore.shared.removeHomeProfile(id: profileRemoval.id, in: scope)
                        if gearSetupFilter == profileRemoval.id { gearSetupFilter = nil }
                    }
                    catch { self.error = "Couldn’t remove this setup. Try again." }
                    self.profileRemoval = nil
                }
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
        }
        .tint(Color.mugshotSageText)
        .disabled(!isCurrentOwner)
    }

    @ViewBuilder private var libraryContent: some View {
        if isCurrentOwner {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(heading).font(.system(.largeTitle, design: .serif).weight(.semibold))
                    Text(subtitle).font(.subheadline).foregroundStyle(Color.secondaryText)
                    if availableSections.count > 1 { sectionPicker }
                    if section == .recipes, includesSipDrafts, draftCount > 0 || offersGuestPhotoDrafts {
                        HomeDraftSummaryButton(count: draftCount) { showsDrafts = true }
                    }
                    sectionContent
                    if let ownerID, let message = synchronizer.messages[ownerID] {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(message).font(.footnote)
                            Button("Retry sync") { Task { await synchronize() } }
                        }.foregroundStyle(Color.secondaryText)
                    }
                    if let error { HomeEditorError(message: error) }
                }.padding(20)
            }
            .accessibilityIdentifier("home.library.scroll")
            .background(Color.creamWhite)
            .scrollDismissesKeyboard(.interactively)
        } else {
            ContentUnavailableView("Home library unavailable", systemImage: "house")
        }
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
                ForEach(availableSections) { item in
                    Button { isSearchingRecipes = false; section = item } label: {
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
        let active = scopedRecipes.filter { !$0.isArchived }
        let matches = HomeLibraryBrowse.recipes(scopedRecipes, query: query,
            use: recipeUseFilter, method: recipeMethodFilter, sort: recipeSort)
        let archived = HomeLibraryBrowse.recipes(scopedRecipes, archived: true, sort: .name)
        return LazyVStack(alignment: .leading, spacing: 14) {
            recipeUseControls
            if recipeUseFilter == .drink { buildDrinkButton }
            if recipeUseFilter == .base { newBrewRecipeMenu }
            saveRecipeButton
            if active.isEmpty {
                empty(archived.isEmpty ? "Start with something good." : "Your recipes are archived",
                    detail: archived.isEmpty
                        ? "Try a coffee, tea or matcha starter, or keep a recipe you found."
                        : "Restore a recipe below whenever you want it back on your shelf.",
                    symbol: "book.pages")
                if canStartRecipe {
                    Button("Try a starter recipe", systemImage: "cup.and.saucer") {
                        showsStarterPicker = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("home.library.starter")
                }
            } else {
                recipeBrowseControls(active)
            }
            if !archived.isEmpty { archivedRecipeShelf(archived) }
            if !active.isEmpty && matches.isEmpty {
                empty("No recipes match", detail: "Try another name, type or method.", symbol: "magnifyingglass")
                Button("Clear filters", systemImage: "xmark.circle", action: clearRecipeFilters)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("home.library.clearRecipeFilters")
            }
            ForEach(matches) { item in
                if let version = item.current {
                    let use = HomeRecipeUse.suggested(for: version.content)
                    Button {
                        guard isCurrentOwner, workspace.scope == scope else { return }
                        isSearchingRecipes = false
                        if let onSelectRecipe { onSelectRecipe(item, version); dismiss() }
                        else { recipe = item }
                    } label: {
                        shelfRow(version.content.name,
                            detail: "\(use.title) · \(version.content.recipeContentsSummary)",
                            symbol: use.symbol, pinned: item.isPinned)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.library.recipe.\(item.id)")
                }
            }
            Button("Find your next recipe", systemImage: "arrow.up.right.square") { findsRecipes = true }
                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                .accessibilityHint("Choose a topic to search outside Mugshot.")
        }
    }

    private var recipeUseControls: some View {
        let columns = dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 8) {
            recipeUseButton("All recipes", use: nil, symbol: "book.pages")
            recipeUseButton("Whole drinks", use: .drink, symbol: "mug")
            recipeUseButton("Add-ins", use: .component, symbol: "sparkles")
            recipeUseButton("Brew recipes", use: .base, symbol: "cup.and.saucer")
        }
    }

    private func recipeUseButton(_ title: String, use: HomeRecipeUse?, symbol: String) -> some View {
        let selected = recipeUseFilter == use
        return Button {
            recipeUseFilter = use
            recipeMethodFilter = nil
            isSearchingRecipes = false
        } label: {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .foregroundStyle(selected ? Color.foamWhite : Color.mugshotSageText)
                .background(selected ? Color.mugshotSageText : Color.foamWhite, in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.library.use.\(use?.rawValue ?? "all")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var newBrewRecipeMenu: some View {
        Menu {
            ForEach(HomeBrewMethod.allCases.filter { $0.family != .component }) { method in
                Button(method.title) {
                    guard isCurrentOwner, workspace.scope == scope else { return }
                    isSearchingRecipes = false
                    brewDraft = HomeRecipeEditorDraft(content: HomeRecipeContent(name: "", template: .preparation, method: method,
                        targets: HomeRecipeContent.defaultTargets(for: method), ingredients: HomeRecipeContent.defaultIngredients(for: method),
                        steps: HomeRecipeContent.defaultSteps(for: method)))
                }
            }
        } label: {
            Label("Choose a method", systemImage: "cup.and.saucer").frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityIdentifier("home.library.newBrew")
    }

    private var saveRecipeButton: some View {
        Button { addsRecipe = true } label: {
            Label("Save a recipe you found", systemImage: "plus")
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle())
        .accessibilityIdentifier("home.library.addRecipe")
    }

    private var buildDrinkButton: some View {
        Button { drinkDraft = HomeRecipeEditorDraft(content: HomeDrinkComposition.starting()) } label: {
            Label("Build a drink", systemImage: "mug").frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityIdentifier("home.library.buildDrink")
    }

    private func recipeBrowseControls(_ records: [HomeRecipeRecord]) -> some View {
        let contents = records.compactMap { $0.current?.content }.filter { HomeRecipeUse.suggested(for: $0) == .base }
        let methods = Set(contents.map(\.method) + [recipeMethodFilter].compactMap { $0 }).sorted {
            let order = $0.title.localizedCaseInsensitiveCompare($1.title)
            return order == .orderedSame ? $0.rawValue < $1.rawValue : order == .orderedAscending
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.mugshotSageText)
                TextField("Search your recipes", text: $query)
                    .focused($isSearchingRecipes)
                    .submitLabel(.search)
                    .onSubmit { isSearchingRecipes = false }
                    .accessibilityIdentifier("home.library.recipeSearch")
            }
            .padding(.horizontal, 12).frame(minHeight: 48)
            .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 14))
            if records.count > 1 || recipeUseFilter != nil || recipeMethodFilter != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { recipeMenus(count: records.count, methods: methods) }
                    VStack(alignment: .leading, spacing: 8) { recipeMenus(count: records.count, methods: methods) }
                }
            }
        }
    }

    @ViewBuilder private func recipeMenus(count: Int, methods: [HomeBrewMethod]) -> some View {
        if count > 1 {
            shelfMenu(recipeSort.rawValue, symbol: "arrow.up.arrow.down", identifier: "home.library.recipeSort") {
                Picker("Sort recipes", selection: $recipeSort) {
                    ForEach(HomeRecipeShelfSort.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            .accessibilityLabel("Sort recipes")
            .accessibilityValue(recipeSort.rawValue)
        }
        if recipeUseFilter == .base && (!methods.isEmpty || recipeMethodFilter != nil) {
            shelfMenu(recipeMethodFilter?.title ?? "Method", symbol: "cup.and.saucer", identifier: "home.library.recipeMethod") {
                Picker("Brew method", selection: $recipeMethodFilter) {
                    Text("All methods").tag(Optional<HomeBrewMethod>.none)
                    ForEach(methods, id: \.rawValue) { Text($0.title).tag(Optional($0)) }
                }
            }
            .accessibilityLabel("Brew method")
            .accessibilityValue(recipeMethodFilter?.title ?? "All methods")
        }
    }

    private func archivedRecipeShelf(_ archived: [HomeRecipeRecord]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { showsArchivedRecipes.toggle() } label: {
                HStack(spacing: 10) {
                    Label("Archived recipes", systemImage: "archivebox")
                    Spacer()
                    Text("\(archived.count)").monospacedDigit()
                    Image(systemName: showsArchivedRecipes ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .accessibilityIdentifier("home.library.archivedRecipes")
            .accessibilityLabel("Archived recipes")
            .accessibilityValue("\(archived.count), \(showsArchivedRecipes ? "expanded" : "collapsed")")
            if showsArchivedRecipes {
                ForEach(archived) { item in
                    if let content = item.current?.content {
                        HStack(spacing: 12) {
                            Text(content.name).font(.subheadline.weight(.semibold))
                            Spacer(minLength: 8)
                            Button("Restore") { restoreRecipe(item.id) }
                                .frame(minHeight: 44)
                                .accessibilityLabel("Restore \(content.name)")
                                .accessibilityIdentifier("home.library.restoreRecipe.\(item.id)")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
        .foregroundStyle(Color.mugshotSageText)
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 16))
    }

    private func restoreRecipe(_ id: UUID) {
        guard isCurrentOwner, workspace.scope == scope else { return }
        do {
            try workspace.mutate { state in
                guard let index = state.recipes.firstIndex(where: { $0.id == id }) else { return }
                state.recipes[index].isArchived = false
            }
            error = nil
            Task {
                guard isCurrentOwner, workspace.scope == scope else { return }
                await workspace.synchronize()
            }
        } catch { self.error = "Couldn’t restore this recipe. Try again." }
    }

    private func clearRecipeFilters() {
        isSearchingRecipes = false
        query = ""
        recipeUseFilter = nil
        recipeMethodFilter = nil
    }

    private func openPendingRecipe() {
        if let saved = pendingMake {
            pendingMake = nil
            guard isCurrentOwner, workspace.scope == scope, let version = saved.current else { return }
            if let onMakeRecipe {
                onMakeRecipe(saved, version)
                dismiss()
            } else if includesSipDrafts {
                let draft = HomeBrewSetup.draft(for: saved, version: version, ownerID: ownerID, shelf: library, guided: true) {
                    workspace.workspace.version($0)?.content
                }
                dismiss()
                onComposeDraft(draft)
            }
            return
        }
        guard isCurrentOwner, workspace.scope == scope, let saved = pendingRecipe else { pendingRecipe = nil; return }
        pendingRecipe = nil
        clearRecipeFilters()
        recipe = saved
    }

    private func openPendingStarter() {
        guard isCurrentOwner, workspace.scope == scope, let content = pendingStarter else { pendingStarter = nil; return }
        pendingStarter = nil
        if let onSelectStarter {
            onSelectStarter(content)
            dismiss()
        } else if includesSipDrafts {
            let draft = HomeStarterRecipes.draft(for: content, ownerID: ownerID)
            dismiss()
            onComposeDraft(draft)
        }
    }

    private var beanShelf: some View {
        let owned = library.bags.filter { $0.ownerUserID == ownerID }
        let visible = HomeLibraryBrowse.bags(owned, ownerID: ownerID, showsArchived: showsArchivedBags, sort: bagSort)
        let matches = HomeLibraryBrowse.bags(visible, ownerID: ownerID, showsArchived: showsArchivedBags,
            status: bagStatusFilter, sort: bagSort)
        let statuses = CoffeeBagStatus.allCases.filter { status in
            bagStatusFilter == status || visible.contains { $0.status == status }
        }
        return LazyVStack(alignment: .leading, spacing: 14) {
            Button("Scan a bag", systemImage: "viewfinder") { bagEditor = .scan }
                .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("home.library.scanBag")
            Button("Add manually", systemImage: "plus") { bagEditor = .manual }
                .buttonStyle(SecondaryButtonStyle()).accessibilityIdentifier("home.library.addBag")
            if owned.contains(where: { !$0.status.isCurrent }) {
                Toggle("Show finished and archived bags", isOn: $showsArchivedBags)
                    .font(.subheadline).frame(minHeight: 44)
                    .accessibilityIdentifier("home.library.archivedBags")
                    .onChange(of: showsArchivedBags) { _, showsArchived in
                        if !showsArchived, bagStatusFilter?.isCurrent == false { bagStatusFilter = nil }
                    }
            }
            if visible.count > 1 || bagStatusFilter != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { bagMenus(count: visible.count, statuses: statuses) }
                    VStack(alignment: .leading, spacing: 8) { bagMenus(count: visible.count, statuses: statuses) }
                }
            }
            if owned.isEmpty {
                empty("Meet your next morning.", detail: "Save the name on a bag so it’s ready when you make a sip.", symbol: "leaf")
            } else if visible.isEmpty {
                empty("No current bags", detail: "Show finished and archived bags to see your earlier coffee.", symbol: "leaf")
            } else if matches.isEmpty {
                empty("No bags match", detail: "Choose a different status to see more bags.", symbol: "magnifyingglass")
                Button("Clear status filter") { bagStatusFilter = nil }.frame(minHeight: 44)
            }
            ForEach(matches) { bag in
                Button { bagEditor = .edit(bag) } label: {
                    let detail = [bag.roaster.remoteTrimmedNonEmpty, bag.origin.remoteTrimmedNonEmpty,
                        bag.status.title, HomeLibraryBrowse.roastDateLabel(bag)].compactMap { $0 }.joined(separator: " · ")
                    shelfRow(bag.displayName, detail: detail, symbol: "leaf")
                }.buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private func bagMenus(count: Int, statuses: [CoffeeBagStatus]) -> some View {
        if count > 1 {
            shelfMenu(bagSort.rawValue, symbol: "arrow.up.arrow.down", identifier: "home.library.bagSort") {
                Picker("Sort bags", selection: $bagSort) {
                    ForEach(HomeBagShelfSort.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            .accessibilityLabel("Sort bags")
            .accessibilityValue(bagSort.rawValue)
        }
        if statuses.count > 1 || bagStatusFilter != nil {
            shelfMenu(bagStatusFilter?.title ?? "Status", symbol: "line.3.horizontal.decrease", identifier: "home.library.bagStatus") {
                Picker("Bag status", selection: $bagStatusFilter) {
                    Text("All statuses").tag(Optional<CoffeeBagStatus>.none)
                    ForEach(statuses) { Text($0.title).tag(Optional($0)) }
                }
            }
            .accessibilityLabel("Bag status")
            .accessibilityValue(bagStatusFilter?.title ?? "All statuses")
        }
    }

    private var gearShelf: some View {
        let owned = library.equipment.filter { $0.ownerUserID == ownerID }
        let setup = profiles.first { $0.id == gearSetupFilter }
        let visible = HomeLibraryBrowse.gear(owned, ownerID: ownerID, showsArchived: showsArchivedGear)
        let matches = HomeLibraryBrowse.gear(visible, ownerID: ownerID, showsArchived: showsArchivedGear,
            role: gearRoleFilter, setup: setup)
        let roles = EquipmentRole.allCases.filter { role in
            gearRoleFilter == role || visible.contains { $0.role == role }
        }
        return LazyVStack(alignment: .leading, spacing: 14) {
            Button("Add gear", systemImage: "plus") { gearEditor = .new }
                .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("home.library.addGear")
            if owned.contains(where: { $0.archivedAt != nil }) {
                Toggle("Show archived gear", isOn: $showsArchivedGear)
                    .font(.subheadline).frame(minHeight: 44)
                    .accessibilityIdentifier("home.library.archivedGear")
            }
            if roles.count > 1 || gearRoleFilter != nil || (!visible.isEmpty && !profiles.isEmpty) || setup != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { gearMenus(roles: roles, setup: setup, hasVisibleGear: !visible.isEmpty) }
                    VStack(alignment: .leading, spacing: 8) { gearMenus(roles: roles, setup: setup, hasVisibleGear: !visible.isEmpty) }
                }
            }
            if owned.isEmpty {
                empty("Make room for your favorites.", detail: "Keep the brewers, grinders and other tools you use most.", symbol: "kettle")
            } else if visible.isEmpty {
                empty("No active gear", detail: "Show archived gear to see your earlier tools.", symbol: "kettle")
            } else if matches.isEmpty {
                empty("No gear matches", detail: "Try another role or Home setup.", symbol: "magnifyingglass")
                Button("Clear gear filters") { gearRoleFilter = nil; gearSetupFilter = nil }.frame(minHeight: 44)
            }
            ForEach(matches) { gear in
                Button { gearEditor = HomeEquipmentEditorConfiguration(equipment: gear) } label: {
                    shelfRow(gear.displayName,
                        detail: gear.archivedAt == nil ? gear.role.title : "\(gear.role.title) · Archived",
                        symbol: gear.role.systemImage)
                }.buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private func gearMenus(roles: [EquipmentRole], setup: HomePlaceProfile?, hasVisibleGear: Bool) -> some View {
        if roles.count > 1 || gearRoleFilter != nil {
            shelfMenu(gearRoleFilter?.title ?? "Role", symbol: "line.3.horizontal.decrease", identifier: "home.library.gearRole") {
                Picker("Gear role", selection: $gearRoleFilter) {
                    Text("All roles").tag(Optional<EquipmentRole>.none)
                    ForEach(roles) { Text($0.title).tag(Optional($0)) }
                }
            }
            .accessibilityLabel("Gear role")
            .accessibilityValue(gearRoleFilter?.title ?? "All roles")
        }
        if (hasVisibleGear && !profiles.isEmpty) || setup != nil {
            shelfMenu(setup?.name ?? "Home setup", symbol: "house", identifier: "home.library.gearSetup") {
                Picker("Home setup", selection: $gearSetupFilter) {
                    Text("All setups").tag(Optional<UUID>.none)
                    ForEach(profiles) { Text($0.name).tag(Optional($0.id)) }
                }
            }
            .accessibilityLabel("Home setup")
            .accessibilityValue(setup?.name ?? "All setups")
        }
    }

    private func shelfMenu<Content: View>(_ title: String, symbol: String, identifier: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12).frame(minHeight: 44)
                .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityIdentifier(identifier)
    }

    private var preferencesForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            HomeEditorSection("Your Home setups", symbol: "house", detail: "Give a spot a nickname and choose the tools you use there.") {
                if profiles.isEmpty {
                    Text("Home is ready to use. Add a named setup whenever you like.")
                        .font(.subheadline).foregroundStyle(Color.secondaryText)
                }
                ForEach(profiles) { profile in
                    HStack(spacing: 8) {
                        Button { profileEditor = profile } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name).font(.headline)
                                Text(preferences.defaultHomeProfileID == profile.id ? "Default Home setup" : (profile.equipmentIDs.count == 1 ? "1 saved tool" : "\(profile.equipmentIDs.count) saved tools"))
                                    .font(.caption).foregroundStyle(Color.secondaryText)
                            }.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        }.buttonStyle(.plain).accessibilityLabel("Edit \(profile.name) Home setup")
                        Menu {
                            Button("Use as default", systemImage: "pin") { updatePreferences { $0.defaultHomeProfileID = profile.id } }
                            Button("Edit setup", systemImage: "pencil") { profileEditor = profile }
                            Button("Remove setup", systemImage: "trash", role: .destructive) { profileRemoval = profile }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel("Actions for \(profile.name)")
                    }
                }
                Button {
                    profileEditor = HomePlaceProfile(ownerUserID: ownerID, name: "")
                } label: { Label("Add a Home setup", systemImage: "plus").frame(minHeight: 44) }
                .accessibilityIdentifier("home.profile.add")
                if preferences.defaultHomeProfileID != nil {
                    Button("Use Home without a saved setup") { updatePreferences { $0.defaultHomeProfileID = nil } }
                        .font(.subheadline).frame(minHeight: 44)
                }
            }
            HomeEditorSection("For a fresh setup", symbol: "slider.horizontal.3",
                detail: "Choose a favorite method and go-to beans for starting without a saved recipe.") {
                Menu(preferences.preferredMethod.map { "Favorite method: \($0.title)" } ?? "Choose a favorite method") {
                    Button("No favorite") { updatePreferences { $0.preferredMethod = nil } }
                    ForEach(HomeBrewMethod.allCases) { method in Button(method.title) { updatePreferences { $0.preferredMethod = method } } }
                }
                Menu(library.defaults(for: ownerID).bag.map { "Go-to beans: \($0.displayName)" } ?? "Choose go-to beans") {
                    Button("None") { updatePreferences { $0.defaultBagID = nil } }
                    ForEach(library.currentBags.filter { $0.ownerUserID == ownerID }) { bag in
                        Button(bag.displayName) { updatePreferences { $0.defaultBagID = bag.id } }
                    }
                }
                Text("Tools for Home").font(.subheadline.weight(.semibold))
                Text("Named setups use their own tools. Choose these for Home without a saved setup.")
                    .font(.caption).foregroundStyle(Color.secondaryText)
                ForEach(library.activeEquipment.filter { $0.ownerUserID == ownerID }) { gear in
                    Toggle(gear.displayName, isOn: Binding(get: { preferences.defaultEquipmentIDs.contains(gear.id) }, set: { value in
                        updatePreferences { if value { $0.defaultEquipmentIDs.insert(gear.id) } else { $0.defaultEquipmentIDs.remove(gear.id) } }
                    }))
                }
                Text("A saved recipe starts with its recorded setup. Change for this brew applies to the sip you’re making.")
                    .font(.caption).foregroundStyle(Color.secondaryText)
            }
            VStack(alignment: .leading, spacing: 12) {
                if let ownerID, permission.isEnabled(ownerID: ownerID) {
                    Toggle("Use Mugsy’s connected suggestions", isOn: Binding(get: { permission.isEnabled(ownerID: ownerID) }, set: { permission.setEnabled($0, ownerID: ownerID) }))
                    Text("OpenAI reads selected photos, recipe text and saved sip details when you ask Mugsy to read them. Manual entry always works.").font(.caption).foregroundStyle(Color.secondaryText)
                } else if ownerID != nil { MugsyPermissionControl(ownerID: ownerID) }
                else { Text("Sign in for Mugsy’s connected suggestions.").font(.subheadline).foregroundStyle(Color.secondaryText) }
            }.padding(16).background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func shelfRow(_ title: String, detail: String, symbol: String, pinned: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Color.mugshotSageText).frame(width: 42)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if pinned {
                        Image(systemName: "pin.fill").font(.caption.weight(.semibold))
                            .foregroundStyle(Color.mugshotSageText).accessibilityLabel("Pinned")
                    }
                    Text(title).font(.headline).foregroundStyle(Color.espressoBrown)
                }
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
        if let gearSetupFilter, !profiles.contains(where: { $0.id == gearSetupFilter }) { self.gearSetupFilter = nil }
        sipDrafts = includesSipDrafts ? SipDraftStore.shared.allDrafts(in: scope) : []
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
                    Link(destination: searchURL) { Label("Search the web", systemImage: "arrow.up.right.square") }
                        .buttonStyle(PrimaryButtonStyle())
                    Text("Search opens your browser.").font(.caption).foregroundStyle(Color.secondaryText)
                    Button("Save a recipe you found", systemImage: "plus", action: onAdd).buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("home.discovery.saveRecipe")
                    Text("Paste a public Instagram or TikTok link, add a caption, or choose screenshots or a saved video. Keep the creator’s source with your recipe.")
                        .font(.caption).foregroundStyle(Color.secondaryText)
                }.padding(20)
            }.background(Color.creamWhite).navigationTitle("Find a recipe").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
        }.tint(Color.mugshotSageText)
    }
}
